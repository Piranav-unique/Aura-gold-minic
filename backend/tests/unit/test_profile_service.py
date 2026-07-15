import uuid
import pytest
from unittest.mock import AsyncMock, MagicMock

from app.services.profile import ProfileService
from app.schemas.profile import (
    ProfileUpdate,
    ChangePasswordRequest,
    AvatarUploadRequest,
    UserSettingsUpdate,
)
from app.core.security import get_password_hash
from app.models.user import User
from datetime import datetime, timezone

_TINY_PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="


def _user(**kwargs) -> User:
    now = datetime.now(timezone.utc)
    defaults = {
        "id": uuid.uuid4(),
        "email": "user@example.com",
        "hashed_password": get_password_hash("correct"),
        "is_active": True,
        "is_deleted": False,
        "roles": [],
        "created_at": now,
        "updated_at": now,
    }
    defaults.update(kwargs)
    return User(**defaults)


@pytest.fixture
def mock_user_repo():
    return MagicMock()


@pytest.fixture
def mock_settings_repo():
    return MagicMock()


@pytest.fixture
def profile_service(mock_user_repo, mock_settings_repo):
    return ProfileService(mock_user_repo, mock_settings_repo, audit_service=None)


@pytest.mark.asyncio
async def test_get_profile(profile_service, mock_user_repo):
    user = _user()
    mock_user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)
    result = await profile_service.get_profile(user.id)
    assert result.email == user.email


@pytest.mark.asyncio
async def test_get_avatar(profile_service, mock_user_repo):
    user = _user(avatar_base64=_TINY_PNG, avatar_content_type="image/png")
    mock_user_repo.get = AsyncMock(return_value=user)
    content, content_type = await profile_service.get_avatar(user.id)
    assert content_type == "image/png"
    assert len(content) > 0


@pytest.mark.asyncio
async def test_change_password_success(profile_service, mock_user_repo):
    user = _user()
    mock_user_repo.get = AsyncMock(return_value=user)
    mock_user_repo.db.commit = AsyncMock()

    assert await profile_service.change_password(
        user.id,
        ChangePasswordRequest(current_password="correct", new_password="newpassword1"),
    )


@pytest.mark.asyncio
async def test_upload_avatar(profile_service, mock_user_repo):
    user = _user()
    mock_user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)
    mock_user_repo.db.commit = AsyncMock()

    result = await profile_service.upload_avatar(
        user.id,
        AvatarUploadRequest(avatar_base64=_TINY_PNG, content_type="image/png"),
    )
    assert result.avatar_base64 == _TINY_PNG


@pytest.mark.asyncio
async def test_get_activity_without_audit_service(profile_service):
    items, total = await profile_service.get_activity(uuid.uuid4())
    assert items == []
    assert total == 0


@pytest.mark.asyncio
async def test_get_and_update_settings(profile_service, mock_settings_repo):
    user_id = uuid.uuid4()
    settings = MagicMock(id=uuid.uuid4())
    mock_settings_repo.get_or_create = AsyncMock(return_value=settings)
    mock_settings_repo.update = AsyncMock(return_value=settings)

    loaded = await profile_service.get_settings(user_id)
    assert loaded is settings

    updated = await profile_service.update_settings(
        user_id, UserSettingsUpdate(locale="en")
    )
    assert updated is settings
    mock_settings_repo.update.assert_awaited_once()


@pytest.mark.asyncio
async def test_update_profile(profile_service, mock_user_repo):
    user = _user(email="old@example.com")
    mock_user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)
    mock_user_repo.get_by_email = AsyncMock(return_value=None)
    mock_user_repo.db.commit = AsyncMock()

    result = await profile_service.update_profile(
        user.id, ProfileUpdate(first_name="New")
    )
    assert result.first_name == "New"


@pytest.mark.asyncio
async def test_change_password_wrong_current(profile_service, mock_user_repo):
    user = _user()
    mock_user_repo.get = AsyncMock(return_value=user)

    with pytest.raises(Exception):
        await profile_service.change_password(
            user.id,
            ChangePasswordRequest(
                current_password="wrong", new_password="newpassword1"
            ),
        )


@pytest.mark.asyncio
async def test_delete_own_account_consumer(profile_service, mock_user_repo, monkeypatch):
    user = _user()
    mock_user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)
    mock_user_repo.db.commit = AsyncMock()
    delete_mock = AsyncMock()
    monkeypatch.setattr(
        "app.services.profile.delete_consumer_account", delete_mock
    )

    await profile_service.delete_own_account(user.id)

    delete_mock.assert_awaited_once_with(mock_user_repo.db, user)
    mock_user_repo.db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_delete_own_account_user_not_found(profile_service, mock_user_repo):
    mock_user_repo.get_with_roles_and_permissions = AsyncMock(return_value=None)

    with pytest.raises(Exception):
        await profile_service.delete_own_account(uuid.uuid4())
