from typing import Any, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.role import Role
from app.repositories.base import BaseRepository


class RoleRepository(BaseRepository[Role]):
    """Repository class handling query logic for Role model."""

    def __init__(self, db_session: AsyncSession):
        super().__init__(Role, db_session)

    async def get_by_name(self, name: str) -> Optional[Role]:
        """Fetch a role record by name, excluding soft-deleted ones."""
        query = select(Role).where(Role.name == name, Role.is_deleted.is_(False))
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_with_permissions(self, role_id: Any) -> Optional[Role]:
        """Fetch a role with its associated permissions eagerly loaded."""
        query = (
            select(Role)
            .where(Role.id == role_id, Role.is_deleted.is_(False))
            .options(selectinload(Role.permissions))
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_by_ids(self, role_ids: list[Any]) -> list[Role]:
        """Fetch multiple roles by their IDs in a single query."""
        if not role_ids:
            return []
        query = select(Role).where(Role.id.in_(role_ids), Role.is_deleted.is_(False))
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list(self, skip: int = 0, limit: int = 100) -> list[Role]:
        """Fetch a list of active roles with permissions loaded."""
        query = (
            select(Role)
            .where(Role.is_deleted.is_(False))
            .offset(skip)
            .limit(limit)
            .options(selectinload(Role.permissions))
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())
