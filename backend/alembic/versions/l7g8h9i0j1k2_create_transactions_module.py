"""create_transactions_module

Revision ID: l7g8h9i0j1k2
Revises: k6f7g8h9i0j1
Create Date: 2026-06-08 20:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "l7g8h9i0j1k2"
down_revision: Union[str, None] = "k6f7g8h9i0j1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "transactions",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("transaction_number", sa.String(length=40), nullable=False),
        sa.Column("transaction_type", sa.String(length=20), nullable=False),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "status", sa.String(length=20), server_default="active", nullable=False
        ),
        sa.Column(
            "payment_status",
            sa.String(length=20),
            server_default="pending",
            nullable=False,
        ),
        sa.Column(
            "subtotal",
            sa.Numeric(precision=14, scale=2),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "tax_amount",
            sa.Numeric(precision=14, scale=2),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "total_amount",
            sa.Numeric(precision=14, scale=2),
            server_default="0",
            nullable=False,
        ),
        sa.Column("invoice_number", sa.String(length=40), nullable=True),
        sa.Column("receipt_number", sa.String(length=40), nullable=True),
        sa.Column(
            "stock_applied", sa.Boolean(), server_default="false", nullable=False
        ),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("performed_by", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancellation_reason", sa.String(length=255), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "transaction_type IN ('purchase', 'sale', 'return', 'exchange')",
            name="ck_transactions_type",
        ),
        sa.CheckConstraint(
            "payment_status IN ('pending', 'paid', 'failed', 'refunded')",
            name="ck_transactions_payment_status",
        ),
        sa.CheckConstraint(
            "status IN ('active', 'cancelled')",
            name="ck_transactions_status",
        ),
        sa.ForeignKeyConstraint(["customer_id"], ["customers.id"]),
        sa.ForeignKeyConstraint(["performed_by"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("invoice_number"),
        sa.UniqueConstraint("receipt_number"),
        sa.UniqueConstraint("transaction_number"),
    )
    op.create_index(
        "ix_transactions_transaction_type",
        "transactions",
        ["transaction_type"],
    )
    op.create_index(
        "ix_transactions_payment_status",
        "transactions",
        ["payment_status"],
    )
    op.create_index("ix_transactions_status", "transactions", ["status"])
    op.create_index("ix_transactions_customer_id", "transactions", ["customer_id"])
    op.create_index("ix_transactions_created_at", "transactions", ["created_at"])

    op.create_table(
        "transaction_lines",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("transaction_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("inventory_item_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("item_name", sa.String(length=200), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("unit_price", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("line_total", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("stock_direction", sa.String(length=10), nullable=False),
        sa.CheckConstraint("quantity > 0", name="ck_transaction_lines_quantity_pos"),
        sa.CheckConstraint(
            "stock_direction IN ('in', 'out')",
            name="ck_transaction_lines_stock_direction",
        ),
        sa.ForeignKeyConstraint(
            ["inventory_item_id"],
            ["inventory_items.id"],
        ),
        sa.ForeignKeyConstraint(
            ["transaction_id"],
            ["transactions.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_transaction_lines_transaction_id",
        "transaction_lines",
        ["transaction_id"],
    )
    op.create_index(
        "ix_transaction_lines_inventory_item_id",
        "transaction_lines",
        ["inventory_item_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_transaction_lines_inventory_item_id", table_name="transaction_lines"
    )
    op.drop_index("ix_transaction_lines_transaction_id", table_name="transaction_lines")
    op.drop_table("transaction_lines")
    op.drop_index("ix_transactions_created_at", table_name="transactions")
    op.drop_index("ix_transactions_customer_id", table_name="transactions")
    op.drop_index("ix_transactions_status", table_name="transactions")
    op.drop_index("ix_transactions_payment_status", table_name="transactions")
    op.drop_index("ix_transactions_transaction_type", table_name="transactions")
    op.drop_table("transactions")
