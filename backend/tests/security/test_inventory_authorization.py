import pytest
from httpx import AsyncClient

from tests.security.conftest import create_user_with_permissions

pytestmark = pytest.mark.security


@pytest.mark.asyncio
async def test_inventory_view_allowed_with_permission(db_client: AsyncClient, test_db):
    _, headers = await create_user_with_permissions(test_db, ["inventory.view"])

    response = await db_client.get("/api/v1/inventory/", headers=headers)
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_inventory_create_forbidden_without_permission(
    db_client: AsyncClient, test_db
):
    _, headers = await create_user_with_permissions(test_db, ["inventory.view"])

    response = await db_client.post(
        "/api/v1/inventory/",
        json={
            "item_name": "Blocked Item",
            "item_category": "gold_bar",
            "weight": "10",
            "purity": "99.9",
            "purchase_price": "50000",
            "current_value": "55000",
        },
        headers=headers,
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_stock_out_requires_update_permission(db_client: AsyncClient, test_db):
    _, headers = await create_user_with_permissions(test_db, ["inventory.view"])

    response = await db_client.post(
        "/api/v1/inventory/00000000-0000-0000-0000-000000000001/stock-out",
        json={"quantity": 1},
        headers=headers,
    )
    assert response.status_code == 403
