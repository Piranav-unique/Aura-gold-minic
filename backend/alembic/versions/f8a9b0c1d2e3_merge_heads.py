"""merge heads

Revision ID: f8a9b0c1d2e3
Revises: b3c4d5e6f7g8, e7f8a9b0c1d2
Create Date: 2026-09-28
"""

from typing import Sequence, Union

revision: str = "f8a9b0c1d2e3"
down_revision: Union[str, Sequence[str], None] = ("b3c4d5e6f7g8", "e7f8a9b0c1d2")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
