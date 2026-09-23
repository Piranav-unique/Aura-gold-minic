"""add payment rrn contact and sync fields

Revision ID: b3c4d5e6f7g8
Revises: z1a2b3c4d5e6
Create Date: 2026-09-23
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "b3c4d5e6f7g8"
down_revision: Union[str, None] = "z1a2b3c4d5e6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "payment_orders",
        sa.Column("payment_method", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "payment_orders",
        sa.Column("bank_rrn", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "payment_orders",
        sa.Column("customer_contact", sa.String(length=20), nullable=True),
    )
    op.add_column(
        "payment_orders",
        sa.Column("failure_reason", sa.String(length=255), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("payment_orders", "failure_reason")
    op.drop_column("payment_orders", "customer_contact")
    op.drop_column("payment_orders", "bank_rrn")
    op.drop_column("payment_orders", "payment_method")
