import uuid
import pytest
from datetime import datetime, timezone
from httpx import AsyncClient
from unittest.mock import AsyncMock, MagicMock

from app.core.security import create_access_token
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User
from app.main import app
from app.api.dependencies import get_dashboard_service


@pytest.fixture
def test_user():
    now = datetime.now(timezone.utc)
    perm = Permission(
        id=uuid.uuid4(), name="dashboard.view", created_at=now, updated_at=now
    )
    role = Role(
        id=uuid.uuid4(),
        name="DashboardViewer",
        permissions=[perm],
        created_at=now,
        updated_at=now,
    )
    return User(
        id=uuid.uuid4(),
        email="user@example.com",
        first_name="Test",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_dashboard_stats(client: AsyncClient, db_session, test_user):
    access_token = create_access_token(subject=test_user.id)

    mock_dashboard_service = MagicMock()
    mock_dashboard_service.get_stats = AsyncMock(
        return_value={
            "recent_activity": [],
            "unread_notifications": 0,
            "security_alerts": [],
            "recent_notifications": [],
            "login_statistics": {"today": 1, "week": 3, "month": 10},
        }
    )

    async def mock_execute(*args, **kwargs):
        class MockScalars:
            def first(self):
                return test_user

            def all(self):
                return []

            def unique(self):
                return self

        class MockResult:
            def scalars(self):
                return MockScalars()

        return MockResult()

    db_session.execute = mock_execute

    app.dependency_overrides[get_dashboard_service] = lambda: mock_dashboard_service

    try:
        response = await client.get(
            "/api/v1/dashboard/stats",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["unread_notifications"] == 0
        assert data["login_statistics"]["today"] == 1
    finally:
        app.dependency_overrides.pop(get_dashboard_service, None)
