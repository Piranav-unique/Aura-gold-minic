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
            "used_weight_grams <= total_weight_grams",
            name="ck_digital_metal_inventory_used_lte_total",
        ),
    )

    metal_type: Mapped[str] = mapped_column(String(16), nullable=False)
    total_weight_grams: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False, default=Decimal("0")
    )
    used_weight_grams: Mapped[Decimal] = mapped_column(
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
        return Decimal(str(self.total_weight_grams or 0)) - Decimal(
            str(self.used_weight_grams or 0)
        )


class DigitalMetalInventoryMovement(Base, UUIDPrimaryKeyMixin):
    """Ledger of admin stock updates and purchase debits."""

    __tablename__ = "digital_metal_inventory_movements"
    __table_args__ = (
        CheckConstraint(
            "movement_type IN ('admin_update', 'purchase_debit')",
            name="ck_digital_metal_inventory_movement_type",
        ),
    )

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
