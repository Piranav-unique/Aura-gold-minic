import uuid
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock

import pytest
from httpx import AsyncClient

from app.core.security import create_access_token
from app.models.inventory_item import InventoryItem
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User


def make_mock_result(val, is_list=False):
    class MockScalars:
        def first(self):
            return None if is_list else val

        def all(self):
            return val if is_list else [val]

        def unique(self):
            return self

    class MockResult:
        def scalars(self):
            return MockScalars()

        def all(self):
            return val if is_list else [val]

        def one(self):
            return val

    return MockResult()


@pytest.fixture
def inventory_permissions():
    now = datetime.now(timezone.utc)
    names = [
        "inventory.view",
        "inventory.create",
        "inventory.update",
        "inventory.delete",
    ]
    return {
        name.split(".")[1]: Permission(
            id=uuid.uuid4(), name=name, created_at=now, updated_at=now
        )
        for name in names
    }


@pytest.fixture
def authorized_user(inventory_permissions):
    now = datetime.now(timezone.utc)
    role = Role(
        id=uuid.uuid4(),
        name="InventoryAdmin",
        permissions=list(inventory_permissions.values()),
        created_at=now,
        updated_at=now,
    )
    return User(
        id=uuid.uuid4(),
        email="inventory@example.com",
        first_name="Inv",
        last_name="Admin",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=now,
        updated_at=now,
    )


def _sample_item(**overrides) -> InventoryItem:
    now = datetime.now(timezone.utc)
    data = {
        "id": uuid.uuid4(),
        "item_name": "Gold Bar",
        "item_category": "gold_bar",
        "weight": Decimal("10"),
        "purity": Decimal("99.9"),
        "purchase_price": Decimal("50000"),
        "current_value": Decimal("55000"),
        "stock_quantity": 10,
        "reorder_level": 5,
        "supplier_id": None,
        "status": "active",
        "notes": None,
        "is_deleted": False,
        "created_at": now,
        "updated_at": now,
    }
    data.update(overrides)
    return InventoryItem(**data)


@pytest.mark.asyncio
async def test_list_inventory_requires_auth(client: AsyncClient):
    response = await client.get("/api/v1/inventory/")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_list_inventory_success(
    client: AsyncClient, authorized_user, monkeypatch
):
    token = create_access_token(subject=str(authorized_user.id))
    item = _sample_item()

    async def mock_get_with_roles(user_id):
        return authorized_user

    monkeypatch.setattr(
        "app.api.dependencies.UserRepository.get_with_roles_and_permissions",
        AsyncMock(side_effect=mock_get_with_roles),
    )

    async def mock_list_items(*args, **kwargs):
        return [item], 1

    monkeypatch.setattr(
        "app.services.inventory.InventoryService.list_items",
        AsyncMock(side_effect=mock_list_items),
    )

    response = await client.get(
        "/api/v1/inventory/",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert data["items"][0]["item_name"] == "Gold Bar"
