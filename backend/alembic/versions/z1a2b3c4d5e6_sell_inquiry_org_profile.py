"""sell inquiry enhancements and organization profile

Revision ID: z1a2b3c4d5e6
Revises: y0z1a2b3c4d5
Create Date: 2026-06-28
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "z1a2b3c4d5e6"
down_revision: Union[str, None] = "y0z1a2b3c4d5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "organization_profiles",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("organization_name", sa.String(length=200), nullable=False),
        sa.Column("admin_name", sa.String(length=200), nullable=False),
        sa.Column("support_contact_number", sa.String(length=20), nullable=False),
        sa.Column("support_email", sa.String(length=255), nullable=True),
        sa.Column("office_address", sa.Text(), nullable=True),
        sa.Column("business_gst", sa.String(length=32), nullable=True),
        sa.Column("business_pan", sa.String(length=16), nullable=True),
        sa.Column("logo_url", sa.Text(), nullable=True),
        sa.Column("upi_id", sa.String(length=100), nullable=True),
        sa.Column("google_pay_id", sa.String(length=100), nullable=True),
        sa.Column("phonepe_id", sa.String(length=100), nullable=True),
        sa.Column("paytm_id", sa.String(length=100), nullable=True),
        sa.Column("bank_name", sa.String(length=200), nullable=True),
        sa.Column("account_number", sa.String(length=32), nullable=True),
        sa.Column("ifsc", sa.String(length=11), nullable=True),
        sa.Column("qr_code_image", sa.Text(), nullable=True),
        sa.Column("business_hours", sa.String(length=200), nullable=True),
        sa.Column("emergency_contact", sa.String(length=20), nullable=True),
        sa.Column("updated_by", sa.UUID(), nullable=True),
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
        sa.ForeignKeyConstraint(["updated_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.execute(
        """
        INSERT INTO organization_profiles (
            id, organization_name, admin_name, support_contact_number,
            support_email, office_address, business_hours
        ) VALUES (
            gen_random_uuid(),
            'AGS Gold',
            'AGS Gold Support',
            '+91 98765 43210',
            'support@agsgold.com',
            'Chennai, Tamil Nadu, India',
            'Mon–Sat, 10:00 AM – 6:00 PM IST'
        )
        """
    )

    op.add_column(
        "gold_sell_inquiries",
        sa.Column("quantity_grams", sa.Numeric(18, 4), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("sell_rate_per_gram", sa.Numeric(18, 4), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("gross_amount_inr", sa.Numeric(18, 2), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("platform_charge_inr", sa.Numeric(18, 2), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("tax_amount_inr", sa.Numeric(18, 2), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("net_payable_inr", sa.Numeric(18, 2), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("payment_method", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("payment_destination", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("reference_number", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("rejection_reason", sa.Text(), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("approved_by_user_id", sa.UUID(), nullable=True),
    )
    op.add_column(
        "gold_sell_inquiries",
        sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_gold_sell_inquiries_approved_by",
        "gold_sell_inquiries",
        "users",
        ["approved_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_gold_sell_inquiries_approved_by", "gold_sell_inquiries", type_="foreignkey"
    )
    for col in (
        "approved_at",
        "approved_by_user_id",
        "rejection_reason",
        "reference_number",
        "payment_destination",
        "payment_method",
        "net_payable_inr",
        "tax_amount_inr",
        "platform_charge_inr",
        "gross_amount_inr",
        "sell_rate_per_gram",
        "quantity_grams",
    ):
        op.drop_column("gold_sell_inquiries", col)
    op.drop_table("organization_profiles")
