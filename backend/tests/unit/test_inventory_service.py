import uuid
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.exceptions import NotFoundException, ValidationException
from app.models.inventory_item import InventoryItem
from app.repositories.inventory_item import InventoryItemRepository
from app.repositories.stock_movement import StockMovementRepository
from app.repositories.supplier import SupplierRepository
from app.schemas.inventory import (
    InventoryItemCreate,
    InventoryItemUpdate,
    StockAdjustRequest,
    StockInRequest,
    StockOutRequest,
)
from app.services.audit import AuditService
from app.services.inventory import InventoryService


@pytest.fixture
def mock_inventory_repo():
    repo = MagicMock(spec=InventoryItemRepository)
    repo.db = MagicMock()
    repo.db.commit = AsyncMock()
    repo.db.flush = AsyncMock()
    return repo


@pytest.fixture
def mock_movement_repo():
    repo = MagicMock(spec=StockMovementRepository)
    repo.db = MagicMock()
    repo.db.add = MagicMock()
    repo.db.commit = AsyncMock()
    repo.db.refresh = AsyncMock()
    return repo


@pytest.fixture
def mock_supplier_repo():
    return MagicMock(spec=SupplierRepository)


@pytest.fixture
def mock_audit_service():
    return MagicMock(spec=AuditService)


@pytest.fixture
def inventory_service(
    mock_inventory_repo, mock_movement_repo, mock_supplier_repo, mock_audit_service
):
    return InventoryService(
        mock_inventory_repo,
        mock_movement_repo,
        mock_supplier_repo,
        mock_audit_service,
    )


def _sample_item(**overrides) -> InventoryItem:
    now = datetime.now(timezone.utc)
    data = {
        "id": uuid.uuid4(),
        "item_name": "Gold Bar 10g",
        "item_category": "gold_bar",
        "weight": Decimal("10.0000"),
        "purity": Decimal("99.900"),
        "purchase_price": Decimal("50000.00"),
        "current_value": Decimal("55000.00"),
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
async def test_create_item_success(
    inventory_service, mock_inventory_repo, mock_audit_service
):
    item_in = InventoryItemCreate(
        item_name="Gold Bar 10g",
        item_category="gold_bar",
        weight=Decimal("10"),
        purity=Decimal("99.9"),
        purchase_price=Decimal("50000"),
        current_value=Decimal("55000"),
    )
    created = _sample_item()
    mock_inventory_repo.create = AsyncMock(return_value=created)
    mock_inventory_repo.get_active = AsyncMock(return_value=created)
    mock_audit_service.log_action = AsyncMock()

    result = await inventory_service.create_item(
        item_in, performing_user_id=uuid.uuid4()
    )

    assert result.item_name == "Gold Bar 10g"
    mock_audit_service.log_action.assert_called_once()
    mock_inventory_repo.db.commit.assert_called_once()


@pytest.mark.asyncio
async def test_create_item_records_opening_stock_movement(
    inventory_service, mock_inventory_repo, mock_movement_repo, mock_audit_service
):
    item_in = InventoryItemCreate(
        item_name="Gold Bar 10g",
        item_category="gold_bar",
        weight=Decimal("10"),
        purity=Decimal("99.9"),
        purchase_price=Decimal("50000"),
        current_value=Decimal("55000"),
        stock_quantity=8,
    )
    created = _sample_item(stock_quantity=8)
    mock_inventory_repo.create = AsyncMock(return_value=created)
    mock_inventory_repo.get_active = AsyncMock(return_value=created)
    mock_audit_service.log_action = AsyncMock()

    await inventory_service.create_item(item_in, performing_user_id=uuid.uuid4())

    assert mock_inventory_repo.create.call_args[0][0]["stock_quantity"] == 0
    assert mock_movement_repo.db.add.called
    assert mock_audit_service.log_action.call_count == 2


@pytest.mark.asyncio
async def test_stock_out_insufficient_stock(inventory_service, mock_inventory_repo):
    item = _sample_item(stock_quantity=2)
    mock_inventory_repo.get_active_for_update = AsyncMock(return_value=item)

    with pytest.raises(ValidationException, match="Insufficient stock"):
        await inventory_service.stock_out(
            item.id, StockOutRequest(quantity=5), performing_user_id=uuid.uuid4()
        )


@pytest.mark.asyncio
async def test_stock_in_increases_quantity(
    inventory_service, mock_inventory_repo, mock_movement_repo, mock_audit_service
):
    item = _sample_item(stock_quantity=5)
    updated = _sample_item(stock_quantity=15)
    mock_inventory_repo.get_active_for_update = AsyncMock(return_value=item)
    mock_inventory_repo.get_active = AsyncMock(return_value=updated)
    mock_audit_service.log_action = AsyncMock()

    result = await inventory_service.stock_in(
        item.id,
        StockInRequest(quantity=10, reference="PO-001"),
        performing_user_id=uuid.uuid4(),
    )

    assert result.stock_quantity == 15
    mock_movement_repo.db.commit.assert_called()
    mock_audit_service.log_action.assert_called_once()


@pytest.mark.asyncio
async def test_stock_adjust_no_change_raises(inventory_service, mock_inventory_repo):
    item = _sample_item(stock_quantity=10)
    mock_inventory_repo.get_active_for_update = AsyncMock(return_value=item)

    with pytest.raises(ValidationException, match="matches current stock"):
        await inventory_service.stock_adjust(
            item.id,
            StockAdjustRequest(new_quantity=10),
            performing_user_id=uuid.uuid4(),
        )


@pytest.mark.asyncio
async def test_delete_item_not_found(inventory_service, mock_inventory_repo):
    mock_inventory_repo.get_active = AsyncMock(return_value=None)

    with pytest.raises(NotFoundException):
        await inventory_service.delete_item(uuid.uuid4())


@pytest.mark.asyncio
async def test_update_item_success(
    inventory_service, mock_inventory_repo, mock_audit_service
):
    item = _sample_item()
    mock_inventory_repo.get_active = AsyncMock(return_value=item)
    mock_inventory_repo.db.commit = AsyncMock()
    mock_inventory_repo.db.refresh = AsyncMock()
    mock_audit_service.log_action = AsyncMock()

    result = await inventory_service.update_item(
        item.id,
        InventoryItemUpdate(item_name="Updated Name"),
        performing_user_id=uuid.uuid4(),
    )

    assert result.item_name == "Updated Name"


@pytest.mark.asyncio
async def test_stock_out_on_inactive_item_raises(
    inventory_service, mock_inventory_repo
):
    item = _sample_item(status="inactive")
    mock_inventory_repo.get_active_for_update = AsyncMock(return_value=item)

    with pytest.raises(ValidationException, match="active items"):
        await inventory_service.stock_out(
            item.id, StockOutRequest(quantity=1), performing_user_id=uuid.uuid4()
        )
