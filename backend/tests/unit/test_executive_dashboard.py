import uuid
from datetime import datetime, timezone


from app.models.role import Role
from app.models.user import User
from app.services.executive_dashboard import resolve_executive_role


def _user_with_roles(role_names: list[str], *, superuser: bool = False) -> User:
    now = datetime.now(timezone.utc)
    roles = [
        Role(
            id=uuid.uuid4(),
            name=name,
            permissions=[],
            created_at=now,
            updated_at=now,
        )
        for name in role_names
    ]
    return User(
        id=uuid.uuid4(),
        email="test@example.com",
        is_active=True,
        is_deleted=False,
        is_superuser=superuser,
        roles=roles,
        created_at=now,
        updated_at=now,
    )


def test_resolve_admin_from_superuser():
    assert resolve_executive_role(_user_with_roles([], superuser=True)) == "admin"


def test_resolve_manager_role():
    assert resolve_executive_role(_user_with_roles(["manager"])) == "manager"


def test_resolve_employee_role():
    assert resolve_executive_role(_user_with_roles(["employee"])) == "employee"


def test_resolve_admin_from_admin_role():
    assert resolve_executive_role(_user_with_roles(["admin"])) == "admin"
