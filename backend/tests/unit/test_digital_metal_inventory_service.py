import uuid
from decimal import Decimal

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.digital_metal_inventory import DigitalMetalInventory
from app.repositories.digital_metal_inventory import (
    DigitalMetalInventoryMovementRepository,
    DigitalMetalInventoryRepository,
)
from app.schemas.digital_metal_inventory import DigitalMetalInventoryUpdate
from app.services.digital_metal_inventory import (
    DigitalMetalInventoryService,
    INSUFFICIENT_STOCK_MESSAGE,
)
from app.core.exceptions import ValidationException


@pytest.mark.asyncio
async def test_ensure_available_blocks_over_limit(test_db: AsyncSession):
    result = await test_db.execute(
        select(DigitalMetalInventory).where(
            DigitalMetalInventory.metal_type == "gold"
        )
    )
    row = result.scalars().first()
    assert row is not None
    row.total_weight_grams = Decimal("100")
    row.used_weight_grams = Decimal("99")
    await test_db.flush()

    service = DigitalMetalInventoryService(
        DigitalMetalInventoryRepository(test_db),
        DigitalMetalInventoryMovementRepository(test_db),
    )
    with pytest.raises(ValidationException, match=INSUFFICIENT_STOCK_MESSAGE):
        await service.ensure_available("gold", Decimal("2"))


@pytest.mark.asyncio
async def test_compute_stock_status_out_of_stock():
    from app.schemas.digital_metal_inventory import compute_stock_status

    assert compute_stock_status(Decimal("0"), Decimal("100")) == "out_of_stock"
    assert compute_stock_status(Decimal("50"), Decimal("100")) == "low_stock"
    assert compute_stock_status(Decimal("500"), Decimal("100")) == "available"


@pytest.mark.asyncio
async def test_update_metal_rejects_total_below_used(test_db: AsyncSession):
    result = await test_db.execute(
        select(DigitalMetalInventory).where(
            DigitalMetalInventory.metal_type == "gold"
        )
    )
    row = result.scalars().first()
    assert row is not None
    row.total_weight_grams = Decimal("100")
    row.used_weight_grams = Decimal("50")
    await test_db.flush()

    service = DigitalMetalInventoryService(
        DigitalMetalInventoryRepository(test_db),
        DigitalMetalInventoryMovementRepository(test_db),
    )
    with pytest.raises(ValidationException, match="cannot be less than used"):
        await service.update_metal(
            "gold",
            DigitalMetalInventoryUpdate(
                total_weight_grams=Decimal("40"),
                low_stock_threshold_grams=Decimal("5"),
            ),
            admin_user_id=uuid.uuid4(),
        )
