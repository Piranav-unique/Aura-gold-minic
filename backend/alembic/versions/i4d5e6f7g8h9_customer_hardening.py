"""customer_hardening

Revision ID: i4d5e6f7g8h9
Revises: h3c4d5e6f7g8
Create Date: 2026-06-08 18:00:00.000000

"""

from typing import Sequence, Union

from alembic import op

revision: str = "i4d5e6f7g8h9"
down_revision: Union[str, None] = "h3c4d5e6f7g8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_check_constraint(
        "ck_customers_type",
        "customers",
        "customer_type IN ('individual', 'business')",
    )
    op.create_check_constraint(
        "ck_customers_status",
        "customers",
        "status IN ('active', 'inactive', 'blacklisted')",
    )
    op.create_index("ix_customers_created_at", "customers", ["created_at"])

    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_customers_full_name_trgm "
        "ON customers USING gin (full_name gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_customers_email_trgm "
        "ON customers USING gin (email gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_customers_mobile_trgm "
        "ON customers USING gin (mobile_number gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_customers_gst_trgm "
        "ON customers USING gin (gst_number gin_trgm_ops)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_customers_gst_trgm")
    op.execute("DROP INDEX IF EXISTS ix_customers_mobile_trgm")
    op.execute("DROP INDEX IF EXISTS ix_customers_email_trgm")
    op.execute("DROP INDEX IF EXISTS ix_customers_full_name_trgm")
    op.drop_index("ix_customers_created_at", table_name="customers")
    op.drop_constraint("ck_customers_status", "customers", type_="check")
    op.drop_constraint("ck_customers_type", "customers", type_="check")
