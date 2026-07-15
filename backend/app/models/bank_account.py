from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class UserBankAccount(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "user_bank_accounts"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    account_holder_name: Mapped[str] = mapped_column(String(200), nullable=False)
    account_number_encrypted: Mapped[str] = mapped_column(String(512), nullable=False)
    account_number_last4: Mapped[str] = mapped_column(String(4), nullable=False)
    ifsc: Mapped[str] = mapped_column(String(11), nullable=False)
    bank_name: Mapped[str] = mapped_column(String(200), nullable=False)
    branch_name: Mapped[str] = mapped_column(String(200), nullable=False)
    account_type: Mapped[str] = mapped_column(String(20), nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    verified_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    razorpay_fund_account_id: Mapped[str | None] = mapped_column(
        String(64), nullable=True
    )

    __table_args__ = (
        Index("ix_user_bank_accounts_user_id", "user_id"),
    )


class BankLinkChallenge(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "bank_link_challenges"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    account_holder_name: Mapped[str] = mapped_column(String(200), nullable=False)
    account_number_encrypted: Mapped[str] = mapped_column(String(512), nullable=False)
    account_number_last4: Mapped[str] = mapped_column(String(4), nullable=False)
    ifsc: Mapped[str] = mapped_column(String(11), nullable=False)
    bank_name: Mapped[str] = mapped_column(String(200), nullable=False)
    branch_name: Mapped[str] = mapped_column(String(200), nullable=False)
    account_type: Mapped[str] = mapped_column(String(20), nullable=False)
    otp_mobile: Mapped[str | None] = mapped_column(String(15), nullable=True)
    otp_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    consumed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    __table_args__ = (
        Index("ix_bank_link_challenges_user_created", "user_id", "created_at"),
    )
