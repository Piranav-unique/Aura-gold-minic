from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Numeric, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class DigitalMetalInventory(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Platform-wide digital metal stock that caps end-user purchases."""

    __tablename__ = "digital_metal_inventory"
    __table_args__ = (
        UniqueConstraint("metal_type", name="uq_digital_metal_inventory_metal_type"),
        CheckConstraint(
            "metal_type IN ('gold', 'silver')",
            name="ck_digital_metal_inventory_metal_type",
        ),
        CheckConstraint(
            "total_weight_grams >= 0",
            name="ck_digital_metal_inventory_total_nonneg",
        ),
        CheckConstraint(
            "used_weight_grams >= 0",
            name="ck_digital_metal_inventory_used_nonneg",
        ),
        CheckConstraint(
            "reserved_weight_grams >= 0",
            name="ck_digital_metal_inventory_reserved_nonneg",
        ),
    )

    metal_type: Mapped[str] = mapped_column(String(16), nullable=False)
    total_weight_grams: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False, default=Decimal("0")
    )
    used_weight_grams: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False, default=Decimal("0")
    )
    reserved_weight_grams: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False, default=Decimal("0")
    )
    low_stock_threshold_grams: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False, default=Decimal("1000")
    )
    updated_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    @property
    def available_weight_grams(self) -> Decimal:
        total = Decimal(str(self.total_weight_grams or 0))
        used = Decimal(str(self.used_weight_grams or 0))
        reserved = Decimal(str(self.reserved_weight_grams or 0))
        avail = total - reserved - used
        return max(Decimal("0"), avail)


class DigitalMetalInventoryMovement(Base, UUIDPrimaryKeyMixin):
    """Ledger of admin stock updates and purchase debits."""

    __tablename__ = "digital_metal_inventory_movements"

    metal_type: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    movement_type: Mapped[str] = mapped_column(String(32), nullable=False)
    grams_delta: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    total_weight_before: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    used_weight_before: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    total_weight_after: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    used_weight_after: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    payment_order_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("payment_orders.id", ondelete="SET NULL"), nullable=True
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    performed_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )


class DigitalMetalStockSubscription(Base, UUIDPrimaryKeyMixin):
    """User subscriptions to receive alerts when gold/silver becomes available again."""

    __tablename__ = "digital_metal_stock_subscriptions"
    __table_args__ = (
        UniqueConstraint("user_id", "metal_type", name="uq_user_metal_stock_sub"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    metal_type: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    is_active: Mapped[bool] = mapped_column(default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

