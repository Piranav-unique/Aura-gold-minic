from datetime import datetime
from sqlalchemy import String, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from app.models.base import Base, UUIDPrimaryKeyMixin, TimestampMixin


class TokenBlacklist(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Model to store blacklisted refresh token JTIs to prevent reuse."""

    __tablename__ = "token_blacklist"

    jti: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
