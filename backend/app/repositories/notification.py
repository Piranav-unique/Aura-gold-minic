import uuid
from datetime import datetime
from typing import Any, List, Optional
from sqlalchemy import select, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification
from app.repositories.base import BaseRepository


class NotificationRepository(BaseRepository[Notification]):
    """Repository class handling query logic for Notification model."""

    def __init__(self, db_session: AsyncSession):
        super().__init__(Notification, db_session)

    async def list_for_user(
        self,
        user_id: uuid.UUID,
        skip: int = 0,
        limit: int = 50,
        category: Optional[str] = None,
        is_read: Optional[bool] = None,
    ) -> list[Notification]:
        limit = min(limit, 100)
        query = (
            select(Notification)
            .where(Notification.user_id == user_id)
            .order_by(Notification.created_at.desc())
        )
        if category:
            query = query.where(Notification.category == category)
        if is_read is not None:
            query = query.where(Notification.is_read == is_read)
        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def count_for_user(
        self,
        user_id: uuid.UUID,
        category: Optional[str] = None,
        is_read: Optional[bool] = None,
    ) -> int:
        query = (
            select(func.count())
            .select_from(Notification)
            .where(Notification.user_id == user_id)
        )
        if category:
            query = query.where(Notification.category == category)
        if is_read is not None:
            query = query.where(Notification.is_read == is_read)
        result = await self.db.execute(query)
        return result.scalar() or 0

    async def mark_read(
        self,
        user_id: uuid.UUID,
        notification_ids: Optional[List[uuid.UUID]] = None,
        mark_all: bool = False,
    ) -> int:
        stmt = (
            update(Notification)
            .where(Notification.user_id == user_id, Notification.is_read.is_(False))
            .values(is_read=True)
        )
        if not mark_all and notification_ids:
            stmt = stmt.where(Notification.id.in_(notification_ids))
        elif not mark_all:
            return 0

        result = await self.db.execute(stmt)
        await self.db.commit()
        return result.rowcount or 0

    async def has_recent_notification(
        self,
        user_id: uuid.UUID,
        category: str,
        title: str,
        since: datetime,
    ) -> bool:
        query = (
            select(func.count())
            .select_from(Notification)
            .where(
                Notification.user_id == user_id,
                Notification.category == category,
                Notification.title == title,
                Notification.created_at >= since,
            )
        )
        result = await self.db.execute(query)
        return (result.scalar() or 0) > 0

    async def get_users_with_role(self, role_id: Any) -> list[uuid.UUID]:
        """Return user IDs that have a given role."""
        from app.models.user import User

        query = select(User.id).join(User.roles).where(User.is_deleted.is_(False))
        from app.models.role import Role

        query = query.where(Role.id == role_id)
        result = await self.db.execute(query)
        return list(result.scalars().all())
