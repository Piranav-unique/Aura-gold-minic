import uuid
import pytest
from datetime import datetime, timezone
from httpx import AsyncClient
from unittest.mock import AsyncMock

from app.core.security import create_access_token
from app.models.user import User


def make_mock_result(val, is_list=False):
    class MockScalars:
        def first(self):
            return None if is_list else val

        def all(self):
            return val if is_list else [val]

    class MockResult:
        def scalars(self):
            return MockScalars()

        def scalar(self):
            return val

    return MockResult()


@pytest.fixture
def test_user():
    now = datetime.now(timezone.utc)
    return User(
        id=uuid.uuid4(),
        email="user@example.com",
        first_name="Test",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[],
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_list_notifications_empty(client: AsyncClient, db_session, test_user):
    access_token = create_access_token(subject=test_user.id)
    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(test_user)
        if call_count == 2:
            return make_mock_result([], is_list=True)
        return make_mock_result(0)

    db_session.execute = mock_execute

    response = await client.get(
        "/api/v1/notifications/",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["items"] == []
    assert data["unread_count"] == 0


@pytest.mark.asyncio
async def test_mark_notifications_read(client: AsyncClient, db_session, test_user):
    access_token = create_access_token(subject=test_user.id)

    async def mock_execute(*args, **kwargs):
        return make_mock_result(test_user)

    db_session.execute = mock_execute
    db_session.commit = AsyncMock()

    class MockUpdateResult:
        rowcount = 1

    async def mock_execute_update(*args, **kwargs):
        return MockUpdateResult()

    original_execute = mock_execute

    call_count = 0

    async def combined_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return await original_execute(*args, **kwargs)
        return MockUpdateResult()

    db_session.execute = combined_execute

    response = await client.post(
        "/api/v1/notifications/read",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"mark_all": True},
    )
    assert response.status_code == 200
