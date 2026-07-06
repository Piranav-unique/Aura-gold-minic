from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Optional

from sqlalchemy import DateTime, ForeignKey, Index, Numeric, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.user import User


class GoldSellInquiry(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "gold_sell_inquiries"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    mobile_number: Mapped[str] = mapped_column(String(15), nullable=False)
    quantity_grams: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(18, 4), nullable=True
    )
    message: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), default="pending", nullable=False
    )
    admin_response: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    responded_by_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    responded_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    sell_rate_per_gram: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(18, 4), nullable=True
    )
    gross_amount_inr: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(18, 2), nullable=True
    )
    platform_charge_inr: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(18, 2), nullable=True
    )
    tax_amount_inr: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(18, 2), nullable=True
    )
    net_payable_inr: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(18, 2), nullable=True
    )
    payment_method: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    payment_destination: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    reference_number: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    rejection_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    approved_by_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    approved_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    razorpay_payout_id: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    razorpay_fund_account_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True
    )
    payout_status: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    payout_failure_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    bank_account_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user_bank_accounts.id", ondelete="SET NULL"),
        nullable=True,
    )

    user: Mapped["User"] = relationship(
        "User",
        foreign_keys=[user_id],
        lazy="joined",
    )
    responded_by: Mapped[Optional["User"]] = relationship(
        "User",
        foreign_keys=[responded_by_user_id],
        lazy="joined",
    )
    approved_by: Mapped[Optional["User"]] = relationship(
        "User",
        foreign_keys=[approved_by_user_id],
        lazy="joined",
    )

    __table_args__ = (
        Index("ix_gold_sell_inquiries_user_id", "user_id"),
        Index("ix_gold_sell_inquiries_status", "status"),
        Index("ix_gold_sell_inquiries_created_at", "created_at"),
    )
