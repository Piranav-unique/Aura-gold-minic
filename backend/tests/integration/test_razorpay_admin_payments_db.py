"""Admin live Razorpay payments go through the backend, never the app."""

import pytest

from app.api.dependencies import get_razorpay_client
from app.core.config import settings
from app.main import app

URL = f"{settings.API_V1_STR}/payments/admin/razorpay-payments"


class _FakeRazorpay:
    def __init__(self):
        self.requested = None

    async def list_payments(self, count: int = 100):
        self.requested = count
        return [{"id": "pay_1", "amount": 10000, "status": "captured"}]


@pytest.fixture
def fake_razorpay():
    fake = _FakeRazorpay()
    app.dependency_overrides[get_razorpay_client] = lambda: fake
    yield fake
    app.dependency_overrides.pop(get_razorpay_client, None)


@pytest.mark.asyncio
async def test_admin_gets_live_payments(db_client, admin_user, fake_razorpay):
    _, headers = admin_user
    resp = await db_client.get(URL, params={"count": 50}, headers=headers)
    assert resp.status_code == 200, resp.text
    assert resp.json() == {"items": [{"id": "pay_1", "amount": 10000, "status": "captured"}]}
    assert fake_razorpay.requested == 50


@pytest.mark.asyncio
async def test_customer_cannot_read_live_payments(db_client, authenticated_user, fake_razorpay):
    _, headers = authenticated_user
    resp = await db_client.get(URL, headers=headers)
    assert resp.status_code == 403, resp.text
    assert fake_razorpay.requested is None


@pytest.mark.asyncio
async def test_anonymous_cannot_read_live_payments(db_client, fake_razorpay):
    resp = await db_client.get(URL)
    assert resp.status_code == 401, resp.text
