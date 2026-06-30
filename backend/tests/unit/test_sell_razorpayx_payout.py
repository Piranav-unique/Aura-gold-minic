from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.razorpayx_client import RazorpayXClient
from app.services.sell_razorpayx_payout import SellRazorpayXPayoutService


def _user():
    user = MagicMock()
    user.id = "user-1"
    user.email = "u@test.com"
    user.first_name = "Test"
    user.last_name = "User"
    user.mobile_number = "9876543210"
    user.razorpay_contact_id = None
    return user


def _bank():
    bank = MagicMock()
    bank.account_holder_name = "Test User"
    bank.ifsc = "HDFC0000001"
    bank.bank_name = "HDFC"
    bank.account_number_last4 = "1234"
    bank.account_number_encrypted = "enc"
    bank.razorpay_fund_account_id = None
    return bank


def _inquiry():
    inquiry = MagicMock()
    inquiry.id = "inq-1"
    return inquiry


@pytest.mark.asyncio
async def test_initiate_payout_dev_mock(monkeypatch):
    from app.core.config import settings

    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    monkeypatch.setattr(settings, "PAYMENT_DEV_MOCK", True)
    monkeypatch.setattr(settings, "RAZORPAY_KEY_ID", "")
    monkeypatch.setattr(settings, "RAZORPAY_KEY_SECRET", "")
    monkeypatch.setattr(settings, "RAZORPAYX_ACCOUNT_NUMBER", "")

    client = RazorpayXClient()

    bank_repo = MagicMock()
    bank_repo.list_for_user = AsyncMock(return_value=[_bank()])
    user_repo = MagicMock()
    inquiry_repo = MagicMock()

    service = SellRazorpayXPayoutService(client, bank_repo, user_repo, inquiry_repo)
    result = await service.initiate_payout(_inquiry(), _user(), Decimal("1500.50"))

    assert result["razorpay_payout_id"].startswith("payout_dev_")
    assert result["payout_status"] == "processed"
    assert result["payment_method"] == "bank_account"
    assert "XXXX1234" in result["payment_destination"]


def test_map_payout_status():
    assert SellRazorpayXPayoutService._map_payout_status("processed") == "processed"
    assert SellRazorpayXPayoutService._map_payout_status("processing") == "processing"
    assert SellRazorpayXPayoutService._map_payout_status("failed") == "failed"
