"""Wipe application data and re-seed roles, permissions, and super admin."""

import asyncio

from decimal import Decimal

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.logging import logger, setup_logging
from app.database.seed import seed_data
from app.database.session import async_session_maker
from app.models.audit_log import AuditLog
from app.models.customer import Customer
from app.models.digital_metal_inventory import (
    DigitalMetalInventory,
    DigitalMetalInventoryMovement,
)
from app.models.inventory_item import InventoryItem
from app.models.notification import Notification
from app.models.payment_order import PaymentOrder
from app.models.bank_account import BankLinkChallenge, UserBankAccount
from app.models.gold_sell_inquiry import GoldSellInquiry
from app.models.referral_reward import ReferralReward
from app.models.signup_otp import SignupOtpChallenge
from app.models.signup_email_otp import SignupEmailOtpChallenge
from app.models.stock_movement import StockMovement
from app.models.supplier import Supplier
from app.models.token_blacklist import TokenBlacklist
from app.models.transaction import Transaction, TransactionLine
from app.models.user import User
from app.models.user_settings import UserSettings
from app.models.workflow import (
    WorkflowApprovalHistory,
    WorkflowComment,
    WorkflowRequest,
)


async def reset_application_data(session: AsyncSession) -> None:
    """Delete users and transactional records; keep schema and re-seed defaults."""
    logger.info("database_reset", message="Clearing application data...")

    await session.execute(delete(WorkflowComment))
    await session.execute(delete(WorkflowApprovalHistory))
    await session.execute(delete(WorkflowRequest))
    await session.execute(delete(TransactionLine))
    await session.execute(delete(Transaction))
    await session.execute(delete(DigitalMetalInventoryMovement))
    await session.execute(
        update(DigitalMetalInventory).values(
            used_weight_grams=Decimal("0"),
            updated_by=None,
        )
    )
    await session.execute(delete(PaymentOrder))
    await session.execute(delete(GoldSellInquiry))
    await session.execute(delete(BankLinkChallenge))
    await session.execute(delete(UserBankAccount))
    await session.execute(delete(SignupOtpChallenge))
    await session.execute(delete(SignupEmailOtpChallenge))
    await session.execute(delete(ReferralReward))
    await session.execute(delete(StockMovement))
    await session.execute(delete(InventoryItem))
    await session.execute(delete(Supplier))
    await session.execute(delete(Customer))
    await session.execute(delete(Notification))
    await session.execute(delete(AuditLog))
    await session.execute(delete(TokenBlacklist))
    await session.execute(delete(UserSettings))

    await session.execute(delete(User))

    await session.commit()
    logger.info("database_reset", message="Application data cleared. Re-seeding...")
    await seed_data(session)


async def main() -> None:
    setup_logging()
    async with async_session_maker() as session:
        await reset_application_data(session)
    logger.info("database_reset_complete", message="Database reset completed.")


if __name__ == "__main__":
    asyncio.run(main())
