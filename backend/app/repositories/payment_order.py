import uuid
from decimal import Decimal
from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.payment_order import PaymentOrder
from app.repositories.base import BaseRepository


class PaymentOrderRepository(BaseRepository[PaymentOrder]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(PaymentOrder, db_session)

    async def get_by_razorpay_order_id(
        self, razorpay_order_id: str
    ) -> Optional[PaymentOrder]:
        result = await self.db.execute(
            select(PaymentOrder).where(
                PaymentOrder.razorpay_order_id == razorpay_order_id
            )
        )
        return result.scalar_one_or_none()

    async def get_by_razorpay_payment_id(
        self, razorpay_payment_id: str
    ) -> Optional[PaymentOrder]:
        result = await self.db.execute(
            select(PaymentOrder).where(
                PaymentOrder.razorpay_payment_id == razorpay_payment_id
            )
        )
        return result.scalar_one_or_none()

    async def get_for_user(
        self, order_id: uuid.UUID, user_id: uuid.UUID
    ) -> Optional[PaymentOrder]:
        result = await self.db.execute(
            select(PaymentOrder).where(
                PaymentOrder.id == order_id,
                PaymentOrder.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def list_paid_orders(
        self,
        skip: int = 0,
        limit: int = 50,
    ) -> list[PaymentOrder]:
        query = (
            select(PaymentOrder)
            .options(selectinload(PaymentOrder.user))
            .where(PaymentOrder.status == "paid")
            .order_by(PaymentOrder.paid_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_orders(
        self,
        *,
        skip: int = 0,
        limit: int = 50,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> list[PaymentOrder]:
        from app.models.user import User
        from sqlalchemy import or_

        ts_col = func.coalesce(PaymentOrder.paid_at, PaymentOrder.created_at)
        query = (
            select(PaymentOrder)
            .options(selectinload(PaymentOrder.user))
            .order_by(ts_col.desc())
        )
        if status:
            if status in {"paid", "captured"}:
                query = query.where(PaymentOrder.status == "paid")
            elif status in {"pending", "created"}:
                query = query.where(PaymentOrder.status == "created")
            else:
                query = query.where(PaymentOrder.status == status)

        if search:
            search_term = f"%{search.strip()}%"
            query = query.outerjoin(PaymentOrder.user).where(
                or_(
                    PaymentOrder.razorpay_payment_id.ilike(search_term),
                    PaymentOrder.razorpay_order_id.ilike(search_term),
                    PaymentOrder.bank_rrn.ilike(search_term),
                    PaymentOrder.customer_contact.ilike(search_term),
                    User.mobile_number.ilike(search_term),
                    User.email.ilike(search_term),
                    User.first_name.ilike(search_term),
                )
            )

        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def count_paid_orders(self) -> int:
        result = await self.db.execute(
            select(func.count())
            .select_from(PaymentOrder)
            .where(PaymentOrder.status == "paid")
        )
        return int(result.scalar_one())

    async def get_orders_summary(self) -> dict:
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

        # Total captured
        captured_res = await self.db.execute(
            select(
                func.count(),
                func.coalesce(func.sum(PaymentOrder.amount_paise), 0),
            ).where(PaymentOrder.status == "paid")
        )
        captured_count, captured_paise = captured_res.one()

        # Total pending
        pending_res = await self.db.execute(
            select(func.count()).where(PaymentOrder.status == "created")
        )
        pending_count = int(pending_res.scalar_one() or 0)

        # Total failed
        failed_res = await self.db.execute(
            select(func.count()).where(PaymentOrder.status == "failed")
        )
        failed_count = int(failed_res.scalar_one() or 0)

        # Today's captured
        ts_col = func.coalesce(PaymentOrder.paid_at, PaymentOrder.created_at)
        today_res = await self.db.execute(
            select(
                func.count(),
                func.coalesce(func.sum(PaymentOrder.amount_paise), 0),
            ).where(PaymentOrder.status == "paid", ts_col >= day_start)
        )
        today_count, today_paise = today_res.one()

        return {
            "total_captured_revenue": Decimal(captured_paise) / Decimal("100"),
            "total_captured_count": int(captured_count),
            "total_pending_count": pending_count,
            "total_failed_count": failed_count,
            "today_captured_revenue": Decimal(today_paise) / Decimal("100"),
            "today_captured_count": int(today_count),
        }
