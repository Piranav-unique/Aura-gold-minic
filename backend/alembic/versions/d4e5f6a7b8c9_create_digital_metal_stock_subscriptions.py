"""create digital_metal_stock_subscriptions table

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Create Date: 2026-10-07
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "d4e5f6a7b8c9"
down_revision: Union[str, None] = "c3d4e5f6a7b8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "digital_metal_stock_subscriptions",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("metal_type", sa.String(length=16), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "metal_type", name="uq_user_metal_stock_sub"),
    )
    op.create_index(
        "ix_digital_metal_stock_subscriptions_user_id",
        "digital_metal_stock_subscriptions",
        ["user_id"],
    )
    op.create_index(
        "ix_digital_metal_stock_subscriptions_metal_type",
        "digital_metal_stock_subscriptions",
        ["metal_type"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_digital_metal_stock_subscriptions_metal_type",
        table_name="digital_metal_stock_subscriptions",
    )
    op.drop_index(
        "ix_digital_metal_stock_subscriptions_user_id",
        table_name="digital_metal_stock_subscriptions",
    )
    op.drop_table("digital_metal_stock_subscriptions")
