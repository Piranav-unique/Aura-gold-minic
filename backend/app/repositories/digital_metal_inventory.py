from __future__ import annotations

import uuid
from decimal import Decimal
from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.digital_metal_inventory import (
    DigitalMetalInventory,
    DigitalMetalInventoryMovement,
    DigitalMetalStockSubscription,
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


class DigitalMetalStockSubscriptionRepository(
    BaseRepository[DigitalMetalStockSubscription]
):
    def __init__(self, db_session: AsyncSession):
        super().__init__(DigitalMetalStockSubscription, db_session)

    async def subscribe(
        self, user_id: uuid.UUID, metal_type: str
    ) -> DigitalMetalStockSubscription:
        metal = metal_type.lower()
        stmt = select(DigitalMetalStockSubscription).where(
            DigitalMetalStockSubscription.user_id == user_id,
            DigitalMetalStockSubscription.metal_type == metal,
        )
        res = await self.db.execute(stmt)
        sub = res.scalars().first()
        if sub:
            sub.is_active = True
        else:
            sub = DigitalMetalStockSubscription(
                id=uuid.uuid4(),
                user_id=user_id,
                metal_type=metal,
                is_active=True,
            )
            self.db.add(sub)
        await self.db.commit()
        await self.db.refresh(sub)
        return sub

    async def get_active_subscribers(
        self, metal_type: str
    ) -> list[DigitalMetalStockSubscription]:
        stmt = select(DigitalMetalStockSubscription).where(
            DigitalMetalStockSubscription.metal_type == metal_type.lower(),
            DigitalMetalStockSubscription.is_active == True,
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def deactivate_subscriptions(self, metal_type: str) -> None:
        stmt = select(DigitalMetalStockSubscription).where(
            DigitalMetalStockSubscription.metal_type == metal_type.lower(),
            DigitalMetalStockSubscription.is_active == True,
        )
        res = await self.db.execute(stmt)
        for sub in res.scalars().all():
            sub.is_active = False
        await self.db.commit()

