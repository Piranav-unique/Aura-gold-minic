"""Remove end-user (AURUM app) accounts and their data; keep admin/staff users."""

import asyncio

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.logging import logger, setup_logging
from app.database.session import async_session_maker
from app.models.role import Role  # noqa: F401 — register mapper for User.roles
from app.models.permission import Permission  # noqa: F401 — register mapper for Role.permissions
from app.models.user import User
from app.services.consumer_account_deletion import (
    _recalculate_digital_metal_used,
    is_staff_user,
    purge_consumer_user_data,
)


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
        await purge_consumer_user_data(
            session, [], clear_all_signup_otp_challenges=True
        )
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

    await purge_consumer_user_data(
        session,
        consumer_ids,
        clear_all_signup_otp_challenges=True,
    )

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
