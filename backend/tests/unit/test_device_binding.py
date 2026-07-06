import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.user import User
from app.repositories.user import UserRepository
from app.services.auth import AuthService
from app.utils.device_binding import (
    bind_device_for_mobile_login,
    ensure_device_available_for_registration,
    normalize_device_id,
)


DEVICE_A = "11111111-1111-4111-8111-111111111111"
DEVICE_B = "22222222-2222-4222-8222-222222222222"


@pytest.fixture
def mock_user_repo():
    repo = MagicMock(spec=UserRepository)
    repo.db = MagicMock()
    repo.db.commit = AsyncMock()
    return repo


def test_normalize_device_id_accepts_lowercase_uuid():
    assert normalize_device_id(DEVICE_A) == DEVICE_A


def test_normalize_device_id_rejects_invalid_value():
    with pytest.raises(ValueError):
        normalize_device_id("not-a-device-id")


@pytest.mark.asyncio
async def test_ensure_device_available_for_registration_allows_used_device(
    mock_user_repo,
):
    mock_user_repo.get_by_registered_device_id = AsyncMock(
        return_value=User(id=uuid.uuid4(), email="x@y.com", hashed_password="x")
    )

    await ensure_device_available_for_registration(mock_user_repo, DEVICE_A)


@pytest.mark.asyncio
async def test_bind_device_for_mobile_login_updates_device(mock_user_repo):
    user = User(
        id=uuid.uuid4(),
        email="user@mobile.agsgold.com",
        hashed_password="x",
        mobile_number="9876543210",
        mobile_verified=True,
        registered_device_id=DEVICE_A,
    )

    await bind_device_for_mobile_login(mock_user_repo, user, DEVICE_B)

    assert user.registered_device_id == DEVICE_B
    mock_user_repo.db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_bind_device_for_mobile_login_binds_legacy_account(mock_user_repo):
    user = User(
        id=uuid.uuid4(),
        email="user@mobile.agsgold.com",
        hashed_password="x",
        mobile_number="9876543210",
        mobile_verified=True,
    )

    await bind_device_for_mobile_login(mock_user_repo, user, DEVICE_A)

    assert user.registered_device_id == DEVICE_A
    mock_user_repo.db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_authenticate_user_by_mobile_allows_other_device(mock_user_repo):
    user = User(
        id=uuid.uuid4(),
        email="user@mobile.agsgold.com",
        hashed_password="x",
        mobile_number="9876543210",
        mobile_verified=True,
        registered_device_id=DEVICE_A,
        is_active=True,
        is_deleted=False,
        is_superuser=False,
    )
    mock_user_repo.get_by_mobile = AsyncMock(return_value=user)
    auth_service = AuthService(
        user_repo=mock_user_repo,
        token_blacklist_repo=MagicMock(),
    )

    result = await auth_service.authenticate_user_by_mobile("9876543210", DEVICE_B)

    assert result is user
    assert user.registered_device_id == DEVICE_B


@pytest.mark.asyncio
async def test_trusted_first_mobile_login_succeeds_on_registration_device(
    mock_user_repo,
):
    user = User(
        id=uuid.uuid4(),
        email="user@mobile.agsgold.com",
        hashed_password="x",
        mobile_number="7010196231",
        mobile_verified=True,
        registered_device_id=DEVICE_A,
        has_completed_mobile_login=False,
        is_active=True,
        is_deleted=False,
        is_superuser=False,
    )
    mock_user_repo.get_by_mobile = AsyncMock(return_value=user)
    auth_service = AuthService(
        user_repo=mock_user_repo,
        token_blacklist_repo=MagicMock(),
    )

    result = await auth_service.authenticate_trusted_first_mobile_login(
        "7010196231", DEVICE_A
    )

    assert result is user
    assert user.has_completed_mobile_login is True
    mock_user_repo.db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_trusted_first_mobile_login_allows_other_device(mock_user_repo):
    user = User(
        id=uuid.uuid4(),
        email="user@mobile.agsgold.com",
        hashed_password="x",
        mobile_number="7010196231",
        mobile_verified=True,
        registered_device_id=DEVICE_A,
        has_completed_mobile_login=False,
        is_active=True,
        is_deleted=False,
        is_superuser=False,
    )
    mock_user_repo.get_by_mobile = AsyncMock(return_value=user)
    auth_service = AuthService(
        user_repo=mock_user_repo,
        token_blacklist_repo=MagicMock(),
    )

    result = await auth_service.authenticate_trusted_first_mobile_login(
        "7010196231", DEVICE_B
    )

    assert result is user
    assert user.has_completed_mobile_login is True


@pytest.mark.asyncio
async def test_trusted_first_mobile_login_requires_otp_after_first_sign_in(
    mock_user_repo,
):
    user = User(
        id=uuid.uuid4(),
        email="user@mobile.agsgold.com",
        hashed_password="x",
        mobile_number="7010196231",
        mobile_verified=True,
        registered_device_id=DEVICE_A,
        has_completed_mobile_login=True,
        is_active=True,
        is_deleted=False,
        is_superuser=False,
    )
    mock_user_repo.get_by_mobile = AsyncMock(return_value=user)
    auth_service = AuthService(
        user_repo=mock_user_repo,
        token_blacklist_repo=MagicMock(),
    )

    from app.core.exceptions import AuthenticationException

    with pytest.raises(AuthenticationException, match="OTP verification"):
        await auth_service.authenticate_trusted_first_mobile_login(
            "7010196231", DEVICE_A
        )
