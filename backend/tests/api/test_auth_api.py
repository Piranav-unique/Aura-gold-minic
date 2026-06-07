import pytest
import uuid
from datetime import datetime, timezone
from httpx import AsyncClient

from app.core.security import get_password_hash, create_access_token, create_refresh_token
from app.models.user import User
from app.models.token_blacklist import TokenBlacklist


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient, db_session):
    """Verify that valid login credentials return access and refresh tokens."""
    hashed_pwd = get_password_hash("password123")
    user_id = uuid.uuid4()
    mock_user = User(
        id=user_id,
        email="test@example.com",
        hashed_password=hashed_pwd,
        is_active=True,
        is_deleted=False,
    )

    async def mock_execute(*args, **kwargs):
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        return mock_user
                return MockScalars()
        return MockResult()

    db_session.execute = mock_execute

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "test@example.com", "password": "password123"},
    )

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_login_invalid_credentials(client: AsyncClient, db_session):
    """Verify that invalid credentials yield a 401 unauthorized status."""
    async def mock_execute(*args, **kwargs):
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        return None
                return MockScalars()
        return MockResult()

    db_session.execute = mock_execute

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "wrong@example.com", "password": "wrongpassword"},
    )

    assert response.status_code == 401
    data = response.json()
    assert "error" in data
    assert "incorrect email or password" in data["error"]["message"].lower()


@pytest.mark.asyncio
async def test_refresh_token_success(client: AsyncClient, db_session):
    """Verify that a valid refresh token returns a rotated set of tokens."""
    user_id = uuid.uuid4()
    jti = str(uuid.uuid4())
    refresh_token = create_refresh_token(subject=user_id, jti=jti)

    mock_user = User(
        id=user_id,
        email="test@example.com",
        is_active=True,
        is_deleted=False,
    )

    # Mock execute returns:
    # 1st call (checking if token is blacklisted): None
    # 2nd call (getting user by ID): mock_user
    call_count = 0
    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        if call_count == 1:
                            return None  # Not blacklisted
                        return mock_user  # Found user
                return MockScalars()
        return MockResult()

    async def mock_get(model, id):
        if model == User:
            return mock_user
        return None

    db_session.execute = mock_execute
    db_session.get = mock_get

    response = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data


@pytest.mark.asyncio
async def test_logout_success(client: AsyncClient, db_session):
    """Verify that logging out blacklists the token and returns a 200 OK status."""
    user_id = uuid.uuid4()
    jti = str(uuid.uuid4())
    refresh_token = create_refresh_token(subject=user_id, jti=jti)

    # Mock token check (not blacklisted yet)
    async def mock_execute(*args, **kwargs):
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        return None
                return MockScalars()
        return MockResult()

    db_session.execute = mock_execute

    response = await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refresh_token},
    )

    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "logged out" in data["message"].lower()


@pytest.mark.asyncio
async def test_current_user_me(client: AsyncClient, db_session):
    """Verify that GET /me returns the user profile details for a valid access token."""
    user_id = uuid.uuid4()
    access_token = create_access_token(subject=user_id)

    mock_user = User(
        id=user_id,
        email="test@example.com",
        first_name="John",
        last_name="Doe",
        is_active=True,
        is_superuser=False,
        is_deleted=False,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    async def mock_execute(*args, **kwargs):
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        return mock_user
                return MockScalars()
        return MockResult()

    db_session.execute = mock_execute

    response = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "test@example.com"
    assert data["first_name"] == "John"
    assert data["last_name"] == "Doe"
