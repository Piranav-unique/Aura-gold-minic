from app.models.user import User
from app.models.role import Role
from app.models.permission import Permission
from app.models.audit_log import AuditLog


def test_user_model_instantiation():
    """Verify that User model properties instantiate and map correctly in memory."""
    user = User(
        email="test@example.com",
        hashed_password="hashedpassword",
        first_name="Test",
        last_name="User",
        is_active=True,
        is_superuser=False,
        is_deleted=False,
    )
    assert user.email == "test@example.com"
    assert user.hashed_password == "hashedpassword"
    assert user.first_name == "Test"
    assert user.last_name == "User"
    assert user.is_active is True
    assert user.is_superuser is False
    assert user.is_deleted is False


def test_role_model_instantiation():
    """Verify that Role model properties instantiate and map correctly in memory."""
    role = Role(name="manager", description="Manager access level", is_deleted=False)
    assert role.name == "manager"
    assert role.description == "Manager access level"
    assert role.is_deleted is False


def test_permission_model_instantiation():
    """Verify that Permission model properties instantiate and map correctly in memory."""
    permission = Permission(name="report:read", description="Can read reports")
    assert permission.name == "report:read"
    assert permission.description == "Can read reports"


def test_audit_log_model_instantiation():
    """Verify that AuditLog model properties instantiate and map correctly in memory."""
    log = AuditLog(
        action="update_user",
        entity_type="users",
        entity_id="12345",
        meta_data={"first_name": "Old", "first_name_new": "New"},
        ip_address="127.0.0.1",
        user_agent="Mozilla/5.0",
    )
    assert log.action == "update_user"
    assert log.entity_type == "users"
    assert log.entity_id == "12345"
    assert log.meta_data == {"first_name": "Old", "first_name_new": "New"}
    assert log.ip_address == "127.0.0.1"
    assert log.user_agent == "Mozilla/5.0"
