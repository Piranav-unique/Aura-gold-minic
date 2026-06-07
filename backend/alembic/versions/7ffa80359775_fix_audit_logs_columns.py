"""fix_audit_logs_columns

Revision ID: 7ffa80359775
Revises: a123bc456def
Create Date: 2026-06-07 17:58:24.128775

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
"""fix_audit_logs_columns

Revision ID: 7ffa80359775
Revises: a123bc456def
Create Date: 2026-06-07 17:58:24.128775

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '7ffa80359775'
down_revision: Union[str, None] = 'a123bc456def'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Drop existing partition and parent table
    op.execute("DROP TABLE IF EXISTS audit_logs_default")
    op.drop_table("audit_logs")

    # 2. Create partitioned audit_logs table
    op.create_table(
        "audit_logs",
        sa.Column(
            "id", sa.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False
        ),
        sa.Column("user_id", sa.UUID(), nullable=True),
        sa.Column("action", sa.String(length=100), nullable=False),
        sa.Column("entity_type", sa.String(length=100), nullable=True),
        sa.Column("entity_id", sa.String(length=100), nullable=True),
        sa.Column("metadata", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("ip_address", sa.String(length=45), nullable=True),
        sa.Column("user_agent", sa.String(length=255), nullable=True),
        sa.Column(
            "timestamp",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id", "timestamp"),
        postgresql_partition_by="RANGE (timestamp)",
    )

    # 3. Create default partition table
    op.execute("CREATE TABLE audit_logs_default PARTITION OF audit_logs DEFAULT")

    # 4. Create indices on partitioned audit_logs table
    op.create_index(
        op.f("ix_audit_logs_action"), "audit_logs", ["action"], unique=False
    )
    op.create_index(
        op.f("ix_audit_logs_entity_id"), "audit_logs", ["entity_id"], unique=False
    )
    op.create_index(
        op.f("ix_audit_logs_entity_type"), "audit_logs", ["entity_type"], unique=False
    )
    op.create_index(
        op.f("ix_audit_logs_user_id"), "audit_logs", ["user_id"], unique=False
    )
    op.create_index(
        "ix_audit_logs_metadata",
        "audit_logs",
        ["metadata"],
        unique=False,
        postgresql_using="gin",
    )


def downgrade() -> None:
    # 1. Drop existing partition and parent table
    op.execute("DROP TABLE IF EXISTS audit_logs_default")
    op.drop_table("audit_logs")

    # 2. Recreate original partitioned audit_logs table
    op.create_table(
        "audit_logs",
        sa.Column(
            "id", sa.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False
        ),
        sa.Column("user_id", sa.UUID(), nullable=True),
        sa.Column("action", sa.String(length=100), nullable=False),
        sa.Column("table_name", sa.String(length=100), nullable=True),
        sa.Column("record_id", sa.String(length=100), nullable=True),
        sa.Column("changes", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("ip_address", sa.String(length=45), nullable=True),
        sa.Column("user_agent", sa.String(length=255), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id", "created_at"),
        postgresql_partition_by="RANGE (created_at)",
    )

    # 3. Create default partition table
    op.execute("CREATE TABLE audit_logs_default PARTITION OF audit_logs DEFAULT")

    # 4. Recreate indices
    op.create_index(
        op.f("ix_audit_logs_action"), "audit_logs", ["action"], unique=False
    )
    op.create_index(
        op.f("ix_audit_logs_record_id"), "audit_logs", ["record_id"], unique=False
    )
    op.create_index(
        op.f("ix_audit_logs_table_name"), "audit_logs", ["table_name"], unique=False
    )
    op.create_index(
        op.f("ix_audit_logs_user_id"), "audit_logs", ["user_id"], unique=False
    )
    op.create_index(
        "ix_audit_logs_changes",
        "audit_logs",
        ["changes"],
        unique=False,
        postgresql_using="gin",
    )
    # ### end Alembic commands ###
