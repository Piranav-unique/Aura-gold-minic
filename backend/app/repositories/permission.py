from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.permission import Permission
from app.repositories.base import BaseRepository


class PermissionRepository(BaseRepository[Permission]):
    """Repository class handling query logic for Permission model."""

    def __init__(self, db_session: AsyncSession):
        super().__init__(Permission, db_session)

    async def get_by_name(self, name: str) -> Optional[Permission]:
        """Fetch a permission record by name."""
        query = select(Permission).where(Permission.name == name)
        result = await self.db.execute(query)
        return result.scalars().first()
