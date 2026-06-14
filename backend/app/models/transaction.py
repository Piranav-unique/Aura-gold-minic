from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class Transaction(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Gold business transaction with payment and document tracking."""

    __tablename__ = "transactions"

    transaction_number: Mapped[str] = mapped_column(
        String(40), nullable=False, unique=True
    )
    transaction_type: Mapped[str] = mapped_column(String(20), nullable=False)
    customer_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customers.id"), nullable=True
    )
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="active")
    payment_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending"
    )
    subtotal: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False, default=0)
    tax_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    total_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    invoice_number: Mapped[str | None] = mapped_column(
        String(40), nullable=True, unique=True
    )
    receipt_number: Mapped[str | None] = mapped_column(
        String(40), nullable=True, unique=True
    )
    stock_applied: Mapped[bool] = mapped_column(default=False, nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    performed_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancellation_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)

    customer: Mapped["Customer | None"] = relationship("Customer")
    lines: Mapped[list["TransactionLine"]] = relationship(
        "TransactionLine", back_populates="transaction", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("ix_transactions_transaction_type", "transaction_type"),
        Index("ix_transactions_payment_status", "payment_status"),
        Index("ix_transactions_status", "status"),
        Index("ix_transactions_customer_id", "customer_id"),
        Index("ix_transactions_created_at", "created_at"),
        CheckConstraint(
            "transaction_type IN ('purchase', 'sale', 'return', 'exchange')",
            name="ck_transactions_type",
        ),
        CheckConstraint(
            "payment_status IN ('pending', 'paid', 'failed', 'refunded')",
            name="ck_transactions_payment_status",
        ),
        CheckConstraint(
            "status IN ('active', 'cancelled')",
            name="ck_transactions_status",
        ),
    )


class TransactionLine(Base, UUIDPrimaryKeyMixin):
    """Line item on a transaction with stock direction."""

    __tablename__ = "transaction_lines"

    transaction_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("transactions.id", ondelete="CASCADE"),
        nullable=False,
    )
    inventory_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("inventory_items.id"), nullable=False
    )
    item_name: Mapped[str] = mapped_column(String(200), nullable=False)
    quantity: Mapped[int] = mapped_column(nullable=False)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    line_total: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    stock_direction: Mapped[str] = mapped_column(String(10), nullable=False)

    transaction: Mapped["Transaction"] = relationship(
        "Transaction", back_populates="lines"
    )
    inventory_item: Mapped["InventoryItem"] = relationship("InventoryItem")

    __table_args__ = (
        Index("ix_transaction_lines_transaction_id", "transaction_id"),
        Index("ix_transaction_lines_inventory_item_id", "inventory_item_id"),
        CheckConstraint("quantity > 0", name="ck_transaction_lines_quantity_pos"),
        CheckConstraint(
            "stock_direction IN ('in', 'out')",
            name="ck_transaction_lines_stock_direction",
        ),
    )
