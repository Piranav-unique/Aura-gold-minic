"""payment order purchase mode and precision

Revision ID: c4d5e6f7g8h9
Revises: f8a9b0c1d2e3
Create Date: 2026-09-28
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c4d5e6f7g8h9"
down_revision: Union[str, None] = "f8a9b0c1d2e3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add purchase_mode to payment_orders
    op.add_column(
        "payment_orders",
        sa.Column(
            "purchase_mode",
            sa.String(length=16),
            server_default="amount",
            nullable=False,
        ),
    )

    # 2. Increase gram precision from 4 to 6 decimal places (1 microgram precision)
    op.alter_column(
        "payment_orders",
        "grams",
        existing_type=sa.Numeric(18, 4),
        type_=sa.Numeric(18, 6),
        existing_nullable=False,
    )
    op.alter_column(
        "users",
        "gold_savings_grams",
        existing_type=sa.Numeric(18, 4),
        type_=sa.Numeric(18, 6),
        existing_nullable=False,
    )
    op.alter_column(
        "users",
        "silver_savings_grams",
        existing_type=sa.Numeric(18, 4),
        type_=sa.Numeric(18, 6),
        existing_nullable=False,
    )

    # 3. Inventory precision
    try:
        op.alter_column(
            "digital_metal_inventory",
            "total_weight_grams",
            existing_type=sa.Numeric(18, 4),
            type_=sa.Numeric(18, 6),
            existing_nullable=False,
        )
        op.alter_column(
            "digital_metal_inventory",
            "used_weight_grams",
            existing_type=sa.Numeric(18, 4),
            type_=sa.Numeric(18, 6),
            existing_nullable=False,
        )
    except Exception:
        pass


def downgrade() -> None:
    try:
        op.alter_column(
            "digital_metal_inventory",
            "used_weight_grams",
            existing_type=sa.Numeric(18, 6),
            type_=sa.Numeric(18, 4),
            existing_nullable=False,
        )
        op.alter_column(
            "digital_metal_inventory",
            "total_weight_grams",
            existing_type=sa.Numeric(18, 6),
            type_=sa.Numeric(18, 4),
            existing_nullable=False,
        )
    except Exception:
        pass

    op.alter_column(
        "users",
        "silver_savings_grams",
        existing_type=sa.Numeric(18, 6),
        type_=sa.Numeric(18, 4),
        existing_nullable=False,
    )
    op.alter_column(
        "users",
        "gold_savings_grams",
        existing_type=sa.Numeric(18, 6),
        type_=sa.Numeric(18, 4),
        existing_nullable=False,
    )
    op.alter_column(
        "payment_orders",
        "grams",
        existing_type=sa.Numeric(18, 6),
        type_=sa.Numeric(18, 4),
        existing_nullable=False,
    )
    op.drop_column("payment_orders", "purchase_mode")
