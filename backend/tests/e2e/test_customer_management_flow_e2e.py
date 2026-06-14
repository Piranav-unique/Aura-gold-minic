import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.e2e.conftest import (
    bearer_headers,
    create_e2e_user,
    create_role_with_permissions,
    login,
)

pytestmark = pytest.mark.e2e


def _unique_mobile(prefix: str = "98") -> str:
    """Generate a numeric-only mobile number valid for customer schema."""
    suffix = f"{uuid.uuid4().int % 100000000:08d}"
    return f"+91{prefix}{suffix[:8]}"


@pytest.mark.asyncio
async def test_e2e_customer_management_full_flow(
    db_client: AsyncClient,
    test_db: AsyncSession,
    admin_actor: tuple,
):
    """Create customer, update customer, delete customer."""
    admin_user, password = admin_actor
    tokens = await login(db_client, admin_user.email, password)
    headers = bearer_headers(tokens["access_token"])

    create_response = await db_client.post(
        "/api/v1/customers/",
        json={
            "customer_type": "business",
            "full_name": "E2E Gold Traders",
            "mobile_number": _unique_mobile(),
            "email": f"e2e_{uuid.uuid4().hex[:8]}@example.com",
            "address": "42 Bullion Street, Mumbai",
            "gst_number": "27AAAAA0000A1Z5",
            "status": "active",
        },
        headers=headers,
    )
    assert create_response.status_code == 201, create_response.text
    created = create_response.json()
    customer_id = created["id"]
    assert created["customer_type"] == "business"
    assert created["full_name"] == "E2E Gold Traders"

    list_response = await db_client.get(
        "/api/v1/customers/?search=E2E Gold",
        headers=headers,
    )
    assert list_response.status_code == 200
    page = list_response.json()
    assert page["total"] >= 1
    assert any(item["id"] == customer_id for item in page["items"])

    get_response = await db_client.get(
        f"/api/v1/customers/{customer_id}",
        headers=headers,
    )
    assert get_response.status_code == 200
    assert get_response.json()["email"] == created["email"]

    update_response = await db_client.put(
        f"/api/v1/customers/{customer_id}",
        json={"status": "inactive", "full_name": "E2E Updated Traders"},
        headers=headers,
    )
    assert update_response.status_code == 200
    assert update_response.json()["status"] == "inactive"
    assert update_response.json()["full_name"] == "E2E Updated Traders"

    delete_response = await db_client.delete(
        f"/api/v1/customers/{customer_id}",
        headers=headers,
    )
    assert delete_response.status_code == 200

    get_deleted = await db_client.get(
        f"/api/v1/customers/{customer_id}",
        headers=headers,
    )
    assert get_deleted.status_code == 404


@pytest.mark.asyncio
async def test_e2e_customer_rbac_enforcement(
    db_client: AsyncClient,
    test_db: AsyncSession,
    admin_actor: tuple,
):
    """Users without customer permissions cannot create customers."""
    admin_user, password = admin_actor
    await login(db_client, admin_user.email, password)

    view_only_role = await create_role_with_permissions(
        test_db,
        f"customer_view_{uuid.uuid4().hex[:6]}",
        ["customer.view"],
    )

    viewer_user, viewer_password = await create_e2e_user(
        test_db, view_only_role, email_prefix="viewer"
    )

    viewer_tokens = await login(db_client, viewer_user.email, viewer_password)
    viewer_headers = bearer_headers(viewer_tokens["access_token"])

    list_response = await db_client.get(
        "/api/v1/customers/",
        headers=viewer_headers,
    )
    assert list_response.status_code == 200

    create_response = await db_client.post(
        "/api/v1/customers/",
        json={
            "customer_type": "individual",
            "full_name": "Blocked User",
            "mobile_number": _unique_mobile("97"),
            "email": f"blocked_{uuid.uuid4().hex[:8]}@example.com",
            "address": "Nowhere",
        },
        headers=viewer_headers,
    )
    assert create_response.status_code == 403
