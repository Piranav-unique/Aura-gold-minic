from __future__ import annotations

import json
import re
import uuid
from dataclasses import dataclass
from datetime import date, datetime, time, timezone
from decimal import Decimal
from typing import Optional

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.gold_sell_inquiry import GoldSellInquiry
from app.models.payment_order import PaymentOrder
from app.models.referral_reward import ReferralReward
from app.models.user import User


@dataclass
class _WalletTxnRow:
    id: str
    user_id: uuid.UUID
    user_name: str
    user_mobile: Optional[str]
    occurred_at: datetime
    transaction_type: str
    metal: Optional[str]
    quantity_grams: Optional[Decimal]
    amount_inr: Optional[Decimal]
    status: str
    reference_id: Optional[str]
    source: str
    source_id: uuid.UUID


def _is_human_name(val: Optional[str]) -> bool:
    if not val:
        return False
    s = val.strip().lower()
    if not s or s in {"unknown", "n/a", "na", "null", "none", "admin", "superadmin", "customer"}:
        return False
    if "aurum" in s or "retail" in s or "store" in s or "test" in s:
        return False
    if "@" in s or ".com" in s or ".local" in s or ".aura" in s:
        return False
    if re.search(r"\d{4,}", s):
        return False
    return len(s) >= 2


def _user_display_name(user: User) -> str:
    # 1. Direct first_name / last_name
    parts = [p.strip() for p in (user.first_name, user.last_name) if p and p.strip()]
    if parts:
        joined = " ".join(parts).strip()
        if _is_human_name(joined):
            return joined
        elif joined:
            return joined

    # 2. Extract from verified KYC profile (Aadhaar / PAN verification)
    if getattr(user, "kyc_profile", None):
        try:
            kd = json.loads(user.kyc_profile)
            if isinstance(kd, dict) and (kd.get("full_name") or kd.get("name")):
                val = str(kd.get("full_name") or kd.get("name")).strip()
                if _is_human_name(val):
                    return val
        except Exception:
            pass

    # 3. Clean email prefix if a real human email
    if getattr(user, "email", None) and "@" in str(user.email):
        em = str(user.email).strip().lower()
        if not em.endswith(".aura") and not em.endswith(".local") and "mobile" not in em:
            prefix = em.split("@")[0].replace(".", " ").replace("_", " ").strip()
            if _is_human_name(prefix):
                cleaned = re.sub(r"\d+", "", prefix).strip()
                if len(cleaned) >= 2:
                    return cleaned.title()

    # 4. Clean mobile number display
    if getattr(user, "mobile_number", None):
        return f"Customer ({user.mobile_number})"

    # 5. Fallback
    return user.email if user.email else "Customer"


class AdminWalletRepository:
    """Data access for admin wallet search and unified transaction feeds."""

    def __init__(self, db_session: AsyncSession):
        self.db = db_session

    def _wallet_user_filters(self, search: Optional[str]):
        import os
        from app.models.role import Role
        from app.models.associations import user_roles

        admin_mobile = os.getenv("ADMIN_MOBILE_NUMBER", "9943795005").strip()

        admin_subq = (
            select(user_roles.c.user_id)
            .join(Role, user_roles.c.role_id == Role.id)
            .where(Role.name.in_(["super_admin", "admin", "superadmin"]))
        )

        clauses = [
            User.is_deleted.is_(False),
            User.is_superuser.is_(False),
            User.email.not_ilike("%superadmin%"),
            User.email.not_ilike("%admin@agsgold%"),
            User.first_name.not_ilike("%yogesh%"),
            or_(User.mobile_number.is_(None), ~User.mobile_number.like("%8248345770%")),
            ~User.id.in_(admin_subq),
        ]
        if admin_mobile:
            clauses.append(or_(User.mobile_number.is_(None), User.mobile_number != admin_mobile))

        if not search:
            return clauses
        term = search.strip()
        if not term:
            return clauses
        pattern = f"%{term}%"
        filters = [
            User.email.ilike(pattern),
            User.first_name.ilike(pattern),
            User.last_name.ilike(pattern),
            User.mobile_number.ilike(pattern),
            User.kyc_aadhaar_last4.ilike(pattern),
            User.kyc_pan_last4.ilike(pattern),
            User.kyc_profile.ilike(pattern),
        ]
        if len(term) >= 2:
            filters.append(
                func.concat(User.first_name, " ", User.last_name).ilike(pattern)
            )
        clauses.append(or_(*filters))
        return clauses

    async def search_wallet_users(
        self,
        *,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 20,
    ) -> tuple[list[User], int]:
        limit = min(max(limit, 1), 100)
        filters = self._wallet_user_filters(search)

        count_q = select(func.count(User.id)).where(*filters)
        total = int((await self.db.execute(count_q)).scalar_one() or 0)

        query = (
            select(User)
            .where(*filters)
            .order_by(User.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(query)
        return list(result.scalars().all()), total

    async def get_wallet_user(self, user_id: uuid.UUID) -> Optional[User]:
        result = await self.db.execute(
            select(User).where(User.id == user_id, User.is_deleted.is_(False))
        )
        return result.scalars().first()

    _IGNORED_ORDERS = (
        "order_dev_3e67692f9a9a4b1fa6e39aa3",
        "order_Tkkr0WuXPYD8G5",
        "order_Tkkk5aZIuCofGZ",
        "order_TkkiZDW6SnMXRA",
        "order_Tkkc5pV5WdC87Y",
        "order_TkKPpYcdWGd8CD",
        "order_TkKSA3pKTBiHKk",
    )

    async def sum_paid_grams(self, user_id: uuid.UUID, metal: Optional[str] = None) -> Decimal:
        query = (
            select(func.coalesce(func.sum(PaymentOrder.grams), 0))
            .where(
                PaymentOrder.user_id == user_id,
                PaymentOrder.status == "paid",
                or_(PaymentOrder.razorpay_payment_id.is_(None), PaymentOrder.razorpay_payment_id != "pay_dev_mock"),
                or_(PaymentOrder.razorpay_order_id.is_(None), ~PaymentOrder.razorpay_order_id.like("order_dev_%")),
                ~PaymentOrder.razorpay_order_id.in_(self._IGNORED_ORDERS),
            )
        )
        if metal:
            query = query.where(PaymentOrder.metal == metal)
        result = await self.db.execute(query)
        return Decimal(str(result.scalar_one() or 0))

    async def batch_sum_paid_grams(
        self, user_ids: list[uuid.UUID], metal: Optional[str] = None
    ) -> dict[uuid.UUID, Decimal]:
        if not user_ids:
            return {}
        query = (
            select(PaymentOrder.user_id, func.coalesce(func.sum(PaymentOrder.grams), 0))
            .where(
                PaymentOrder.user_id.in_(user_ids),
                PaymentOrder.status == "paid",
                or_(PaymentOrder.razorpay_payment_id.is_(None), PaymentOrder.razorpay_payment_id != "pay_dev_mock"),
                or_(PaymentOrder.razorpay_order_id.is_(None), ~PaymentOrder.razorpay_order_id.like("order_dev_%")),
                ~PaymentOrder.razorpay_order_id.in_(self._IGNORED_ORDERS),
            )
        )
        if metal:
            query = query.where(PaymentOrder.metal == metal)
        query = query.group_by(PaymentOrder.user_id)
        result = await self.db.execute(query)
        return {row[0]: Decimal(str(row[1] or 0)) for row in result.all()}


    async def count_pending_sell_inquiries(self, user_id: uuid.UUID) -> int:
        result = await self.db.execute(
            select(func.count())
            .select_from(GoldSellInquiry)
            .where(
                GoldSellInquiry.user_id == user_id,
                GoldSellInquiry.status == "pending",
            )
        )
        return int(result.scalar_one() or 0)

    async def sum_referral_rewards(self, user_id: uuid.UUID) -> tuple[Decimal, Decimal]:
        result = await self.db.execute(
            select(
                func.coalesce(func.sum(ReferralReward.reward_inr), 0),
                func.coalesce(func.sum(ReferralReward.scheme_grams), 0),
            ).where(ReferralReward.referrer_id == user_id)
        )
        row = result.one()
        return Decimal(str(row[0] or 0)), Decimal(str(row[1] or 0))

    async def _build_buy_rows(
        self,
        user_id: Optional[uuid.UUID] = None,
        metal: Optional[str] = None,
        status: Optional[str] = None,
    ) -> list[_WalletTxnRow]:
        query = select(PaymentOrder).options(selectinload(PaymentOrder.user))
        query = query.where(
            or_(PaymentOrder.razorpay_payment_id.is_(None), PaymentOrder.razorpay_payment_id != "pay_dev_mock"),
            or_(PaymentOrder.razorpay_order_id.is_(None), ~PaymentOrder.razorpay_order_id.like("order_dev_%")),
            ~PaymentOrder.razorpay_order_id.in_(self._IGNORED_ORDERS),
        )
        if user_id:
            query = query.where(PaymentOrder.user_id == user_id)
        if metal:
            query = query.where(PaymentOrder.metal == metal.lower())
        if status:
            query = query.where(PaymentOrder.status == status.lower())
        result = await self.db.execute(query)
        orders = list(result.scalars().all())
        rows: list[_WalletTxnRow] = []
        for order in orders:
            user = order.user
            occurred = order.paid_at or order.created_at
            rows.append(
                _WalletTxnRow(
                    id=f"buy:{order.id}",
                    user_id=order.user_id,
                    user_name=_user_display_name(user) if user else "",
                    user_mobile=user.mobile_number if user else None,
                    occurred_at=occurred,
                    transaction_type="BUY",
                    metal=order.metal.upper(),
                    quantity_grams=order.grams,
                    amount_inr=Decimal(order.amount_paise) / Decimal("100"),
                    status=order.status,
                    reference_id=order.razorpay_order_id,
                    source="payment_order",
                    source_id=order.id,
                )
            )
        return rows

    async def _build_sell_rows(
        self,
        user_id: Optional[uuid.UUID] = None,
        status: Optional[str] = None,
    ) -> list[_WalletTxnRow]:
        query = select(GoldSellInquiry).options(selectinload(GoldSellInquiry.user))
        if user_id:
            query = query.where(GoldSellInquiry.user_id == user_id)
        if status:
            query = query.where(GoldSellInquiry.status == status.lower())
        result = await self.db.execute(query)
        inquiries = list(result.scalars().all())
        rows: list[_WalletTxnRow] = []
        for inquiry in inquiries:
            user = inquiry.user
            rows.append(
                _WalletTxnRow(
                    id=f"sell:{inquiry.id}",
                    user_id=inquiry.user_id,
                    user_name=_user_display_name(user) if user else inquiry.name,
                    user_mobile=inquiry.mobile_number,
                    occurred_at=inquiry.created_at,
                    transaction_type="SELL",
                    metal="GOLD",
                    quantity_grams=inquiry.quantity_grams,
                    amount_inr=inquiry.net_payable_inr or inquiry.gross_amount_inr,
                    status=inquiry.status,
                    reference_id=str(inquiry.id),
                    source="gold_sell_inquiry",
                    source_id=inquiry.id,
                )
            )
        return rows

    async def _build_referral_rows(
        self,
        user_id: Optional[uuid.UUID] = None,
    ) -> list[_WalletTxnRow]:
        query = select(ReferralReward)
        if user_id:
            query = query.where(ReferralReward.referrer_id == user_id)
        result = await self.db.execute(query)
        rewards = list(result.scalars().all())
        rows: list[_WalletTxnRow] = []
        for reward in rewards:
            user_result = await self.db.execute(
                select(User).where(User.id == reward.referrer_id)
            )
            user = user_result.scalars().first()
            rows.append(
                _WalletTxnRow(
                    id=f"referral:{reward.id}",
                    user_id=reward.referrer_id,
                    user_name=_user_display_name(user) if user else "",
                    user_mobile=user.mobile_number if user else None,
                    occurred_at=reward.created_at,
                    transaction_type="REFERRAL",
                    metal="GOLD",
                    quantity_grams=reward.scheme_grams,
                    amount_inr=reward.reward_inr,
                    status="completed",
                    reference_id=str(reward.id),
                    source="referral_reward",
                    source_id=reward.id,
                )
            )
        return rows

    async def _build_savings_rows(
        self,
        user_id: Optional[uuid.UUID] = None,
    ) -> list[_WalletTxnRow]:
        query = select(User).where(
            User.is_deleted.is_(False),
            User.gold_scheme_status.in_(["active", "completed"]),
            User.gold_scheme_started_at.isnot(None),
            User.gold_scheme_target_grams.isnot(None),
        )
        if user_id:
            query = query.where(User.id == user_id)
        result = await self.db.execute(query)
        users = list(result.scalars().all())
        rows: list[_WalletTxnRow] = []
        for user in users:
            rows.append(
                _WalletTxnRow(
                    id=f"savings:{user.id}",
                    user_id=user.id,
                    user_name=_user_display_name(user),
                    user_mobile=user.mobile_number,
                    occurred_at=user.gold_scheme_started_at,
                    transaction_type="SAVINGS",
                    metal="GOLD",
                    quantity_grams=user.gold_scheme_target_grams,
                    amount_inr=None,
                    status=user.gold_scheme_status,
                    reference_id=f"scheme-{user.gold_scheme_target_grams}g",
                    source="gold_scheme",
                    source_id=user.id,
                )
            )
        return rows

    async def list_transactions(
        self,
        *,
        user_id: Optional[uuid.UUID] = None,
        skip: int = 0,
        limit: int = 20,
        transaction_type: Optional[str] = None,
        metal: Optional[str] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
        from_date: Optional[date] = None,
        to_date: Optional[date] = None,
    ) -> tuple[list[_WalletTxnRow], int]:
        limit = min(max(limit, 1), 100)
        type_upper = transaction_type.upper() if transaction_type else None
        metal_lower = metal.lower() if metal else None
        status_lower = status.lower() if status else None

        filter_user_ids: Optional[set[uuid.UUID]] = None
        if search and search.strip() and user_id is None:
            users, _ = await self.search_wallet_users(
                search=search.strip(), skip=0, limit=500
            )
            filter_user_ids = {u.id for u in users}

        rows: list[_WalletTxnRow] = []
        if type_upper is None or type_upper == "BUY":
            rows.extend(
                await self._build_buy_rows(user_id, metal_lower, status_lower)
            )
        if type_upper is None or type_upper == "SELL":
            rows.extend(await self._build_sell_rows(user_id, status_lower))
        if type_upper is None or type_upper == "REFERRAL":
            if not metal_lower or metal_lower == "gold":
                if not status_lower or status_lower == "completed":
                    rows.extend(await self._build_referral_rows(user_id))
        if type_upper is None or type_upper == "SAVINGS":
            if not metal_lower or metal_lower == "gold":
                rows.extend(await self._build_savings_rows(user_id))

        if filter_user_ids is not None:
            rows = [r for r in rows if r.user_id in filter_user_ids]

        if from_date is not None:
            start = datetime.combine(from_date, time.min, tzinfo=timezone.utc)
            rows = [r for r in rows if r.occurred_at >= start]
        if to_date is not None:
            end = datetime.combine(to_date, time.max, tzinfo=timezone.utc)
            rows = [r for r in rows if r.occurred_at <= end]

        rows.sort(key=lambda r: r.occurred_at, reverse=True)
        total = len(rows)
        return rows[skip : skip + limit], total

    async def get_payment_order(self, order_id: uuid.UUID) -> Optional[PaymentOrder]:
        result = await self.db.execute(
            select(PaymentOrder).where(PaymentOrder.id == order_id)
        )
        return result.scalars().first()

    async def get_sell_inquiry(self, inquiry_id: uuid.UUID) -> Optional[GoldSellInquiry]:
        result = await self.db.execute(
            select(GoldSellInquiry).where(GoldSellInquiry.id == inquiry_id)
        )
        return result.scalars().first()

    async def get_referral_reward(self, reward_id: uuid.UUID) -> Optional[ReferralReward]:
        result = await self.db.execute(
            select(ReferralReward).where(ReferralReward.id == reward_id)
        )
        return result.scalars().first()
