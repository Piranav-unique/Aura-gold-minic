import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import get_password_hash
from app.middleware.rate_limit_middleware import reset_rate_limit_store
from app.models.user import User
from tests.security.conftest import create_user_with_permissions

pytestmark = pytest.mark.security

SQL_INJECTION_PAYLOADS = [
    "' OR 1=1 --",
    '"; DROP TABLE users; --',
    "1'; SELECT * FROM users; --",
    "admin'--",
]

SQL_ERROR_FRAGMENTS = ("syntax error", "pg_", "asyncpg", "sqlalchemy")


@pytest.mark.asyncio
@pytest.mark.parametrize("payload", SQL_INJECTION_PAYLOADS)
async def test_sql_injection_search_param_safe(
    db_client: AsyncClient, test_db: AsyncSession, payload: str
):
    _, headers = await create_user_with_permissions(test_db, ["user.view"])

    response = await db_client.get(
        "/api/v1/users/",
        params={"search": payload},
        headers=headers,
    )

    assert response.status_code in (200, 401, 422)
    body_text = response.text.lower()
    for fragment in SQL_ERROR_FRAGMENTS:
        assert fragment not in body_text


@pytest.mark.asyncio
@pytest.mark.parametrize("payload", SQL_INJECTION_PAYLOADS)
async def test_sql_injection_login_email_safe(db_client: AsyncClient, payload: str):
    response = await db_client.post(
        "/api/v1/auth/login",
        json={"email": payload, "password": "password123"},
    )

    assert response.status_code in (401, 422)
    body_text = response.text.lower()
    for fragment in SQL_ERROR_FRAGMENTS:
        assert fragment not in body_text


@pytest.mark.asyncio
async def test_xss_payload_stored_as_literal_json(
    db_client: AsyncClient, test_db: AsyncSession
):
    xss_payload = "<script>alert('xss')</script>"
    admin_user = User(
        email=f"admin_xss_{uuid.uuid4().hex[:6]}@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
        is_superuser=True,
    )
    test_db.add(admin_user)
    await test_db.flush()

    from app.core.security import create_access_token

    admin_headers = {
        "Authorization": f"Bearer {create_access_token(subject=str(admin_user.id))}"
    }

    create_res = await db_client.post(
        "/api/v1/users/",
        json={
            "email": f"xss_target_{uuid.uuid4().hex[:6]}@example.com",
            "password": "password123",
            "first_name": xss_payload,
            "last_name": "User",
        },
        headers=admin_headers,
    )
    assert create_res.status_code == 201
    user_id = create_res.json()["id"]

    get_res = await db_client.get(
        f"/api/v1/users/{user_id}",
        headers=admin_headers,
    )
    assert get_res.status_code == 200
    assert get_res.headers["content-type"].startswith("application/json")
    assert get_res.json()["first_name"] == xss_payload


@pytest.mark.asyncio
async def test_rate_limiting_blocks_excessive_login_attempts(
    db_client: AsyncClient, rate_limit_settings
):
    login_body = {"email": "nobody@example.com", "password": "wrongpass1"}

    responses = []
    for _ in range(5):
        responses.append(await db_client.post("/api/v1/auth/login", json=login_body))

    status_codes = [r.status_code for r in responses]
    assert 429 in status_codes
    rate_limited = next(r for r in responses if r.status_code == 429)
    body = rate_limited.json()
    assert body["error"]["type"] == "RateLimitException"
    assert body["error"]["status_code"] == 429


@pytest.mark.asyncio
async def test_rate_limit_allows_requests_under_limit(db_client: AsyncClient):
    reset_rate_limit_store()
    original_max = settings.RATE_LIMIT_LOGIN_MAX
    settings.RATE_LIMIT_LOGIN_MAX = 10
    try:
        for _ in range(3):
            res = await db_client.post(
                "/api/v1/auth/login",
                json={"email": "under_limit@example.com", "password": "wrongpass1"},
            )
            assert res.status_code in (401, 422)
    finally:
        settings.RATE_LIMIT_LOGIN_MAX = original_max
        reset_rate_limit_store()


@pytest.mark.asyncio
async def test_validation_short_password_rejected(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(
        test_db, ["user.create", "user.view"], is_superuser=True
    )

    response = await db_client.post(
        "/api/v1/users/",
        json={
            "email": f"shortpw_{uuid.uuid4().hex[:6]}@example.com",
            "password": "short",
        },
        headers=headers,
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_validation_invalid_email_rejected(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(
        test_db, ["user.create"], is_superuser=True
    )

    response = await db_client.post(
        "/api/v1/users/",
        json={"email": "not-an-email", "password": "password123"},
        headers=headers,
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_validation_invalid_uuid_path_rejected(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(test_db, ["user.view"])

    response = await db_client.get("/api/v1/users/not-a-uuid", headers=headers)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_validation_empty_login_body_rejected(db_client: AsyncClient):
    response = await db_client.post("/api/v1/auth/login", json={})
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_validation_limit_above_max_rejected(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(test_db, ["user.view"])

    response = await db_client.get(
        "/api/v1/users/",
        params={"limit": 9999},
        headers=headers,
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_validation_oversized_first_name_rejected(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(
        test_db, ["user.create"], is_superuser=True
    )

    response = await db_client.post(
        "/api/v1/users/",
        json={
            "email": f"longname_{uuid.uuid4().hex[:6]}@example.com",
            "password": "password123",
            "first_name": "x" * 101,
        },
        headers=headers,
    )
    assert response.status_code == 422
