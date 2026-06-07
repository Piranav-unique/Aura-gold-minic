import uuid
from datetime import datetime, timedelta, timezone

import pytest
from jose import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    get_password_hash,
)
from app.middleware.rate_limit_middleware import reset_rate_limit_store
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User


def make_expired_token(user_id: uuid.UUID) -> str:
    return create_access_token(
        subject=str(user_id), expires_delta=timedelta(seconds=-1)
    )


def make_tampered_token(user_id: uuid.UUID) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=30)
    payload = {"exp": expire, "sub": str(user_id), "type": "access"}
    return jwt.encode(payload, "wrong-secret-key", algorithm=settings.ALGORITHM)


def make_refresh_as_access_token(user_id: uuid.UUID) -> str:
    return create_refresh_token(subject=user_id, jti=str(uuid.uuid4()))


async def create_user_with_permissions(
    test_db: AsyncSession,
    permission_names: list[str],
    *,
    email: str | None = None,
    is_superuser: bool = False,
    is_active: bool = True,
    password: str = "password123",
) -> tuple[User, dict[str, str]]:
    """Create a user with a dedicated role holding the given permissions."""
    role = Role(
        name=f"test_role_{uuid.uuid4().hex[:8]}",
        description="Security test role",
        permissions=[],
    )
    test_db.add(role)
    await test_db.flush()

    for perm_name in permission_names:
        result = await test_db.execute(
            select(Permission).where(Permission.name == perm_name)
        )
        perm = result.scalars().first()
        if not perm:
            perm = Permission(name=perm_name, description=f"Test {perm_name}")
            test_db.add(perm)
            await test_db.flush()
        if perm not in role.permissions:
            role.permissions.append(perm)

    user = User(
        email=email or f"sec_{uuid.uuid4().hex[:8]}@example.com",
        hashed_password=get_password_hash(password),
        is_active=is_active,
        is_superuser=is_superuser,
        roles=[role],
    )
    test_db.add(user)
    await test_db.flush()

    token = create_access_token(subject=str(user.id))
    headers = {"Authorization": f"Bearer {token}"}
    return user, headers


@pytest.fixture
def rate_limit_settings(monkeypatch):
    """Lower rate limits and reset store for burst tests."""
    monkeypatch.setattr(settings, "RATE_LIMIT_LOGIN_MAX", 3)
    monkeypatch.setattr(settings, "RATE_LIMIT_LOGIN_WINDOW_SECONDS", 60)
    reset_rate_limit_store()
    yield
    reset_rate_limit_store()


@pytest.fixture(autouse=True)
def _reset_rate_limits_between_tests():
    reset_rate_limit_store()
    yield
    reset_rate_limit_store()
