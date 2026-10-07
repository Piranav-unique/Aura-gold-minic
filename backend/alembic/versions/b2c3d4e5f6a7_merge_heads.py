"""merge heads: reserved_weight_grams and totp columns

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6, e6f7g8h9i0j1
Create Date: 2026-10-07

Merge migration to reconcile two divergent heads:
  - a1b2c3d4e5f6: add reserved_weight_grams to digital_metal_inventory
  - e6f7g8h9i0j1: add admin TOTP 2FA columns to users
"""

from typing import Sequence, Union

revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, Sequence[str], None] = ("a1b2c3d4e5f6", "e6f7g8h9i0j1")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
