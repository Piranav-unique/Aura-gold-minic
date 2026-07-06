"""add has_completed_mobile_login to users

Revision ID: b4c5d6e7f8a9
Revises: a3b4c5d6e7f8
Create Date: 2026-07-06
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "b4c5d6e7f8a9"
down_revision: Union[str, None] = "a3b4c5d6e7f8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "has_completed_mobile_login",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    # Existing verified accounts already use OTP login; skip one-time trusted sign-in.
    op.execute(
        "UPDATE users SET has_completed_mobile_login = true "
        "WHERE mobile_verified = true"
    )
    op.alter_column("users", "has_completed_mobile_login", server_default=None)


def downgrade() -> None:
    op.drop_column("users", "has_completed_mobile_login")
