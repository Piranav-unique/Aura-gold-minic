from typing import Any, Optional

from sqlalchemy import func, select
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

    async def get_by_mobile(self, mobile_number: str) -> Optional[User]:
        """Fetch a user record by mobile number, excluding soft-deleted ones."""
        query = select(User).where(
            User.mobile_number == mobile_number,
            User.is_deleted.is_(False),
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_by_registered_device_id(self, device_id: str) -> Optional[User]:
        """Fetch a user linked to a device, excluding soft-deleted ones."""
        query = select(User).where(
            User.registered_device_id == device_id,
            User.is_deleted.is_(False),
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_by_referral_code(self, referral_code: str) -> Optional[User]:
        query = select(User).where(
            User.referral_code == referral_code,
            User.is_deleted.is_(False),
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_user_ids_with_permission(self, permission_name: str) -> list[Any]:
        """Return active user IDs granted a specific permission."""
        from app.models.permission import Permission
        from app.models.role import Role

        query = (
            select(User.id)
            .join(User.roles)
            .join(Role.permissions)
            .where(
                User.is_deleted.is_(False),
                User.is_active.is_(True),
                Permission.name == permission_name,
            )
            .distinct()
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

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
                | User.mobile_number.ilike(pattern)
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

    async def count_active_users(self) -> int:
        query = select(func.count(User.id)).where(
            User.is_deleted.is_(False),
            User.is_active.is_(True),
        )
        result = await self.db.execute(query)
        return int(result.scalar() or 0)
