"""add otp_mobile to bank_link_challenges

Revision ID: e7f8a9b0c1d2
Revises: d6e7f8a9b0c1
Create Date: 2026-07-09
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e7f8a9b0c1d2"
down_revision: Union[str, None] = "d6e7f8a9b0c1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "bank_link_challenges",
        sa.Column("otp_mobile", sa.String(length=15), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("bank_link_challenges", "otp_mobile")
