from __future__ import annotations

import uuid
from typing import Optional

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class OrganizationProfile(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Singleton-style organization / support contact configuration."""

    __tablename__ = "organization_profiles"

    organization_name: Mapped[str] = mapped_column(String(200), nullable=False, default="AGS Gold")
    admin_name: Mapped[str] = mapped_column(String(200), nullable=False, default="AGS Gold Support")
    support_contact_number: Mapped[str] = mapped_column(String(20), nullable=False, default="")
    support_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    office_address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    business_gst: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    business_pan: Mapped[Optional[str]] = mapped_column(String(16), nullable=True)
    logo_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    upi_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    google_pay_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    phonepe_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    paytm_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    bank_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    account_number: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    ifsc: Mapped[Optional[str]] = mapped_column(String(11), nullable=True)
    qr_code_image: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    business_hours: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    emergency_contact: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    updated_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
