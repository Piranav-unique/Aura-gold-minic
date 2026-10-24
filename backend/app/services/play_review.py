"""Google Play review demo login.

Play reviewers cannot receive Indian SMS OTPs, so a single dedicated demo
account may log in with a fixed OTP. The shortcut is off unless both
PLAY_STORE_REVIEW_MOBILE and PLAY_STORE_REVIEW_OTP are set in the server .env,
and it only ever applies to the dedicated reviewer account: if the configured
number belongs to a real customer, the shortcut stays off for it.
"""

import hmac
import secrets
import time
from collections import deque
from typing import Optional

from sqlalchemy import select

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.core.logging import logger
from app.core.security import get_password_hash
from app.models.user import User
from app.repositories.user import UserRepository
from app.utils.mobile import normalize_mobile

REVIEWER_EMAIL = "playreviewer@aurumgold.co.in"

_WEAK_OTPS = frozenset(
    {"123456", "654321", "000000", "111111", "121212", "123123", "112233"}
)
_MAX_FAILED_ATTEMPTS_PER_HOUR = 20
_failed_attempts: deque[float] = deque()


def _configured_mobile() -> str:
    raw = (settings.PLAY_STORE_REVIEW_MOBILE or "").strip()
    if not raw:
        return ""
    try:
        return normalize_mobile(raw)
    except ValidationException:
        return ""


def _configured_otp() -> str:
    return (settings.PLAY_STORE_REVIEW_OTP or "").strip()


def reviewer_login_enabled() -> bool:
    otp = _configured_otp()
    return (
        len(_configured_mobile()) == 10
        and otp.isdigit()
        and len(otp) == settings.SIGNUP_OTP_LENGTH
        and otp not in _WEAK_OTPS
        and len(set(otp)) > 2
    )


def is_reviewer_account(user: Optional[User]) -> bool:
    return bool(
        user is not None
        and user.email == REVIEWER_EMAIL
        and user.is_active
        and not user.is_deleted
        and not user.is_superuser
    )


async def reviewer_shortcut_applies(user_repo: UserRepository, mobile_number: str) -> bool:
    """True only for the configured number when it belongs to the reviewer account."""
    if not reviewer_login_enabled():
        return False
    try:
        if normalize_mobile(mobile_number) != _configured_mobile():
            return False
    except ValidationException:
        return False
    return is_reviewer_account(await user_repo.get_by_mobile(mobile_number))


def _locked_out(now: float) -> bool:
    while _failed_attempts and now - _failed_attempts[0] > 3600:
        _failed_attempts.popleft()
    return len(_failed_attempts) >= _MAX_FAILED_ATTEMPTS_PER_HOUR


def check_reviewer_otp(otp: str) -> bool:
    """Constant-time OTP check with a global lockout against brute force."""
    now = time.monotonic()
    if _locked_out(now):
        logger.warning("play_review_login_locked_out")
        return False
    if hmac.compare_digest(otp.strip().encode(), _configured_otp().encode()):
        return True
    _failed_attempts.append(now)
    return False


def reset_failed_attempts() -> None:
    _failed_attempts.clear()


async def ensure_reviewer_account(session) -> None:
    """Create the reviewer account on startup when the demo login is enabled.

    The account has no money, no verified KYC and an unusable random password.
    """
    if not reviewer_login_enabled():
        return

    mobile = _configured_mobile()
    existing = await UserRepository(session).get_by_mobile(mobile)
    if existing is not None:
        if not is_reviewer_account(existing):
            logger.error(
                "play_review_mobile_belongs_to_another_account",
                message="PLAY_STORE_REVIEW_MOBILE is a real user's number; reviewer login stays off.",
            )
        return

    by_email = await session.execute(select(User).where(User.email == REVIEWER_EMAIL))
    reviewer = by_email.scalars().first()
    if reviewer is not None:
        # Reviewer number was changed in .env: move the demo account to it.
        reviewer.mobile_number = mobile
        reviewer.is_active = True
        reviewer.is_deleted = False
    else:
        session.add(
            User(
                email=REVIEWER_EMAIL,
                hashed_password=get_password_hash(secrets.token_urlsafe(32)),
                mobile_number=mobile,
                mobile_verified=True,
                first_name="Google Play",
                last_name="Reviewer",
                is_active=True,
                is_superuser=False,
                kyc_status="not_started",
            )
        )
    await session.commit()
    logger.info("play_review_account_ready")
