import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.e2e.conftest import bearer_headers, create_role_with_permissions, login

pytestmark = pytest.mark.e2e


@pytest.mark.asyncio
async def test_e2e_user_management_full_flow(
    db_client: AsyncClient,
    test_db: AsyncSession,
    admin_actor: tuple,
):
    """Create user, assign role, update user, delete user."""
    admin_user, password = admin_actor
    tokens = await login(db_client, admin_user.email, password)
    headers = bearer_headers(tokens["access_token"])

    new_email = f"e2e_new_{uuid.uuid4().hex[:8]}@example.com"
    create_response = await db_client.post(
        "/api/v1/users/",
        json={
            "email": new_email,
            "password": "password123",
            "first_name": "E2E",
            "last_name": "User",
        },
        headers=headers,
    )
    assert create_response.status_code == 201
    created = create_response.json()
    user_id = created["id"]
    assert created["email"] == new_email

    assign_role = await create_role_with_permissions(
        test_db,
        f"e2e_assign_{uuid.uuid4().hex[:6]}",
        ["user.view"],
    )

    assign_response = await db_client.post(
        f"/api/v1/rbac/users/{user_id}/roles",
        params={"role_id": str(assign_role.id)},
        headers=headers,
    )
    assert assign_response.status_code == 200
    assigned_roles = assign_response.json()["roles"]
    assert any(r["id"] == str(assign_role.id) for r in assigned_roles)

    update_response = await db_client.put(
        f"/api/v1/users/{user_id}",
        json={"first_name": "Updated", "last_name": "Operator"},
        headers=headers,
    )
    assert update_response.status_code == 200
    assert update_response.json()["first_name"] == "Updated"

    delete_response = await db_client.delete(
        f"/api/v1/users/{user_id}",
        headers=headers,
    )
    assert delete_response.status_code == 200

    get_response = await db_client.get(
        f"/api/v1/users/{user_id}",
        headers=headers,
    )
    assert get_response.status_code == 404
