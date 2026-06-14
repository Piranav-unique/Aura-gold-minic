import uuid

import pytest
from decimal import Decimal
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.inventory_item import InventoryItemRepository
from app.services.inventory import InventoryService
from app.repositories.stock_movement import StockMovementRepository
from app.repositories.supplier import SupplierRepository

pytestmark = pytest.mark.integration


@pytest.mark.asyncio
async def test_opening_stock_creates_movement(test_db: AsyncSession):
    inventory_repo = InventoryItemRepository(test_db)
    movement_repo = StockMovementRepository(test_db)
    supplier_repo = SupplierRepository(test_db)
    service = InventoryService(inventory_repo, movement_repo, supplier_repo)

    from app.schemas.inventory import InventoryItemCreate

    item = await service.create_item(
        InventoryItemCreate(
            item_name=f"Opening_{uuid.uuid4().hex[:6]}",
            item_category="gold_bar",
            weight=Decimal("10"),
            purity=Decimal("99.9"),
            purchase_price=Decimal("50000"),
            current_value=Decimal("55000"),
            stock_quantity=12,
        )
    )

    assert item.stock_quantity == 12
    movements = await movement_repo.list_for_item(item.id)
    assert len(movements) == 1
    assert movements[0].movement_type == "stock_in"
    assert movements[0].quantity_before == 0
    assert movements[0].quantity_after == 12


@pytest.mark.asyncio
async def test_supplier_delete_blocked_when_linked(test_db: AsyncSession):
    from app.services.supplier import SupplierService
    from app.schemas.supplier import SupplierCreate
    from app.core.exceptions import ValidationException

    inventory_repo = InventoryItemRepository(test_db)
    movement_repo = StockMovementRepository(test_db)
    supplier_repo = SupplierRepository(test_db)
    supplier_service = SupplierService(supplier_repo)
    inventory_service = InventoryService(inventory_repo, movement_repo, supplier_repo)

    supplier = await supplier_service.create_supplier(
        SupplierCreate(name=f"Linked_{uuid.uuid4().hex[:6]}")
    )
    from app.schemas.inventory import InventoryItemCreate

    await inventory_service.create_item(
        InventoryItemCreate(
            item_name="Linked item",
            item_category="gold_coin",
            weight=Decimal("5"),
            purity=Decimal("91.6"),
            purchase_price=Decimal("25000"),
            current_value=Decimal("27000"),
            supplier_id=supplier.id,
        )
    )

    with pytest.raises(ValidationException, match="linked"):
        await supplier_service.delete_supplier(supplier.id)
