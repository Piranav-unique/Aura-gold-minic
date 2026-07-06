"""add user registered device id

Revision ID: a3b4c5d6e7f8
Revises: a2b3c4d5e6f7
Create Date: 2026-07-06
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "a3b4c5d6e7f8"
down_revision: Union[str, None] = "a2b3c4d5e6f7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("registered_device_id", sa.String(length=36), nullable=True),
    )
    op.create_index(
        "ix_users_registered_device_active",
        "users",
        ["registered_device_id"],
        unique=True,
        postgresql_where=sa.text(
            "is_deleted = false AND registered_device_id IS NOT NULL"
        ),
    )


def downgrade() -> None:
    op.drop_index("ix_users_registered_device_active", table_name="users")
    op.drop_column("users", "registered_device_id")
