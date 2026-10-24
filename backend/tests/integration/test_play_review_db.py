"""Google Play reviewer login against a real database and the HTTP API."""

import pytest
from sqlalchemy import select

from app.core.config import settings
from app.middleware.rate_limit_middleware import reset_rate_limit_store
from app.models.user import User
from app.services import play_review

REVIEW_MOBILE = "9000012345"
REVIEW_OTP = "582941"
DEVICE_ID = "3f1b2c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d"
LOGIN_URL = f"{settings.API_V1_STR}/auth/login/mobile"
SEND_URL = f"{settings.API_V1_STR}/auth/login/otp/send"


@pytest.fixture(autouse=True)
def _enabled(monkeypatch):
    monkeypatch.setattr(settings, "PLAY_STORE_REVIEW_MOBILE", REVIEW_MOBILE)
    monkeypatch.setattr(settings, "PLAY_STORE_REVIEW_OTP", REVIEW_OTP)
    play_review.reset_failed_attempts()
    reset_rate_limit_store()
    yield
    play_review.reset_failed_attempts()
    reset_rate_limit_store()


async def _reviewer(session) -> User | None:
    result = await session.execute(
        select(User).where(User.email == play_review.REVIEWER_EMAIL)
    )
    return result.scalars().first()


@pytest.mark.asyncio
async def test_reviewer_account_is_created_safely_and_can_log_in(test_db, db_client):
    await play_review.ensure_reviewer_account(test_db)
    await play_review.ensure_reviewer_account(test_db)  # idempotent on restart

    reviewer = await _reviewer(test_db)
    assert reviewer is not None
    assert reviewer.mobile_number == REVIEW_MOBILE
    assert reviewer.hashed_password
    assert reviewer.is_superuser is False
    assert reviewer.kyc_status == "not_started"
    assert reviewer.wallet_balance_inr == 0
    assert reviewer.gold_savings_grams == 0
    assert reviewer.silver_savings_grams == 0

    sent = await db_client.post(
        SEND_URL, json={"mobile_number": REVIEW_MOBILE, "device_id": DEVICE_ID}
    )
    assert sent.status_code == 200, sent.text

    wrong = await db_client.post(
        LOGIN_URL,
        json={"mobile_number": REVIEW_MOBILE, "otp": "582940", "device_id": DEVICE_ID},
    )
    assert wrong.status_code in (400, 401, 422), wrong.text

    ok = await db_client.post(
        LOGIN_URL,
        json={"mobile_number": REVIEW_MOBILE, "otp": REVIEW_OTP, "device_id": DEVICE_ID},
    )
    assert ok.status_code == 200, ok.text
    assert ok.json()["access_token"]


@pytest.mark.asyncio
async def test_real_customer_number_never_gets_the_shortcut(test_db, db_client):
    customer = User(
        email="real.customer@example.com",
        hashed_password="hash",
        mobile_number=REVIEW_MOBILE,
        mobile_verified=True,
        first_name="Real",
        last_name="Customer",
    )
    test_db.add(customer)
    await test_db.commit()

    await play_review.ensure_reviewer_account(test_db)
    assert await _reviewer(test_db) is None

    resp = await db_client.post(
        LOGIN_URL,
        json={"mobile_number": REVIEW_MOBILE, "otp": REVIEW_OTP, "device_id": DEVICE_ID},
    )
    assert resp.status_code != 200, resp.text


@pytest.mark.asyncio
async def test_disabled_reviewer_login_does_not_create_account(test_db, monkeypatch):
    monkeypatch.setattr(settings, "PLAY_STORE_REVIEW_OTP", "")
    await play_review.ensure_reviewer_account(test_db)
    assert await _reviewer(test_db) is None
