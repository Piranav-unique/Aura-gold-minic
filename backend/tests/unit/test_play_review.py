from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.models.user import User
from app.services import play_review
from app.services.signup_otp import SignupOtpService

REVIEW_MOBILE = "9000012345"
REVIEW_OTP = "582941"


def _user(email: str, *, superuser: bool = False) -> User:
    return User(
        email=email,
        hashed_password="x",
        mobile_number=REVIEW_MOBILE,
        mobile_verified=True,
        is_active=True,
        is_deleted=False,
        is_superuser=superuser,
    )


@pytest.fixture(autouse=True)
def _reset(monkeypatch):
    monkeypatch.setattr(settings, "PLAY_STORE_REVIEW_MOBILE", "")
    monkeypatch.setattr(settings, "PLAY_STORE_REVIEW_OTP", "")
    play_review.reset_failed_attempts()
    yield
    play_review.reset_failed_attempts()


def _enable(monkeypatch, otp: str = REVIEW_OTP):
    monkeypatch.setattr(settings, "PLAY_STORE_REVIEW_MOBILE", REVIEW_MOBILE)
    monkeypatch.setattr(settings, "PLAY_STORE_REVIEW_OTP", otp)


def _service(account):
    otp_repo = MagicMock()
    otp_repo.get_latest_active = AsyncMock(return_value=None)
    user_repo = MagicMock()
    user_repo.get_by_mobile = AsyncMock(return_value=account)
    sms = MagicMock()
    sms.uses_msg91_native_otp = False
    service = SignupOtpService(otp_repo, user_repo, sms)
    service._send_otp_challenge = AsyncMock()
    return service, otp_repo


def test_disabled_by_default():
    assert play_review.reviewer_login_enabled() is False


@pytest.mark.parametrize("otp", ["123456", "000000", "111111", "112233", "12345", "abcdef"])
def test_weak_or_malformed_otp_keeps_shortcut_off(monkeypatch, otp):
    _enable(monkeypatch, otp)
    assert play_review.reviewer_login_enabled() is False


@pytest.mark.asyncio
async def test_reviewer_logs_in_with_configured_otp_without_sms(monkeypatch):
    _enable(monkeypatch)
    service, otp_repo = _service(_user(play_review.REVIEWER_EMAIL))

    await service.send_login_otp(REVIEW_MOBILE, "3f1b2c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d")
    service._send_otp_challenge.assert_not_awaited()

    await service.consume_login_otp(REVIEW_MOBILE, REVIEW_OTP)
    otp_repo.get_latest_active.assert_not_awaited()


@pytest.mark.asyncio
async def test_reviewer_wrong_otp_rejected(monkeypatch):
    _enable(monkeypatch)
    service, _ = _service(_user(play_review.REVIEWER_EMAIL))
    with pytest.raises(ValidationException):
        await service.consume_login_otp(REVIEW_MOBILE, "582940")


@pytest.mark.asyncio
async def test_reviewer_shortcut_locks_out_after_repeated_failures(monkeypatch):
    _enable(monkeypatch)
    service, _ = _service(_user(play_review.REVIEWER_EMAIL))
    for _ in range(20):
        with pytest.raises(ValidationException):
            await service.consume_login_otp(REVIEW_MOBILE, "000001")
    with pytest.raises(ValidationException):
        await service.consume_login_otp(REVIEW_MOBILE, REVIEW_OTP)


@pytest.mark.asyncio
async def test_shortcut_never_applies_to_a_real_customer_with_that_number(monkeypatch):
    _enable(monkeypatch)
    service, otp_repo = _service(_user("real.customer@example.com"))

    await service.send_login_otp(REVIEW_MOBILE, "3f1b2c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d")
    service._send_otp_challenge.assert_awaited_once()

    with pytest.raises(ValidationException):
        await service.consume_login_otp(REVIEW_MOBILE, REVIEW_OTP)
    otp_repo.get_latest_active.assert_awaited_once()


@pytest.mark.asyncio
async def test_shortcut_never_applies_to_an_admin_account(monkeypatch):
    _enable(monkeypatch)
    service, _ = _service(_user(play_review.REVIEWER_EMAIL, superuser=True))
    with pytest.raises(ValidationException):
        await service.consume_login_otp(REVIEW_MOBILE, REVIEW_OTP)


@pytest.mark.asyncio
async def test_disabled_shortcut_uses_normal_otp_flow(monkeypatch):
    service, otp_repo = _service(_user(play_review.REVIEWER_EMAIL))
    with pytest.raises(ValidationException):
        await service.consume_login_otp(REVIEW_MOBILE, REVIEW_OTP)
    otp_repo.get_latest_active.assert_awaited_once()


def _session(existing_by_email=None):
    session = MagicMock()
    session.add = MagicMock()
    session.commit = AsyncMock()
    result = MagicMock()
    result.scalars.return_value.first.return_value = existing_by_email
    session.execute = AsyncMock(return_value=result)
    return session


@pytest.mark.asyncio
async def test_ensure_account_creates_safe_reviewer(monkeypatch):
    _enable(monkeypatch)
    repo = MagicMock()
    repo.get_by_mobile = AsyncMock(return_value=None)
    monkeypatch.setattr(play_review, "UserRepository", lambda session: repo)
    session = _session()

    await play_review.ensure_reviewer_account(session)

    created = session.add.call_args.args[0]
    assert created.email == play_review.REVIEWER_EMAIL
    assert created.mobile_number == REVIEW_MOBILE
    assert created.hashed_password
    assert created.is_superuser is False
    assert created.kyc_status == "not_started"
    assert not created.wallet_balance_inr
    assert created.gold_savings_grams in (None, Decimal("0"))
    session.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_ensure_account_leaves_real_customer_untouched(monkeypatch):
    _enable(monkeypatch)
    repo = MagicMock()
    repo.get_by_mobile = AsyncMock(return_value=_user("real.customer@example.com"))
    monkeypatch.setattr(play_review, "UserRepository", lambda session: repo)
    session = _session()

    await play_review.ensure_reviewer_account(session)

    session.add.assert_not_called()
    session.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_ensure_account_does_nothing_when_disabled(monkeypatch):
    session = _session()
    await play_review.ensure_reviewer_account(session)
    session.add.assert_not_called()
    session.execute.assert_not_awaited()
