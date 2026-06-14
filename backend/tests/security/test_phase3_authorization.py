import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.security.conftest import create_user_with_permissions

pytestmark = pytest.mark.security


@pytest.mark.asyncio
async def test_dashboard_executive_requires_dashboard_view(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(test_db, ["user.view"])

    response = await db_client.get(
        "/api/v1/dashboard/executive",
        headers=headers,
    )
    assert response.status_code == 403
    assert "dashboard.view" in response.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_dashboard_stats_requires_dashboard_view(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(test_db, ["user.view"])

    response = await db_client.get(
        "/api/v1/dashboard/stats",
        headers=headers,
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_report_export_transaction_requires_transaction_view(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(
        test_db, ["report.view", "report.export"]
    )

    response = await db_client.get(
        "/api/v1/reports/transaction/export",
        params={"format": "csv"},
        headers=headers,
    )
    assert response.status_code == 403
    assert "transaction.view" in response.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_report_export_audit_requires_audit_view(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(
        test_db, ["report.view", "report.export"]
    )

    response = await db_client.get(
        "/api/v1/reports/audit/export",
        params={"format": "csv"},
        headers=headers,
    )
    assert response.status_code == 403
    assert "audit.view" in response.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_workflow_detail_idor_blocked(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, owner_headers = await create_user_with_permissions(
        test_db, ["workflow.view", "workflow.create"]
    )
    _, intruder_headers = await create_user_with_permissions(test_db, ["workflow.view"])

    create_res = await db_client.post(
        "/api/v1/workflows/",
        json={
            "title": "Private request",
            "description": "Should not leak",
            "request_type": "general",
        },
        headers=owner_headers,
    )
    assert create_res.status_code == 201, create_res.text
    request_id = create_res.json()["id"]

    detail_res = await db_client.get(
        f"/api/v1/workflows/{request_id}",
        headers=intruder_headers,
    )
    assert detail_res.status_code == 403
