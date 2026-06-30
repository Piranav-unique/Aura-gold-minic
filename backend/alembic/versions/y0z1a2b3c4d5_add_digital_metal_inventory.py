"""add digital metal inventory for buy limits

Revision ID: y0z1a2b3c4d5
Revises: x9y0z1a2b3c4
Create Date: 2026-06-28
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "y0z1a2b3c4d5"
down_revision: Union[str, None] = "x9y0z1a2b3c4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "digital_metal_inventory",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("metal_type", sa.String(length=16), nullable=False),
        sa.Column("total_weight_grams", sa.Numeric(18, 4), nullable=False),
        sa.Column("used_weight_grams", sa.Numeric(18, 4), nullable=False, server_default="0"),
        sa.Column(
            "low_stock_threshold_grams",
            sa.Numeric(18, 4),
            nullable=False,
            server_default="1000",
        ),
        sa.Column("updated_by", sa.UUID(), nullable=True),
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
            "metal_type IN ('gold', 'silver')",
            name="ck_digital_metal_inventory_metal_type",
        ),
        sa.CheckConstraint(
            "total_weight_grams >= 0",
            name="ck_digital_metal_inventory_total_nonneg",
        ),
        sa.CheckConstraint(
            "used_weight_grams >= 0",
            name="ck_digital_metal_inventory_used_nonneg",
        ),
        sa.CheckConstraint(
            "used_weight_grams <= total_weight_grams",
            name="ck_digital_metal_inventory_used_lte_total",
        ),
        sa.ForeignKeyConstraint(["updated_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("metal_type", name="uq_digital_metal_inventory_metal_type"),
    )

    op.create_table(
        "digital_metal_inventory_movements",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("metal_type", sa.String(length=16), nullable=False),
        sa.Column("movement_type", sa.String(length=32), nullable=False),
        sa.Column("grams_delta", sa.Numeric(18, 4), nullable=False),
        sa.Column("total_weight_before", sa.Numeric(18, 4), nullable=False),
        sa.Column("used_weight_before", sa.Numeric(18, 4), nullable=False),
        sa.Column("total_weight_after", sa.Numeric(18, 4), nullable=False),
        sa.Column("used_weight_after", sa.Numeric(18, 4), nullable=False),
        sa.Column("payment_order_id", sa.UUID(), nullable=True),
        sa.Column("user_id", sa.UUID(), nullable=True),
        sa.Column("performed_by", sa.UUID(), nullable=True),
        sa.Column("notes", sa.String(length=500), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "movement_type IN ('admin_update', 'purchase_debit')",
            name="ck_digital_metal_inventory_movement_type",
        ),
        sa.ForeignKeyConstraint(["payment_order_id"], ["payment_orders.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["performed_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_digital_metal_inventory_movements_metal_type",
        "digital_metal_inventory_movements",
        ["metal_type"],
    )
    op.create_index(
        "ix_digital_metal_inventory_movements_created_at",
        "digital_metal_inventory_movements",
        ["created_at"],
    )

    op.execute(
        """
        INSERT INTO digital_metal_inventory (id, metal_type, total_weight_grams, used_weight_grams, low_stock_threshold_grams)
        VALUES
            (gen_random_uuid(), 'gold', 15000, 0, 1000),
            (gen_random_uuid(), 'silver', 5000, 0, 500)
        """
    )


def downgrade() -> None:
    op.drop_index(
        "ix_digital_metal_inventory_movements_created_at",
        table_name="digital_metal_inventory_movements",
    )
    op.drop_index(
        "ix_digital_metal_inventory_movements_metal_type",
        table_name="digital_metal_inventory_movements",
    )
    op.drop_table("digital_metal_inventory_movements")
    op.drop_table("digital_metal_inventory")
