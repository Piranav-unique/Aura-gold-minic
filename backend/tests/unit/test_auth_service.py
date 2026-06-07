from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock
import pytest
import uuid

from app.core.exceptions import AuthenticationException
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.models.user import User
from app.repositories.user import UserRepository
from app.repositories.token_blacklist import TokenBlacklistRepository
from app.services.auth import AuthService


# --- Security Utils Unit Tests ---

def test_password_hashing_and_verification():
    """Verify that password hashing generates valid hashes that verify successfully."""
    pwd = "mysecretpassword"
    pwd_hash = get_password_hash(pwd)

    assert pwd_hash != pwd
    assert verify_password(pwd, pwd_hash) is True
    assert verify_password("wrongpassword", pwd_hash) is False
    assert verify_password(pwd, "invalidhash") is False


def test_token_creation_and_decoding():
    """Verify that access and refresh tokens are encoded and decoded correctly."""
    user_id = uuid.uuid4()

    # Access token
    token = create_access_token(subject=user_id)
    payload = decode_token(token)

    assert payload["sub"] == str(user_id)
    assert payload["type"] == "access"
    assert "exp" in payload

    # Refresh token
    jti = str(uuid.uuid4())
    r_token = create_refresh_token(subject=user_id, jti=jti)
    r_payload = decode_token(r_token)

    assert r_payload["sub"] == str(user_id)
    assert r_payload["jti"] == jti
    assert r_payload["type"] == "refresh"


def test_expired_token_raises_exception():
    """Verify that decode_token raises AuthenticationException for expired tokens."""
    token = create_access_token(subject="user", expires_delta=timedelta(seconds=-10))

    with pytest.raises(AuthenticationException) as exc_info:
        decode_token(token)

    assert "expired" in str(exc_info.value).lower()


def test_invalid_token_payload_raises_exception():
    """Verify that tokens missing critical fields raise AuthenticationException."""
    from jose import jwt
    from app.core.config import settings
    
    # Missing 'sub' claim
    bad_payload = {"exp": datetime.now(timezone.utc) + timedelta(minutes=10), "type": "access"}
    bad_token = jwt.encode(bad_payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

    with pytest.raises(AuthenticationException) as exc_info:
        decode_token(bad_token)
    assert "payload" in str(exc_info.value).lower()


# --- AuthService Unit Tests ---

@pytest.fixture
def mock_user_repository():
    return MagicMock(spec=UserRepository)


@pytest.fixture
def mock_token_blacklist_repository():
    return MagicMock(spec=TokenBlacklistRepository)


@pytest.fixture
def auth_service(mock_user_repository, mock_token_blacklist_repository):
    return AuthService(
        user_repo=mock_user_repository,
        token_blacklist_repo=mock_token_blacklist_repository,
    )


@pytest.mark.asyncio
async def test_authenticate_user_success(auth_service, mock_user_repository):
    """Verify successful authentication returns the user."""
    password = "correct_password"
    hashed_password = get_password_hash(password)
    user = User(
        id=uuid.uuid4(),
        email="test@example.com",
        hashed_password=hashed_password,
        is_active=True,
        is_deleted=False,
    )

    mock_user_repository.get_by_email = AsyncMock(return_value=user)

    result = await auth_service.authenticate_user("test@example.com", password)
    assert result == user
    mock_user_repository.get_by_email.assert_called_once_with("test@example.com")


@pytest.mark.asyncio
async def test_authenticate_user_invalid_email(auth_service, mock_user_repository):
    """Verify authentication fails if user is not found."""
    mock_user_repository.get_by_email = AsyncMock(return_value=None)

    with pytest.raises(AuthenticationException) as exc_info:
        await auth_service.authenticate_user("nonexistent@example.com", "password")

    assert "incorrect email or password" in str(exc_info.value).lower()


@pytest.mark.asyncio
async def test_authenticate_user_wrong_password(auth_service, mock_user_repository):
    """Verify authentication fails with incorrect password."""
    user = User(
        id=uuid.uuid4(),
        email="test@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
        is_deleted=False,
    )
    mock_user_repository.get_by_email = AsyncMock(return_value=user)

    with pytest.raises(AuthenticationException) as exc_info:
        await auth_service.authenticate_user("test@example.com", "wrong_password")

    assert "incorrect email or password" in str(exc_info.value).lower()


@pytest.mark.asyncio
async def test_authenticate_user_inactive(auth_service, mock_user_repository):
    """Verify authentication fails if user is inactive."""
    user = User(
        id=uuid.uuid4(),
        email="test@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=False,
        is_deleted=False,
    )
    mock_user_repository.get_by_email = AsyncMock(return_value=user)

    with pytest.raises(AuthenticationException) as exc_info:
        await auth_service.authenticate_user("test@example.com", "password123")

    assert "incorrect email or password" in str(exc_info.value).lower()


@pytest.mark.asyncio
async def test_refresh_tokens_success(
    auth_service, mock_user_repository, mock_token_blacklist_repository
):
    """Verify refresh token rotation blacklists old and returns a new token pair."""
    user_id = uuid.uuid4()
    old_jti = str(uuid.uuid4())
    refresh_token = create_refresh_token(subject=user_id, jti=old_jti)

    user = User(id=user_id, email="test@example.com", is_active=True, is_deleted=False)

    mock_token_blacklist_repository.is_blacklisted = AsyncMock(return_value=False)
    mock_token_blacklist_repository.blacklist_token = AsyncMock()
    mock_user_repository.get = AsyncMock(return_value=user)

    tokens = await auth_service.refresh_tokens(refresh_token)

    assert tokens.access_token is not None
    assert tokens.refresh_token is not None
    mock_token_blacklist_repository.is_blacklisted.assert_called_once_with(old_jti)
    mock_token_blacklist_repository.blacklist_token.assert_called_once()
    mock_user_repository.get.assert_called_once_with(user_id)


@pytest.mark.asyncio
async def test_refresh_tokens_blacklisted(
    auth_service, mock_token_blacklist_repository
):
    """Verify refresh fails if the token JTI is already blacklisted."""
    user_id = uuid.uuid4()
    jti = str(uuid.uuid4())
    refresh_token = create_refresh_token(subject=user_id, jti=jti)

    mock_token_blacklist_repository.is_blacklisted = AsyncMock(return_value=True)

    with pytest.raises(AuthenticationException) as exc_info:
        await auth_service.refresh_tokens(refresh_token)

    assert "revoked" in str(exc_info.value).lower()


@pytest.mark.asyncio
async def test_logout_user_success(auth_service, mock_token_blacklist_repository):
    """Verify that logging out blacklists the token JTI."""
    user_id = uuid.uuid4()
    jti = str(uuid.uuid4())
    refresh_token = create_refresh_token(subject=user_id, jti=jti)

    mock_token_blacklist_repository.is_blacklisted = AsyncMock(return_value=False)
    mock_token_blacklist_repository.blacklist_token = AsyncMock()

    await auth_service.logout_user(refresh_token)

    mock_token_blacklist_repository.is_blacklisted.assert_called_once_with(jti)
    mock_token_blacklist_repository.blacklist_token.assert_called_once()
