import uuid
import pytest
from datetime import datetime, timezone
from httpx import AsyncClient
from unittest.mock import AsyncMock

from app.core.security import create_access_token, get_password_hash
from app.models.user import User
from app.models.user_settings import UserSettings


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

    return MockResult()


@pytest.fixture
def test_user():
    now = datetime.now(timezone.utc)
    return User(
        id=uuid.uuid4(),
        email="user@example.com",
        first_name="Test",
        last_name="User",
        hashed_password=get_password_hash("password123"),
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[],
        created_at=now,
        updated_at=now,
    )


@pytest.fixture
def test_settings(test_user):
    now = datetime.now(timezone.utc)
    return UserSettings(
        id=uuid.uuid4(),
        user_id=test_user.id,
        locale="en",
        notification_email_enabled=True,
        notification_push_enabled=True,
        notification_security_alerts=True,
        notification_system_updates=True,
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_get_profile(client: AsyncClient, db_session, test_user):
    access_token = create_access_token(subject=test_user.id)

    async def mock_execute(*args, **kwargs):
        return make_mock_result(test_user)

    db_session.execute = mock_execute
    db_session.commit = AsyncMock()
    db_session.refresh = AsyncMock()

    response = await client.get(
        "/api/v1/profile/",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "user@example.com"


@pytest.mark.asyncio
async def test_get_profile_settings(
    client: AsyncClient, db_session, test_user, test_settings
):
    access_token = create_access_token(subject=test_user.id)
    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(test_user)
        return make_mock_result(test_settings)

    db_session.execute = mock_execute
    db_session.commit = AsyncMock()
    db_session.refresh = AsyncMock()

    response = await client.get(
        "/api/v1/profile/settings",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["locale"] == "en"
