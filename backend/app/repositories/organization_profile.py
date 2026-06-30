from __future__ import annotations

from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.organization_profile import OrganizationProfile
from app.repositories.base import BaseRepository


class OrganizationProfileRepository(BaseRepository[OrganizationProfile]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(OrganizationProfile, db_session)

    async def get_singleton(self) -> Optional[OrganizationProfile]:
        result = await self.db.execute(
            select(OrganizationProfile).order_by(OrganizationProfile.created_at).limit(1)
        )
        return result.scalars().first()
