from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

from sqlalchemy import cast, Date, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.associations import user_roles
from app.models.gold_sell_inquiry import GoldSellInquiry
from app.models.payment_order import PaymentOrder
from app.models.referral_reward import ReferralReward
from app.models.role import Role
from app.models.user import User


class AppMetricsRepository:
    """Aggregated metrics for the gold app (payments, members, wallet activity)."""

    def __init__(self, db_session: AsyncSession):
        self.db = db_session

    @staticmethod
    def _month_bounds(now: Optional[datetime] = None) -> tuple[datetime, datetime]:
        now = now or datetime.now(timezone.utc)
        day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        month_start = day_start.replace(day=1)
        day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)
        return month_start, day_end

    async def paid_revenue_sum(
        self,
        *,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> Decimal:
        ts_col = func.coalesce(PaymentOrder.paid_at, PaymentOrder.created_at)
        query = select(
            func.coalesce(func.sum(PaymentOrder.amount_paise), 0)
        ).where(PaymentOrder.status == "paid")
        if start is not None:
            query = query.where(ts_col >= start)
        if end is not None:
            query = query.where(ts_col <= end)
        result = await self.db.execute(query)
        paise = int(result.scalar_one() or 0)
        return Decimal(paise) / Decimal("100")

    async def count_wallet_transactions(
        self,
        *,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> int:
        buy_ts = func.coalesce(PaymentOrder.paid_at, PaymentOrder.created_at)
        buy_q = select(func.count()).select_from(PaymentOrder).where(
            PaymentOrder.status == "paid"
        )
        if start is not None:
            buy_q = buy_q.where(buy_ts >= start)
        if end is not None:
            buy_q = buy_q.where(buy_ts <= end)

        sell_q = select(func.count()).select_from(GoldSellInquiry)
        if start is not None:
            sell_q = sell_q.where(GoldSellInquiry.created_at >= start)
        if end is not None:
            sell_q = sell_q.where(GoldSellInquiry.created_at <= end)

        referral_q = select(func.count()).select_from(ReferralReward)
        if start is not None:
            referral_q = referral_q.where(ReferralReward.created_at >= start)
        if end is not None:
            referral_q = referral_q.where(ReferralReward.created_at <= end)

        buy_count = int((await self.db.execute(buy_q)).scalar_one() or 0)
        sell_count = int((await self.db.execute(sell_q)).scalar_one() or 0)
        referral_count = int((await self.db.execute(referral_q)).scalar_one() or 0)
        return buy_count + sell_count + referral_count

    async def count_app_members(self) -> int:
        query = (
            select(func.count(func.distinct(User.id)))
            .select_from(User)
            .join(user_roles, User.id == user_roles.c.user_id)
            .join(Role, Role.id == user_roles.c.role_id)
            .where(
                User.is_deleted.is_(False),
                Role.name == "user",
            )
        )
        result = await self.db.execute(query)
        return int(result.scalar_one() or 0)

    async def count_new_members_this_month(self) -> int:
        month_start, day_end = self._month_bounds()
        query = (
            select(func.count(func.distinct(User.id)))
            .select_from(User)
            .join(user_roles, User.id == user_roles.c.user_id)
            .join(Role, Role.id == user_roles.c.role_id)
            .where(
                User.is_deleted.is_(False),
                Role.name == "user",
                User.created_at >= month_start,
                User.created_at <= day_end,
            )
        )
        result = await self.db.execute(query)
        return int(result.scalar_one() or 0)

    async def payment_revenue_trend(self, days: int = 30) -> list[dict]:
        from datetime import timedelta

        start = datetime.now(timezone.utc) - timedelta(days=days - 1)
        start = start.replace(hour=0, minute=0, second=0, microsecond=0)
        ts_col = func.coalesce(PaymentOrder.paid_at, PaymentOrder.created_at)
        day_col = cast(ts_col, Date).label("day")
        query = (
            select(
                day_col,
                func.coalesce(func.sum(PaymentOrder.amount_paise), 0).label("paise"),
                func.count(PaymentOrder.id).label("transaction_count"),
            )
            .where(PaymentOrder.status == "paid", ts_col >= start)
            .group_by(day_col)
            .order_by(day_col)
        )
        result = await self.db.execute(query)
        return [
            {
                "label": row.day.isoformat(),
                "revenue": Decimal(int(row.paise or 0)) / Decimal("100"),
                "transaction_count": int(row.transaction_count or 0),
            }
            for row in result.all()
        ]

    async def payment_revenue_growth_percent(self) -> Optional[Decimal]:
        from datetime import timedelta

        now = datetime.now(timezone.utc)
        month_start, day_end = self._month_bounds(now)
        if month_start.month == 1:
            prev_start = month_start.replace(year=month_start.year - 1, month=12, day=1)
        else:
            prev_start = month_start.replace(month=month_start.month - 1, day=1)
        prev_end = month_start - timedelta(microseconds=1)
        current = await self.paid_revenue_sum(start=month_start, end=day_end)
        previous = await self.paid_revenue_sum(start=prev_start, end=prev_end)
        if previous <= 0:
            return None if current <= 0 else Decimal("100")
        growth = ((current - previous) / previous) * Decimal("100")
        return growth.quantize(Decimal("0.1"))
