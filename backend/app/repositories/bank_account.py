from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bank_account import BankLinkChallenge, UserBankAccount
from app.repositories.base import BaseRepository


class UserBankAccountRepository(BaseRepository[UserBankAccount]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(UserBankAccount, db_session)

    async def list_for_user(self, user_id: UUID) -> list[UserBankAccount]:
        query = (
            select(UserBankAccount)
            .where(UserBankAccount.user_id == user_id)
            .order_by(UserBankAccount.is_primary.desc(), UserBankAccount.created_at.desc())
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def get_for_user(
        self, user_id: UUID, account_id: UUID
    ) -> UserBankAccount | None:
        query = select(UserBankAccount).where(
            UserBankAccount.user_id == user_id,
            UserBankAccount.id == account_id,
        )
        result = await self.db.execute(query)
        return result.scalars().first()


class BankLinkChallengeRepository(BaseRepository[BankLinkChallenge]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(BankLinkChallenge, db_session)

    async def invalidate_pending(self, user_id: UUID) -> None:
        await self.db.execute(
            update(BankLinkChallenge)
            .where(
                BankLinkChallenge.user_id == user_id,
                BankLinkChallenge.consumed.is_(False),
            )
            .values(consumed=True)
        )

    async def get_latest_active(self, user_id: UUID) -> BankLinkChallenge | None:
        now = datetime.now(timezone.utc)
        query = (
            select(BankLinkChallenge)
            .where(
                BankLinkChallenge.user_id == user_id,
                BankLinkChallenge.consumed.is_(False),
                BankLinkChallenge.expires_at > now,
            )
            .order_by(BankLinkChallenge.created_at.desc())
            .limit(1)
        )
        result = await self.db.execute(query)
        return result.scalars().first()
