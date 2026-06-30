from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.gold_sell_inquiry import GoldSellInquiry
from app.models.user import User
from app.repositories.base import BaseRepository


class GoldSellInquiryRepository(BaseRepository[GoldSellInquiry]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(GoldSellInquiry, db_session)

    async def list_for_user(
        self,
        user_id,
        skip: int = 0,
        limit: int = 50,
    ) -> list[GoldSellInquiry]:
        query = (
            select(GoldSellInquiry)
            .where(GoldSellInquiry.user_id == user_id)
            .order_by(GoldSellInquiry.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_all(
        self,
        skip: int = 0,
        limit: int = 50,
        status: Optional[str] = None,
    ) -> list[GoldSellInquiry]:
        query = (
            select(GoldSellInquiry)
            .options(selectinload(GoldSellInquiry.user))
            .order_by(GoldSellInquiry.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        if status:
            query = query.where(GoldSellInquiry.status == status)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def count_all(self, status: Optional[str] = None) -> int:
        query = select(func.count()).select_from(GoldSellInquiry)
        if status:
            query = query.where(GoldSellInquiry.status == status)
        result = await self.db.execute(query)
        return int(result.scalar_one())

    async def count_for_user(self, user_id) -> int:
        query = (
            select(func.count())
            .select_from(GoldSellInquiry)
            .where(GoldSellInquiry.user_id == user_id)
        )
        result = await self.db.execute(query)
        return int(result.scalar_one())

    async def get_by_razorpay_payout_id(
        self, payout_id: str
    ) -> Optional[GoldSellInquiry]:
        query = (
            select(GoldSellInquiry)
            .options(selectinload(GoldSellInquiry.user))
            .where(GoldSellInquiry.razorpay_payout_id == payout_id)
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_with_user(self, inquiry_id) -> Optional[GoldSellInquiry]:
        query = (
            select(GoldSellInquiry)
            .options(selectinload(GoldSellInquiry.user))
            .where(GoldSellInquiry.id == inquiry_id)
        )
        result = await self.db.execute(query)
        return result.scalars().first()
