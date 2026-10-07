"""add reserved_weight_grams to digital_metal_inventory

Revision ID: a1b2c3d4e5f6
Revises: z1a2b3c4d5e6
Create Date: 2026-10-07

The original migration (y0z1a2b3c4d5) created digital_metal_inventory without
the reserved_weight_grams column. The model was updated later to include it, but
no corresponding migration was added, causing a ProgrammingError on VPS.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "z1a2b3c4d5e6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add the missing column with a server_default of 0 so existing rows are valid
    op.add_column(
        "digital_metal_inventory",
        sa.Column(
            "reserved_weight_grams",
            sa.Numeric(18, 4),
            nullable=False,
            server_default="0",
        ),
    )

    # Add the non-negative check constraint that the model defines
    op.create_check_constraint(
        "ck_digital_metal_inventory_reserved_nonneg",
        "digital_metal_inventory",
        "reserved_weight_grams >= 0",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_digital_metal_inventory_reserved_nonneg",
        "digital_metal_inventory",
        type_="check",
    )
    op.drop_column("digital_metal_inventory", "reserved_weight_grams")
