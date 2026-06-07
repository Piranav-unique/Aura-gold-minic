import pytest
from httpx import AsyncClient

from tests.e2e.conftest import bearer_headers, login

pytestmark = pytest.mark.e2e


@pytest.mark.asyncio
async def test_e2e_login_dashboard_logout_flow(
    db_client: AsyncClient, admin_actor: tuple
):
    """Full login flow: authenticate, access dashboard data, logout."""
    user, password = admin_actor

    tokens = await login(db_client, user.email, password)
    assert "access_token" in tokens
    assert "refresh_token" in tokens

    headers = bearer_headers(tokens["access_token"])

    me_response = await db_client.get("/api/v1/auth/me", headers=headers)
    assert me_response.status_code == 200
    profile = me_response.json()
    assert profile["email"] == user.email

    audit_response = await db_client.get("/api/v1/audit-logs/?limit=5", headers=headers)
    assert audit_response.status_code == 200
    assert isinstance(audit_response.json(), list)

    logout_response = await db_client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert logout_response.status_code == 200
    assert "logged out" in logout_response.json()["message"].lower()

    refresh_response = await db_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert refresh_response.status_code == 401
