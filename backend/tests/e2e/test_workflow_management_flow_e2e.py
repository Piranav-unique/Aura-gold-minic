import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.e2e.conftest import (
    bearer_headers,
    create_e2e_user,
    create_role_with_permissions,
    login,
)

pytestmark = pytest.mark.e2e

E2E_PASSWORD = "password123"


@pytest.fixture
async def workflow_creator(test_db: AsyncSession):
    role = await create_role_with_permissions(
        test_db,
        f"e2e_workflow_creator_{uuid.uuid4().hex[:6]}",
        ["workflow.view", "workflow.create"],
    )
    return await create_e2e_user(test_db, role, email_prefix="wf_creator")


@pytest.fixture
async def workflow_approver(test_db: AsyncSession):
    role = await create_role_with_permissions(
        test_db,
        f"e2e_workflow_approver_{uuid.uuid4().hex[:6]}",
        ["workflow.view", "workflow.approve"],
    )
    return await create_e2e_user(test_db, role, email_prefix="wf_approver")


@pytest.mark.asyncio
async def test_workflow_create_submit_approve_flow(
    db_client: AsyncClient,
    workflow_creator,
    workflow_approver,
):
    creator, creator_pw = workflow_creator
    approver, approver_pw = workflow_approver

    creator_tokens = await login(db_client, creator.email, creator_pw)
    approver_tokens = await login(db_client, approver.email, approver_pw)

    create_resp = await db_client.post(
        "/api/v1/workflows/",
        headers=bearer_headers(creator_tokens["access_token"]),
        json={
            "title": "Discount approval",
            "description": "Approve 10% discount",
            "request_type": "general",
            "assignee_id": str(approver.id),
        },
    )
    assert create_resp.status_code == 201, create_resp.text
    request_id = create_resp.json()["id"]
    assert create_resp.json()["state"] == "draft"

    submit_resp = await db_client.post(
        f"/api/v1/workflows/{request_id}/submit",
        headers=bearer_headers(creator_tokens["access_token"]),
        json={"comment": "Please review"},
    )
    assert submit_resp.status_code == 200, submit_resp.text
    assert submit_resp.json()["state"] == "pending"

    detail_resp = await db_client.get(
        f"/api/v1/workflows/{request_id}",
        headers=bearer_headers(approver_tokens["access_token"]),
    )
    assert detail_resp.status_code == 200
    assert len(detail_resp.json()["history"]) >= 2

    approve_resp = await db_client.post(
        f"/api/v1/workflows/{request_id}/approve",
        headers=bearer_headers(approver_tokens["access_token"]),
        json={"comment": "Approved"},
    )
    assert approve_resp.status_code == 200, approve_resp.text
    assert approve_resp.json()["state"] == "approved"

    comment_resp = await db_client.post(
        f"/api/v1/workflows/{request_id}/comments",
        headers=bearer_headers(creator_tokens["access_token"]),
        json={"body": "Thanks"},
    )
    assert comment_resp.status_code == 422


@pytest.mark.asyncio
async def test_workflow_reject_flow(
    db_client: AsyncClient,
    workflow_creator,
    workflow_approver,
):
    creator, creator_pw = workflow_creator
    approver, approver_pw = workflow_approver

    creator_tokens = await login(db_client, creator.email, creator_pw)
    approver_tokens = await login(db_client, approver.email, approver_pw)

    create_resp = await db_client.post(
        "/api/v1/workflows/",
        headers=bearer_headers(creator_tokens["access_token"]),
        json={
            "title": "Policy exception",
            "request_type": "customer",
            "assignee_id": str(approver.id),
        },
    )
    request_id = create_resp.json()["id"]

    await db_client.post(
        f"/api/v1/workflows/{request_id}/submit",
        headers=bearer_headers(creator_tokens["access_token"]),
        json={},
    )

    reject_resp = await db_client.post(
        f"/api/v1/workflows/{request_id}/reject",
        headers=bearer_headers(approver_tokens["access_token"]),
        json={"comment": "Not allowed"},
    )
    assert reject_resp.status_code == 200
    assert reject_resp.json()["state"] == "rejected"
