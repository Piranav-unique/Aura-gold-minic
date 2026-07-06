"""relax device binding unique index

Revision ID: d6e7f8a9b0c1
Revises: c5d6e7f8a9b0
Create Date: 2026-07-07
"""

from typing import Sequence, Union

from alembic import op

revision: str = "d6e7f8a9b0c1"
down_revision: Union[str, None] = "c5d6e7f8a9b0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_index("ix_users_registered_device_active", table_name="users")


def downgrade() -> None:
    import sqlalchemy as sa

    op.create_index(
        "ix_users_registered_device_active",
        "users",
        ["registered_device_id"],
        unique=True,
        postgresql_where=sa.text(
            "is_deleted = false AND registered_device_id IS NOT NULL"
        ),
    )
