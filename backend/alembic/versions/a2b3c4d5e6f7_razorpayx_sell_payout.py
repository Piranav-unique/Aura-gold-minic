"""razorpayx sell payout fields

Revision ID: a2b3c4d5e6f7
Revises: z1a2b3c4d5e6
Create Date: 2026-06-28

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "a2b3c4d5e6f7"
down_revision: Union[str, None] = "z1a2b3c4d5e6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("razorpay_contact_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "user_bank_accounts",
        sa.Column("razorpay_fund_account_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("razorpay_payout_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("razorpay_fund_account_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("payout_status", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("payout_failure_reason", sa.Text(), nullable=True),
    )
    op.create_index(
        "ix_gold_sell_inquiries_razorpay_payout_id",
        "gold_sell_inquiries",
        ["razorpay_payout_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_gold_sell_inquiries_razorpay_payout_id", "gold_sell_inquiries")
    op.drop_column("gold_sell_inquiries", "payout_failure_reason")
    op.drop_column("gold_sell_inquiries", "payout_status")
    op.drop_column("gold_sell_inquiries", "razorpay_fund_account_id")
    op.drop_column("gold_sell_inquiries", "razorpay_payout_id")
    op.drop_column("user_bank_accounts", "razorpay_fund_account_id")
    op.drop_column("users", "razorpay_contact_id")
