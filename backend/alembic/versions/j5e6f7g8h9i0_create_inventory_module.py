"""create_inventory_module

Revision ID: j5e6f7g8h9i0
Revises: i4d5e6f7g8h9
Create Date: 2026-06-08 18:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "j5e6f7g8h9i0"
down_revision: Union[str, None] = "i4d5e6f7g8h9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "suppliers",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("contact_person", sa.String(length=100), nullable=True),
        sa.Column("mobile_number", sa.String(length=20), nullable=True),
        sa.Column("email", sa.String(length=255), nullable=True),
        sa.Column("address", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "is_deleted",
            sa.Boolean(),
            server_default="false",
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_suppliers_name_active",
        "suppliers",
        ["name"],
        unique=True,
        postgresql_where=sa.text("is_deleted = false"),
    )

    op.create_table(
        "inventory_items",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("item_name", sa.String(length=200), nullable=False),
        sa.Column("item_category", sa.String(length=30), nullable=False),
        sa.Column("weight", sa.Numeric(precision=12, scale=4), nullable=False),
        sa.Column("purity", sa.Numeric(precision=6, scale=3), nullable=False),
        sa.Column("purchase_price", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("current_value", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("stock_quantity", sa.Integer(), server_default="0", nullable=False),
        sa.Column("reorder_level", sa.Integer(), server_default="5", nullable=False),
        sa.Column("supplier_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "status",
            sa.String(length=20),
            server_default="active",
            nullable=False,
        ),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "is_deleted",
            sa.Boolean(),
            server_default="false",
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["supplier_id"], ["suppliers.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint(
            "item_category IN ('gold_bar', 'gold_coin', 'gold_ornament', 'raw_gold')",
            name="ck_inventory_items_category",
        ),
        sa.CheckConstraint(
            "status IN ('active', 'inactive', 'discontinued')",
            name="ck_inventory_items_status",
        ),
        sa.CheckConstraint(
            "stock_quantity >= 0", name="ck_inventory_items_stock_nonneg"
        ),
        sa.CheckConstraint(
            "reorder_level >= 0", name="ck_inventory_items_reorder_nonneg"
        ),
    )
    op.create_index("ix_inventory_items_item_name", "inventory_items", ["item_name"])
    op.create_index(
        "ix_inventory_items_item_category", "inventory_items", ["item_category"]
    )
    op.create_index("ix_inventory_items_status", "inventory_items", ["status"])
    op.create_index(
        "ix_inventory_items_supplier_id", "inventory_items", ["supplier_id"]
    )
    op.create_index(
        "ix_inventory_items_stock_quantity", "inventory_items", ["stock_quantity"]
    )

    op.create_table(
        "stock_movements",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("inventory_item_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("movement_type", sa.String(length=20), nullable=False),
        sa.Column("quantity_change", sa.Integer(), nullable=False),
        sa.Column("quantity_before", sa.Integer(), nullable=False),
        sa.Column("quantity_after", sa.Integer(), nullable=False),
        sa.Column("reference", sa.String(length=100), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("supplier_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("performed_by", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["inventory_item_id"], ["inventory_items.id"]),
        sa.ForeignKeyConstraint(["supplier_id"], ["suppliers.id"]),
        sa.ForeignKeyConstraint(["performed_by"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint(
            "movement_type IN ('stock_in', 'stock_out', 'adjustment')",
            name="ck_stock_movements_type",
        ),
    )
    op.create_index(
        "ix_stock_movements_item_id", "stock_movements", ["inventory_item_id"]
    )
    op.create_index(
        "ix_stock_movements_movement_type", "stock_movements", ["movement_type"]
    )
    op.create_index("ix_stock_movements_created_at", "stock_movements", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_stock_movements_created_at", table_name="stock_movements")
    op.drop_index("ix_stock_movements_movement_type", table_name="stock_movements")
    op.drop_index("ix_stock_movements_item_id", table_name="stock_movements")
    op.drop_table("stock_movements")
    op.drop_index("ix_inventory_items_stock_quantity", table_name="inventory_items")
    op.drop_index("ix_inventory_items_supplier_id", table_name="inventory_items")
    op.drop_index("ix_inventory_items_status", table_name="inventory_items")
    op.drop_index("ix_inventory_items_item_category", table_name="inventory_items")
    op.drop_index("ix_inventory_items_item_name", table_name="inventory_items")
    op.drop_table("inventory_items")
    op.drop_index("ix_suppliers_name_active", table_name="suppliers")
    op.drop_table("suppliers")
