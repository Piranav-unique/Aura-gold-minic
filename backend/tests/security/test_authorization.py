import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, get_password_hash
from app.models.role import Role
from app.models.user import User
from tests.security.conftest import create_user_with_permissions

pytestmark = pytest.mark.security


@pytest.mark.asyncio
async def test_endpoint_access_by_role_permissions(
    db_client: AsyncClient, test_db: AsyncSession
):
    """Verify that a standard user role is permitted to view users but forbidden from creating them,
    while a super admin / admin user is allowed.
    """
    role_result = await test_db.execute(select(Role).where(Role.name == "user"))
    user_role = role_result.scalars().first()
    assert user_role is not None

    user = User(
        email="std_user@example.com",
        hashed_password="pw",
        roles=[user_role],
        is_active=True,
    )
    test_db.add(user)
    await test_db.commit()

    std_token = create_access_token(subject=str(user.id))
    std_headers = {"Authorization": f"Bearer {std_token}"}

    get_res = await db_client.get("/api/v1/users/", headers=std_headers)
    assert get_res.status_code == 200

    post_data = {
        "email": "new_created@example.com",
        "password": "somepassword123",
        "first_name": "New",
        "last_name": "Created",
    }
    post_res = await db_client.post(
        "/api/v1/users/", json=post_data, headers=std_headers
    )
    assert post_res.status_code == 403
    assert "permission" in post_res.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_superuser_endpoint_bypass(db_client: AsyncClient, test_db: AsyncSession):
    """Verify that a superuser has full access to create users without needing specific role permissions."""
    role_result = await test_db.execute(select(Role).where(Role.name == "super_admin"))
    admin_role = role_result.scalars().first()

    admin_user = User(
        email="super_dev@example.com",
        hashed_password="pw",
        roles=[admin_role] if admin_role else [],
        is_active=True,
        is_superuser=True,
    )
    test_db.add(admin_user)
    await test_db.commit()

    admin_token = create_access_token(subject=str(admin_user.id))
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    post_data = {
        "email": "super_created@example.com",
        "password": "somepassword123",
        "first_name": "Super",
        "last_name": "Created",
    }
    post_res = await db_client.post(
        "/api/v1/users/", json=post_data, headers=admin_headers
    )
    assert post_res.status_code == 201
    assert post_res.json()["email"] == "super_created@example.com"


@pytest.mark.asyncio
async def test_unauthenticated_request_rejected(db_client: AsyncClient):
    """Verify that accessing a protected endpoint without authentication headers returns 401 Unauthorized."""
    res = await db_client.get("/api/v1/users/")
    assert res.status_code == 401
    assert res.json() == {"detail": "Not authenticated"}


@pytest.mark.asyncio
async def test_unauthorized_access_audit_logs(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(test_db, ["user.view"])

    response = await db_client.get("/api/v1/audit-logs/", headers=headers)
    assert response.status_code == 403
    assert response.json()["error"]["type"] == "ForbiddenException"


@pytest.mark.asyncio
async def test_unauthorized_access_create_role(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(test_db, ["user.view"])

    response = await db_client.post(
        "/api/v1/rbac/roles",
        json={"name": "evil_role", "description": "Should not be created"},
        headers=headers,
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_unauthorized_access_delete_user(
    db_client: AsyncClient, test_db: AsyncSession
):
    victim = User(
        email=f"victim_{uuid.uuid4().hex[:6]}@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
    )
    test_db.add(victim)
    await test_db.flush()

    _, headers = await create_user_with_permissions(test_db, ["user.view"])

    response = await db_client.delete(f"/api/v1/users/{victim.id}", headers=headers)
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_permission_escalation_blocked(
    db_client: AsyncClient, test_db: AsyncSession
):
    user, headers = await create_user_with_permissions(
        test_db, ["user.update", "user.view"]
    )

    response = await db_client.put(
        f"/api/v1/users/{user.id}",
        json={"is_superuser": True},
        headers=headers,
    )
    assert response.status_code == 403
    assert "superuser" in response.json()["error"]["message"].lower()

    await test_db.refresh(user)
    assert user.is_superuser is False


@pytest.mark.asyncio
async def test_role_manipulation_by_standard_user_forbidden(
    db_client: AsyncClient, test_db: AsyncSession
):
    user, headers = await create_user_with_permissions(test_db, ["user.view"])

    admin_role_result = await test_db.execute(
        select(Role).where(Role.name == "super_admin")
    )
    admin_role = admin_role_result.scalars().first()
    assert admin_role is not None

    response = await db_client.post(
        f"/api/v1/rbac/users/{user.id}/roles",
        params={"role_id": str(admin_role.id)},
        headers=headers,
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_role_manipulation_by_readonly_admin_forbidden(
    db_client: AsyncClient, test_db: AsyncSession
):
    admin_role_result = await test_db.execute(select(Role).where(Role.name == "admin"))
    admin_role = admin_role_result.scalars().first()
    assert admin_role is not None

    user = User(
        email=f"readonly_admin_{uuid.uuid4().hex[:6]}@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
        roles=[admin_role],
    )
    test_db.add(user)
    await test_db.flush()

    headers = {"Authorization": f"Bearer {create_access_token(subject=str(user.id))}"}

    super_admin_result = await test_db.execute(
        select(Role).where(Role.name == "super_admin")
    )
    super_admin_role = super_admin_result.scalars().first()

    response = await db_client.post(
        f"/api/v1/rbac/users/{user.id}/roles",
        params={"role_id": str(super_admin_role.id)},
        headers=headers,
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_rbac_wildcard_allows_matching_action(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(test_db, ["user:*"])

    response = await db_client.get("/api/v1/users/", headers=headers)
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_rbac_wildcard_denies_unmatched_action(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(test_db, ["user:read"])

    response = await db_client.post(
        "/api/v1/users/",
        json={
            "email": f"wildcard_deny_{uuid.uuid4().hex[:6]}@example.com",
            "password": "password123",
        },
        headers=headers,
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_superuser_bypass_without_explicit_permissions(
    db_client: AsyncClient, test_db: AsyncSession
):
    user = User(
        email=f"super_bypass_{uuid.uuid4().hex[:6]}@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
        is_superuser=True,
        roles=[],
    )
    test_db.add(user)
    await test_db.flush()

    headers = {"Authorization": f"Bearer {create_access_token(subject=str(user.id))}"}

    response = await db_client.post(
        "/api/v1/users/",
        json={
            "email": f"created_by_super_{uuid.uuid4().hex[:6]}@example.com",
            "password": "password123",
        },
        headers=headers,
    )
    assert response.status_code == 201


@pytest.mark.asyncio
async def test_inactive_user_token_rejected(
    db_client: AsyncClient, test_db: AsyncSession
):
    user = User(
        email=f"deactivate_{uuid.uuid4().hex[:6]}@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
    )
    test_db.add(user)
    await test_db.flush()

    token = create_access_token(subject=str(user.id))
    headers = {"Authorization": f"Bearer {token}"}

    user.is_active = False
    await test_db.flush()

    response = await db_client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 401
    assert response.json()["error"]["type"] == "AuthenticationException"
