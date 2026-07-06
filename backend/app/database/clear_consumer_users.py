"""Remove end-user (AURUM app) accounts and their data; keep admin/staff users."""

import asyncio
from decimal import Decimal

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.logging import logger, setup_logging
from app.database.session import async_session_maker
from app.models.audit_log import AuditLog
from app.models.bank_account import BankLinkChallenge, UserBankAccount
from app.models.digital_metal_inventory import (
    DigitalMetalInventory,
    DigitalMetalInventoryMovement,
)
from app.models.gold_sell_inquiry import GoldSellInquiry
from app.models.notification import Notification
from app.models.payment_order import PaymentOrder
from app.models.referral_reward import ReferralReward
from app.models.signup_otp import SignupOtpChallenge
from app.models.signup_email_otp import SignupEmailOtpChallenge
from app.models.role import Role  # noqa: F401 — register mapper for User.roles
from app.models.permission import Permission  # noqa: F401 — register mapper for Role.permissions
from app.models.user import User
from app.models.user_settings import UserSettings
from app.models.workflow import (
    WorkflowApprovalHistory,
    WorkflowComment,
    WorkflowRequest,
)

STAFF_ROLE_NAMES = frozenset({"super_admin", "admin", "manager", "employee"})


async def _table_exists(session: AsyncSession, table_name: str) -> bool:
    from sqlalchemy import text

    result = await session.execute(
        text(
            "SELECT EXISTS ("
            "SELECT FROM information_schema.tables "
            "WHERE table_schema = 'public' AND table_name = :table_name"
            ")"
        ),
        {"table_name": table_name},
    )
    return bool(result.scalar())


async def _delete_signup_email_otp_challenges(session: AsyncSession) -> None:
    if await _table_exists(session, SignupEmailOtpChallenge.__tablename__):
        await session.execute(delete(SignupEmailOtpChallenge))


def is_staff_user(user: User) -> bool:
    if user.is_superuser:
        return True
    role_names = {role.name for role in user.roles}
    return bool(role_names & STAFF_ROLE_NAMES)


async def _recalculate_digital_metal_used(session: AsyncSession) -> None:
    """Set used_weight_grams from remaining purchase_debit ledger rows."""
    result = await session.execute(select(DigitalMetalInventory))
    inventories = result.scalars().all()
    if not inventories:
        return

    movement_result = await session.execute(
        select(DigitalMetalInventoryMovement).where(
            DigitalMetalInventoryMovement.movement_type == "purchase_debit"
        )
    )
    debits = movement_result.scalars().all()
    used_by_metal: dict[str, Decimal] = {"gold": Decimal("0"), "silver": Decimal("0")}
    for row in debits:
        metal = row.metal_type
        if metal in used_by_metal:
            used_by_metal[metal] += abs(Decimal(str(row.grams_delta or 0)))

    for inv in inventories:
        inv.used_weight_grams = used_by_metal.get(inv.metal_type, Decimal("0"))


async def clear_consumer_users(session: AsyncSession) -> int:
    """
    Delete AURUM consumer accounts (role ``user`` only) and related records.
    Preserves super_admin, admin, manager, employee accounts and business tables.
    """
    result = await session.execute(
        select(User).options(selectinload(User.roles))
    )
    users = result.scalars().all()
    consumer_ids = [user.id for user in users if not is_staff_user(user)]

    if not consumer_ids:
        await session.execute(delete(SignupOtpChallenge))
        await _delete_signup_email_otp_challenges(session)
        await session.commit()
        logger.info(
            "consumer_users_cleared",
            message="No consumer users found. Cleared signup OTP challenges only.",
            deleted_users=0,
        )
        return 0

    logger.info(
        "consumer_users_clearing",
        message=f"Removing {len(consumer_ids)} consumer user(s)...",
    )

    payment_result = await session.execute(
        select(PaymentOrder.id).where(PaymentOrder.user_id.in_(consumer_ids))
    )
    payment_order_ids = [row[0] for row in payment_result.all()]

    if payment_order_ids:
        await session.execute(
            delete(DigitalMetalInventoryMovement).where(
                DigitalMetalInventoryMovement.payment_order_id.in_(payment_order_ids)
            )
        )
    await session.execute(
        delete(DigitalMetalInventoryMovement).where(
            DigitalMetalInventoryMovement.user_id.in_(consumer_ids)
        )
    )
    await session.execute(
        delete(GoldSellInquiry).where(GoldSellInquiry.user_id.in_(consumer_ids))
    )
    await session.execute(
        delete(PaymentOrder).where(PaymentOrder.user_id.in_(consumer_ids))
    )
    await session.execute(
        delete(BankLinkChallenge).where(BankLinkChallenge.user_id.in_(consumer_ids))
    )
    await session.execute(
        delete(UserBankAccount).where(UserBankAccount.user_id.in_(consumer_ids))
    )
    await session.execute(
        delete(ReferralReward).where(
            ReferralReward.referrer_id.in_(consumer_ids)
            | ReferralReward.referee_id.in_(consumer_ids)
        )
    )
    await session.execute(
        delete(Notification).where(Notification.user_id.in_(consumer_ids))
    )
    await session.execute(
        delete(UserSettings).where(UserSettings.user_id.in_(consumer_ids))
    )
    await session.execute(
        delete(AuditLog).where(AuditLog.user_id.in_(consumer_ids))
    )

    workflow_result = await session.execute(
        select(WorkflowRequest.id).where(
            WorkflowRequest.requester_id.in_(consumer_ids)
        )
    )
    workflow_request_ids = [row[0] for row in workflow_result.all()]
    if workflow_request_ids:
        await session.execute(
            delete(WorkflowComment).where(
                WorkflowComment.request_id.in_(workflow_request_ids)
            )
        )
        await session.execute(
            delete(WorkflowApprovalHistory).where(
                WorkflowApprovalHistory.request_id.in_(workflow_request_ids)
            )
        )
        await session.execute(
            delete(WorkflowRequest).where(
                WorkflowRequest.id.in_(workflow_request_ids)
            )
        )

    await session.execute(delete(SignupOtpChallenge))
    await _delete_signup_email_otp_challenges(session)

    for user_id in consumer_ids:
        user = await session.get(User, user_id)
        if user is not None:
            await session.delete(user)

    await _recalculate_digital_metal_used(session)
    await session.commit()

    logger.info(
        "consumer_users_cleared",
        message="Consumer users and related app data removed.",
        deleted_users=len(consumer_ids),
    )
    return len(consumer_ids)


async def main() -> None:
    setup_logging()
    async with async_session_maker() as session:
        deleted = await clear_consumer_users(session)
    print(f"Removed {deleted} consumer user(s). Admin/staff accounts were kept.")


if __name__ == "__main__":
    asyncio.run(main())
