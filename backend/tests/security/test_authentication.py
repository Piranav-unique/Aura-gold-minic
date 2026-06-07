import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, get_password_hash
from app.models.role import Role
from app.models.user import User
from tests.security.conftest import (
    make_expired_token,
    make_refresh_as_access_token,
    make_tampered_token,
)

pytestmark = pytest.mark.security


@pytest.mark.asyncio
async def test_invalid_login_wrong_password(db_client: AsyncClient, test_db: AsyncSession):
    user = User(
        email="auth_wrong_pw@example.com",
        hashed_password=get_password_hash("correctpassword"),
        is_active=True,
    )
    test_db.add(user)
    await test_db.flush()

    response = await db_client.post(
        "/api/v1/auth/login",
        json={"email": "auth_wrong_pw@example.com", "password": "wrongpassword"},
    )

    assert response.status_code == 401
    body = response.json()
    assert "error" in body
    assert "access_token" not in body
    assert "incorrect email or password" in body["error"]["message"].lower()


@pytest.mark.asyncio
async def test_invalid_login_unknown_email(db_client: AsyncClient):
    response = await db_client.post(
        "/api/v1/auth/login",
        json={"email": "nonexistent@example.com", "password": "anypassword1"},
    )

    assert response.status_code == 401
    body = response.json()
    assert "error" in body
    assert "incorrect email or password" in body["error"]["message"].lower()


@pytest.mark.asyncio
async def test_invalid_login_inactive_user(db_client: AsyncClient, test_db: AsyncSession):
    user = User(
        email="inactive_auth@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=False,
    )
    test_db.add(user)
    await test_db.flush()

    response = await db_client.post(
        "/api/v1/auth/login",
        json={"email": "inactive_auth@example.com", "password": "password123"},
    )

    assert response.status_code == 401
    assert "incorrect email or password" in response.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_expired_access_token_rejected(
    db_client: AsyncClient, test_db: AsyncSession
):
    user = User(
        email="expired_token@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
    )
    test_db.add(user)
    await test_db.flush()

    token = make_expired_token(user.id)
    response = await db_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 401
    body = response.json()
    assert body["error"]["type"] == "AuthenticationException"
    assert "expired" in body["error"]["message"].lower()


@pytest.mark.asyncio
async def test_tampered_token_signature_rejected(
    db_client: AsyncClient, test_db: AsyncSession
):
    user = User(
        email="tampered@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
    )
    test_db.add(user)
    await test_db.flush()

    token = make_tampered_token(user.id)
    response = await db_client.get(
        "/api/v1/users/",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["type"] == "AuthenticationException"


@pytest.mark.asyncio
async def test_refresh_token_used_as_access_rejected(
    db_client: AsyncClient, test_db: AsyncSession
):
    user = User(
        email="refresh_as_access@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
    )
    test_db.add(user)
    await test_db.flush()

    token = make_refresh_as_access_token(user.id)
    response = await db_client.get(
        "/api/v1/users/",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 401
    body = response.json()
    assert body["error"]["type"] == "AuthenticationException"
    assert "token type" in body["error"]["message"].lower()


@pytest.mark.asyncio
async def test_missing_token_returns_401(db_client: AsyncClient):
    response = await db_client.get("/api/v1/users/")
    assert response.status_code == 401
    assert response.json() == {"detail": "Not authenticated"}


@pytest.mark.asyncio
async def test_malformed_authorization_header_rejected(db_client: AsyncClient):
    for headers in (
        {"Authorization": "Bearer"},
        {"Authorization": "Bearer not.a.valid.jwt"},
        {"Authorization": "Basic dXNlcjpwYXNz"},
    ):
        response = await db_client.get("/api/v1/users/", headers=headers)
        assert response.status_code == 401
