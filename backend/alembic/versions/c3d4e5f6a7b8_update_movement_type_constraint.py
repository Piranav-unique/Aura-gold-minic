"""update movement_type check constraint to include restock and reserve_adjustment

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-10-07

The original migration only allowed ('admin_update', 'purchase_debit') but the
service code also uses 'restock' and 'reserve_adjustment' movement types.
"""

from typing import Sequence, Union

from alembic import op

revision: str = "c3d4e5f6a7b8"
down_revision: Union[str, None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop the old restrictive constraint
    op.drop_constraint(
        "ck_digital_metal_inventory_movement_type",
        "digital_metal_inventory_movements",
        type_="check",
    )

    # Re-create with all movement types the application uses
    op.create_check_constraint(
        "ck_digital_metal_inventory_movement_type",
        "digital_metal_inventory_movements",
        "movement_type IN ('admin_update', 'purchase_debit', 'restock', 'reserve_adjustment')",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_digital_metal_inventory_movement_type",
        "digital_metal_inventory_movements",
        type_="check",
    )
    op.create_check_constraint(
        "ck_digital_metal_inventory_movement_type",
        "digital_metal_inventory_movements",
        "movement_type IN ('admin_update', 'purchase_debit')",
    )
