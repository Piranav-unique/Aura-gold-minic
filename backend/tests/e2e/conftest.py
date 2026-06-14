import uuid
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_password_hash
from app.middleware.rate_limit_middleware import reset_rate_limit_store
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User

E2E_PASSWORD = "password123"


@pytest.fixture(autouse=True)
def reset_rate_limit_before_test():
    """Reset rate limit store before each E2E test to prevent false positives from rate limiting."""
    reset_rate_limit_store()
    yield
    reset_rate_limit_store()


async def login(client: AsyncClient, email: str, password: str) -> dict[str, Any]:
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return response.json()


def bearer_headers(access_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {access_token}"}


async def create_role_with_permissions(
    test_db: AsyncSession,
    role_name: str,
    permission_names: list[str],
) -> Role:
    role = Role(name=role_name, description=f"E2E role {role_name}", permissions=[])
    test_db.add(role)
    await test_db.flush()

    for perm_name in permission_names:
        result = await test_db.execute(
            select(Permission).where(Permission.name == perm_name)
        )
        perm = result.scalars().first()
        if not perm:
            perm = Permission(name=perm_name, description=f"E2E {perm_name}")
            test_db.add(perm)
            await test_db.flush()
        if perm not in role.permissions:
            role.permissions.append(perm)

    await test_db.flush()
    return role


async def create_e2e_user(
    test_db: AsyncSession,
    role: Role,
    *,
    email_prefix: str,
    is_superuser: bool = False,
) -> tuple[User, str]:
    user = User(
        email=f"{email_prefix}_{uuid.uuid4().hex[:8]}@e2e.test",
        hashed_password=get_password_hash(E2E_PASSWORD),
        is_active=True,
        is_superuser=is_superuser,
        roles=[role],
    )
    test_db.add(user)
    await test_db.flush()
    return user, E2E_PASSWORD


@pytest.fixture
async def admin_actor(test_db: AsyncSession) -> tuple[User, str]:
    role = await create_role_with_permissions(
        test_db,
        f"e2e_admin_{uuid.uuid4().hex[:6]}",
        [
            "user.view",
            "user.create",
            "user.update",
            "user.delete",
            "role:read",
            "role:write",
            "audit.view",
            "customer.view",
            "customer.create",
            "customer.update",
            "customer.delete",
            "inventory.view",
            "inventory.create",
            "inventory.update",
            "inventory.delete",
            "transaction.view",
            "transaction.create",
            "transaction.update",
            "report.view",
            "report.export",
            "workflow.view",
            "workflow.create",
            "workflow.approve",
            "workflow.manage",
            "dashboard.view",
        ],
    )
    user, password = await create_e2e_user(
        test_db, role, email_prefix="admin", is_superuser=True
    )
    return user, password


@pytest.fixture
async def manager_actor(test_db: AsyncSession) -> tuple[User, str]:
    role = await create_role_with_permissions(
        test_db,
        f"e2e_manager_{uuid.uuid4().hex[:6]}",
        ["user.view", "user.update", "role:read", "audit.view"],
    )
    return await create_e2e_user(test_db, role, email_prefix="manager")


@pytest.fixture
async def employee_actor(test_db: AsyncSession) -> tuple[User, str]:
    role = await create_role_with_permissions(
        test_db,
        f"e2e_employee_{uuid.uuid4().hex[:6]}",
        ["user.view"],
    )
    return await create_e2e_user(test_db, role, email_prefix="employee")
