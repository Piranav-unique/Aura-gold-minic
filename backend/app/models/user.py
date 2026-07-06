from __future__ import annotations
from typing import List, TYPE_CHECKING
from datetime import datetime
from decimal import Decimal
from datetime import datetime
import uuid

from sqlalchemy import String, Boolean, Index, Text, Integer, Numeric, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin
from app.models.associations import user_roles

if TYPE_CHECKING:
    from app.models.role import Role


class User(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_superuser: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    first_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    last_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    mobile_number: Mapped[str | None] = mapped_column(String(15), nullable=True)
    mobile_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    avatar_base64: Mapped[str | None] = mapped_column(Text, nullable=True)
    avatar_content_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    token_version: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    kyc_status: Mapped[str] = mapped_column(
        String(20), default="not_started", nullable=False
    )
    kyc_aadhaar_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    kyc_aadhaar_last4: Mapped[str | None] = mapped_column(String(4), nullable=True)
    kyc_pan_last4: Mapped[str | None] = mapped_column(String(4), nullable=True)
    kyc_profile: Mapped[str | None] = mapped_column(Text, nullable=True)
    gold_savings_grams: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), default=Decimal("0"), nullable=False
    )
    silver_savings_grams: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), default=Decimal("0"), nullable=False
    )
    gold_invested_inr: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), default=Decimal("0"), nullable=False
    )
    silver_invested_inr: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), default=Decimal("0"), nullable=False
    )
    gold_scheme_target_grams: Mapped[Decimal | None] = mapped_column(
        Numeric(18, 4), nullable=True
    )
    gold_scheme_status: Mapped[str] = mapped_column(
        String(20), default="not_selected", nullable=False
    )
    gold_scheme_started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    referral_code: Mapped[str | None] = mapped_column(String(16), nullable=True)
    referred_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    referral_scheme_grams: Mapped[Decimal | None] = mapped_column(
        Numeric(18, 4), nullable=True
    )
    wallet_balance_inr: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), default=Decimal("0"), nullable=False
    )
    razorpay_contact_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    registered_device_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    has_completed_mobile_login: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )

    # Relationships
    roles: Mapped[List["Role"]] = relationship(
        "Role", secondary=user_roles, back_populates="users"
    )

    __table_args__ = (
        Index(
            "ix_users_email_active",
            "email",
            unique=True,
            postgresql_where="is_deleted = false",
        ),
        Index(
            "ix_users_mobile_active",
            "mobile_number",
            unique=True,
            postgresql_where="is_deleted = false AND mobile_number IS NOT NULL",
        ),
    )
