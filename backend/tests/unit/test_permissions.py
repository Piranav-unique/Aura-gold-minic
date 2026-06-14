import uuid
from datetime import datetime, timezone

from app.core.permissions import user_has_permission
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User


def _user_with_permission(permission_name: str) -> User:
    now = datetime.now(timezone.utc)
    perm = Permission(
        id=uuid.uuid4(),
        name=permission_name,
        created_at=now,
        updated_at=now,
    )
    role = Role(
        id=uuid.uuid4(),
        name="test",
        permissions=[perm],
        created_at=now,
        updated_at=now,
    )
    return User(
        id=uuid.uuid4(),
        email="perm@test.com",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=now,
        updated_at=now,
    )


def test_user_has_permission_exact_match():
    user = _user_with_permission("customer.view")
    assert user_has_permission(user, "customer.view") is True
    assert user_has_permission(user, "customer.create") is False


def test_user_has_permission_wildcard_namespace():
    user = _user_with_permission("customer.*")
    assert user_has_permission(user, "customer.view") is True
    assert user_has_permission(user, "inventory.view") is False


def test_superuser_has_all_permissions():
    now = datetime.now(timezone.utc)
    user = User(
        id=uuid.uuid4(),
        email="admin@test.com",
        is_active=True,
        is_deleted=False,
        is_superuser=True,
        roles=[],
        created_at=now,
        updated_at=now,
    )
    assert user_has_permission(user, "anything.here") is True
