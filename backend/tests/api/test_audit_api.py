import pytest
import uuid
from datetime import datetime, timezone
from httpx import AsyncClient

from app.core.security import create_access_token
from app.models.user import User
from app.models.role import Role
from app.models.permission import Permission
from app.models.audit_log import AuditLog


def make_mock_result(val, is_list=False):
    class MockScalars:
        def first(self):
            return None if is_list else val

        def all(self):
            return val if is_list else [val]

        def unique(self):
            return self

    class MockResult:
        def scalars(self):
            return MockScalars()

        def all(self):
            return val if is_list else [val]

    return MockResult()


@pytest.fixture
def test_permissions():
    now = datetime.now(timezone.utc)
    return {
        "view_audit": Permission(
            id=uuid.uuid4(), name="audit.view", created_at=now, updated_at=now
        ),
    }


@pytest.fixture
def authorized_user(test_permissions):
    now = datetime.now(timezone.utc)
    admin_role = Role(
        id=uuid.uuid4(),
        name="Administrator",
        permissions=[test_permissions["view_audit"]],
        created_at=now,
        updated_at=now,
    )
    return User(
        id=uuid.uuid4(),
        email="admin@example.com",
        first_name="Admin",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[admin_role],
        created_at=now,
        updated_at=now,
    )


@pytest.fixture
def unauthorized_user():
    now = datetime.now(timezone.utc)
    return User(
        id=uuid.uuid4(),
        email="unauthorized@example.com",
        first_name="Guest",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[],
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_list_audit_logs_api_allowed(
    client: AsyncClient, db_session, authorized_user
):
    """Verify that user with 'audit.view' permission can retrieve audit logs."""
    access_token = create_access_token(subject=authorized_user.id)

    mock_logs = [
        AuditLog(
            id=uuid.uuid4(),
            action="login_success",
            entity_type="User",
            entity_id=str(authorized_user.id),
            meta_data={"email": "admin@example.com"},
            ip_address="127.0.0.1",
            user_agent="HTTPX",
            timestamp=datetime.now(timezone.utc),
        )
    ]

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            # get_current_user check
            return make_mock_result(authorized_user)
        else:
            # list_audit_logs query result
            return make_mock_result(mock_logs, is_list=True)

    db_session.execute = mock_execute

    response = await client.get(
        "/api/v1/audit-logs/?skip=0&limit=50&action=login_success",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["action"] == "login_success"
    assert data[0]["ip_address"] == "127.0.0.1"
    assert data[0]["metadata"] == {"email": "admin@example.com"}


@pytest.mark.asyncio
async def test_list_audit_logs_api_forbidden(
    client: AsyncClient, db_session, unauthorized_user
):
    """Verify that user without 'audit.view' permission is denied access (403)."""
    access_token = create_access_token(subject=unauthorized_user.id)

    async def mock_execute(*args, **kwargs):
        # get_current_user check
        return make_mock_result(unauthorized_user)

    db_session.execute = mock_execute

    response = await client.get(
        "/api/v1/audit-logs/",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 403
    data = response.json()
    assert "permission 'audit.view' is required" in data["error"]["message"].lower()
