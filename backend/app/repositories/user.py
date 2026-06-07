from typing import Any, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    """Repository class handling query logic for User model."""

    def __init__(self, db_session: AsyncSession):
        super().__init__(User, db_session)

    async def get_by_email(self, email: str) -> Optional[User]:
        """Fetch a user record by email, excluding soft-deleted ones."""
        query = select(User).where(User.email == email, User.is_deleted.is_(False))
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_with_roles_and_permissions(self, user_id: Any) -> Optional[User]:
        """Fetch user with eager loading of roles and nested permissions."""
        from sqlalchemy.orm import selectinload
        from app.models.role import Role

        query = (
            select(User)
            .where(User.id == user_id, User.is_deleted.is_(False))
            .options(selectinload(User.roles).selectinload(Role.permissions))
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def list_users(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        is_active: Optional[bool] = None,
        is_superuser: Optional[bool] = None,
        role_id: Optional[Any] = None,
    ) -> list[User]:
        """Fetch users matching filters and search keywords, eagerly loading roles."""
        from sqlalchemy.orm import selectinload
        from app.models.role import Role

        # Safeguard query limit
        limit = min(limit, 100)

        query = (
            select(User)
            .where(User.is_deleted.is_(False))
            .options(selectinload(User.roles).selectinload(Role.permissions))
        )

        if search:
            pattern = f"%{search}%"
            query = query.where(
                User.email.ilike(pattern)
                | User.first_name.ilike(pattern)
                | User.last_name.ilike(pattern)
            )

        if is_active is not None:
            query = query.where(User.is_active == is_active)

        if is_superuser is not None:
            query = query.where(User.is_superuser == is_superuser)

        if role_id is not None:
            # Join roles and filter by role ID
            query = query.join(User.roles).where(Role.id == role_id)

        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().unique().all())
