"""add bank_account_id to gold_sell_inquiries

Revision ID: c5d6e7f8a9b0
Revises: b4c5d6e7f8a9
Create Date: 2026-07-06
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c5d6e7f8a9b0"
down_revision: Union[str, None] = "b4c5d6e7f8a9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("bank_account_id", sa.UUID(), nullable=True),
    )
    op.create_foreign_key(
        "fk_gold_sell_inquiries_bank_account_id",
        "gold_sell_inquiries",
        "user_bank_accounts",
        ["bank_account_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_gold_sell_inquiries_bank_account_id",
        "gold_sell_inquiries",
        ["bank_account_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_gold_sell_inquiries_bank_account_id",
        table_name="gold_sell_inquiries",
    )
    op.drop_constraint(
        "fk_gold_sell_inquiries_bank_account_id",
        "gold_sell_inquiries",
        type_="foreignkey",
    )
    op.drop_column("gold_sell_inquiries", "bank_account_id")
