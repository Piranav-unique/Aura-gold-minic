from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, UUIDPrimaryKeyMixin


class StockMovement(Base, UUIDPrimaryKeyMixin):
    """Immutable ledger of stock in, out, and adjustment events."""

    __tablename__ = "stock_movements"

    inventory_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("inventory_items.id"), nullable=False
    )
    movement_type: Mapped[str] = mapped_column(String(20), nullable=False)
    quantity_change: Mapped[int] = mapped_column(Integer, nullable=False)
    quantity_before: Mapped[int] = mapped_column(Integer, nullable=False)
    quantity_after: Mapped[int] = mapped_column(Integer, nullable=False)
    reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    supplier_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("suppliers.id"), nullable=True
    )
    performed_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    inventory_item: Mapped["InventoryItem"] = relationship(
        "InventoryItem", back_populates="movements"
    )

    __table_args__ = (
        Index("ix_stock_movements_item_id", "inventory_item_id"),
        Index("ix_stock_movements_movement_type", "movement_type"),
        Index("ix_stock_movements_created_at", "created_at"),
        CheckConstraint(
            "movement_type IN ('stock_in', 'stock_out', 'adjustment')",
            name="ck_stock_movements_type",
        ),
    )
