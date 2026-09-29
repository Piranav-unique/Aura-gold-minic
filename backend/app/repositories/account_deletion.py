import uuid
from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.account_deletion_request import AccountDeletionRequest
from app.repositories.base import BaseRepository


class AccountDeletionRepository(BaseRepository[AccountDeletionRequest]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(AccountDeletionRequest, db_session)

    async def get_active_for_user(
        self, user_id: uuid.UUID
    ) -> Optional[AccountDeletionRequest]:
        query = (
            select(AccountDeletionRequest)
            .where(
                AccountDeletionRequest.user_id == user_id,
                AccountDeletionRequest.status == "pending",
            )
            .order_by(AccountDeletionRequest.created_at.desc())
            .limit(1)
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_latest_for_user(
        self, user_id: uuid.UUID
    ) -> Optional[AccountDeletionRequest]:
        query = (
            select(AccountDeletionRequest)
            .where(AccountDeletionRequest.user_id == user_id)
            .order_by(AccountDeletionRequest.created_at.desc())
            .limit(1)
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def list_all(
        self,
        skip: int = 0,
        limit: int = 50,
        status: Optional[str] = None,
    ) -> list[AccountDeletionRequest]:
        query = (
            select(AccountDeletionRequest)
            .options(selectinload(AccountDeletionRequest.user))
            .order_by(AccountDeletionRequest.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        if status:
            query = query.where(AccountDeletionRequest.status == status)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def count_all(self, status: Optional[str] = None) -> int:
        query = select(func.count()).select_from(AccountDeletionRequest)
        if status:
            query = query.where(AccountDeletionRequest.status == status)
        result = await self.db.execute(query)
        return int(result.scalar_one())
