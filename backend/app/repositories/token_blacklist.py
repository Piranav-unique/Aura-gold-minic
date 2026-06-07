from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.token_blacklist import TokenBlacklist
from app.repositories.base import BaseRepository


class TokenBlacklistRepository(BaseRepository[TokenBlacklist]):
    """Repository class handling query logic for TokenBlacklist model."""

    def __init__(self, db_session: AsyncSession):
        super().__init__(TokenBlacklist, db_session)

    async def get_by_jti(self, jti: str) -> Optional[TokenBlacklist]:
        """Fetch a blacklisted token entry by its unique JWT ID (jti)."""
        query = select(TokenBlacklist).where(TokenBlacklist.jti == jti)
        result = await self.db.execute(query)
        return result.scalars().first()

    async def is_blacklisted(self, jti: str) -> bool:
        """Check if a specific token JTI is already blacklisted."""
        token = await self.get_by_jti(jti)
        return token is not None

    async def blacklist_token(self, jti: str, expires_at: datetime) -> TokenBlacklist:
        """Add a token JTI to the blacklist to prevent future usage."""
        # Ensure UTC timezone if not already set
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        return await self.create({"jti": jti, "expires_at": expires_at})
