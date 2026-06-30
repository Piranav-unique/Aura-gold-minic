import uuid
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.digital_metal_inventory import DigitalMetalInventory
from tests.security.conftest import create_user_with_permissions


@pytest.mark.asyncio
async def test_list_metals_requires_permission(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(test_db, ["customer.view"])
    response = await db_client.get(
        "/api/v1/admin/inventory/metals", headers=headers
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_list_metals_success(db_client: AsyncClient, test_db: AsyncSession):
    _, headers = await create_user_with_permissions(test_db, ["inventory.view"])
    response = await db_client.get(
        "/api/v1/admin/inventory/metals", headers=headers
    )
    assert response.status_code == 200
    data = response.json()
    metals = {item["metal_type"] for item in data["items"]}
    assert metals == {"gold", "silver"}
    gold = next(i for i in data["items"] if i["metal_type"] == "gold")
    assert Decimal(gold["available_weight_grams"]) > 0


@pytest.mark.asyncio
async def test_update_metal_requires_update_permission(
    db_client: AsyncClient, test_db: AsyncSession
):
    _, headers = await create_user_with_permissions(test_db, ["inventory.view"])
    response = await db_client.put(
        "/api/v1/admin/inventory/metals/gold",
        headers=headers,
        json={
            "total_weight_grams": "20000",
            "low_stock_threshold_grams": "500",
        },
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_update_metal_success(db_client: AsyncClient, test_db: AsyncSession):
    admin, headers = await create_user_with_permissions(
        test_db, ["inventory.view", "inventory.update"]
    )
    response = await db_client.put(
        "/api/v1/admin/inventory/metals/gold",
        headers=headers,
        json={
            "total_weight_grams": "20000",
            "low_stock_threshold_grams": "800",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert Decimal(data["total_weight_grams"]) == Decimal("20000")
    assert Decimal(data["low_stock_threshold_grams"]) == Decimal("800")
    assert data["updated_by"] == str(admin.id)

    movements = await db_client.get(
        "/api/v1/admin/inventory/metals/gold/movements",
        headers=headers,
    )
    assert movements.status_code == 200
    assert movements.json()["total"] >= 1


@pytest.mark.asyncio
async def test_alerts_low_stock(db_client: AsyncClient, test_db: AsyncSession):
    result = await test_db.execute(
        select(DigitalMetalInventory).where(
            DigitalMetalInventory.metal_type == "silver"
        )
    )
    row = result.scalars().first()
    assert row is not None
    row.total_weight_grams = Decimal("100")
    row.used_weight_grams = Decimal("95")
    row.low_stock_threshold_grams = Decimal("10")
    await test_db.flush()

    _, headers = await create_user_with_permissions(test_db, ["inventory.view"])
    response = await db_client.get(
        "/api/v1/admin/inventory/alerts", headers=headers
    )
    assert response.status_code == 200
    alerts = response.json()["items"]
    silver_alerts = [a for a in alerts if a["metal_type"] == "silver"]
    assert silver_alerts
    assert silver_alerts[0]["stock_status"] == "low_stock"
