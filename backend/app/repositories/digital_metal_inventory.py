from __future__ import annotations

import uuid
from decimal import Decimal
from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.digital_metal_inventory import (
    DigitalMetalInventory,
    DigitalMetalInventoryMovement,
)
from app.repositories.base import BaseRepository


class DigitalMetalInventoryRepository(BaseRepository[DigitalMetalInventory]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(DigitalMetalInventory, db_session)

    async def list_all(self) -> list[DigitalMetalInventory]:
        result = await self.db.execute(
            select(DigitalMetalInventory).order_by(DigitalMetalInventory.metal_type)
        )
        return list(result.scalars().all())

    async def get_by_metal(self, metal_type: str) -> Optional[DigitalMetalInventory]:
        result = await self.db.execute(
            select(DigitalMetalInventory).where(
                DigitalMetalInventory.metal_type == metal_type.lower()
            )
        )
        return result.scalars().first()

    async def get_by_metal_for_update(
        self, metal_type: str
    ) -> Optional[DigitalMetalInventory]:
        result = await self.db.execute(
            select(DigitalMetalInventory)
            .where(DigitalMetalInventory.metal_type == metal_type.lower())
            .with_for_update()
        )
        return result.scalars().first()


class DigitalMetalInventoryMovementRepository(
    BaseRepository[DigitalMetalInventoryMovement]
):
    def __init__(self, db_session: AsyncSession):
        super().__init__(DigitalMetalInventoryMovement, db_session)

    async def list_for_metal(
        self,
        metal_type: str,
        *,
        skip: int = 0,
        limit: int = 50,
    ) -> tuple[list[DigitalMetalInventoryMovement], int]:
        base = select(DigitalMetalInventoryMovement).where(
            DigitalMetalInventoryMovement.metal_type == metal_type.lower()
        )
        count_result = await self.db.execute(
            select(func.count()).select_from(base.subquery())
        )
        total = int(count_result.scalar_one() or 0)
        result = await self.db.execute(
            base.order_by(DigitalMetalInventoryMovement.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all()), total

    async def has_purchase_debit_for_order(
        self, payment_order_id: uuid.UUID
    ) -> bool:
        result = await self.db.execute(
            select(func.count())
            .select_from(DigitalMetalInventoryMovement)
            .where(
                DigitalMetalInventoryMovement.payment_order_id == payment_order_id,
                DigitalMetalInventoryMovement.movement_type == "purchase_debit",
            )
        )
        return int(result.scalar_one() or 0) > 0
