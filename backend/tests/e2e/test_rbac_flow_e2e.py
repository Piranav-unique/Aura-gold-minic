import uuid

import pytest
from httpx import AsyncClient

from tests.e2e.conftest import bearer_headers, login

pytestmark = pytest.mark.e2e


@pytest.mark.asyncio
async def test_e2e_admin_access(db_client: AsyncClient, admin_actor: tuple):
    """Admin can create users, manage RBAC, and view audit logs."""
    user, password = admin_actor
    tokens = await login(db_client, user.email, password)
    headers = bearer_headers(tokens["access_token"])

    users_response = await db_client.get("/api/v1/users/", headers=headers)
    assert users_response.status_code == 200

    create_response = await db_client.post(
        "/api/v1/users/",
        json={
            "email": f"admin_created_{uuid.uuid4().hex[:6]}@example.com",
            "password": "password123",
        },
        headers=headers,
    )
    assert create_response.status_code == 201

    roles_response = await db_client.get("/api/v1/rbac/roles", headers=headers)
    assert roles_response.status_code == 200

    audit_response = await db_client.get("/api/v1/audit-logs/", headers=headers)
    assert audit_response.status_code == 200


@pytest.mark.asyncio
async def test_e2e_manager_access(db_client: AsyncClient, manager_actor: tuple):
    """Manager can view and update users but cannot create, delete, or write RBAC."""
    user, password = manager_actor
    tokens = await login(db_client, user.email, password)
    headers = bearer_headers(tokens["access_token"])

    list_response = await db_client.get("/api/v1/users/", headers=headers)
    assert list_response.status_code == 200

    update_response = await db_client.put(
        f"/api/v1/users/{user.id}",
        json={"first_name": "ManagerUpdated"},
        headers=headers,
    )
    assert update_response.status_code == 200

    create_response = await db_client.post(
        "/api/v1/users/",
        json={
            "email": f"manager_blocked_{uuid.uuid4().hex[:6]}@example.com",
            "password": "password123",
        },
        headers=headers,
    )
    assert create_response.status_code == 403

    rbac_response = await db_client.post(
        "/api/v1/rbac/roles",
        json={"name": "blocked_role", "description": "Should fail"},
        headers=headers,
    )
    assert rbac_response.status_code == 403


@pytest.mark.asyncio
async def test_e2e_employee_access(db_client: AsyncClient, employee_actor: tuple):
    """Employee can view users only; all write operations are denied."""
    user, password = employee_actor
    tokens = await login(db_client, user.email, password)
    headers = bearer_headers(tokens["access_token"])

    list_response = await db_client.get("/api/v1/users/", headers=headers)
    assert list_response.status_code == 200

    audit_response = await db_client.get("/api/v1/audit-logs/", headers=headers)
    assert audit_response.status_code == 403

    create_response = await db_client.post(
        "/api/v1/users/",
        json={
            "email": f"employee_blocked_{uuid.uuid4().hex[:6]}@example.com",
            "password": "password123",
        },
        headers=headers,
    )
    assert create_response.status_code == 403

    roles_response = await db_client.get("/api/v1/rbac/roles", headers=headers)
    assert roles_response.status_code == 403
