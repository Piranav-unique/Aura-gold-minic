from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.user import User


class PaymentOrder(Base):
    __tablename__ = "payment_orders"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    razorpay_order_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    razorpay_payment_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    metal: Mapped[str] = mapped_column(String(16), nullable=False)
    purchase_mode: Mapped[str] = mapped_column(
        String(16), default="amount", server_default="amount", nullable=False
    )
    amount_paise: Mapped[int] = mapped_column(Integer, nullable=False)
    grams: Mapped[Decimal] = mapped_column(Numeric(18, 6), nullable=False)
    rate_per_gram: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    gst_percent: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    metal_value_inr: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    gst_amount_inr: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    razorpay_fee_inr: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    merchant_settlement_inr: Mapped[Decimal | None] = mapped_column(
        Numeric(18, 2), nullable=True
    )
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="created")
    payment_method: Mapped[str | None] = mapped_column(String(32), nullable=True)
    bank_rrn: Mapped[str | None] = mapped_column(String(64), nullable=True)
    customer_contact: Mapped[str | None] = mapped_column(String(20), nullable=True)
    failure_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped["User"] = relationship("User", lazy="joined")
