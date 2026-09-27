import io
from types import SimpleNamespace
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.config import settings
from app.core.exceptions import NotFoundException, ValidationException
from app.services.invoice import generate_invoice_html, generate_invoice_pdf
from app.services.email_service import _snapshot_data, send_invoice_email_async
from app.services.gold_payment import GoldPaymentService


def _dummy_user(
    *,
    user_id: uuid.UUID | None = None,
    email: str = "customer@example.com",
    first_name: str = "John",
    last_name: str = "Doe",
    mobile_number: str = "9876543210",
    is_superuser: bool = False,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email=email,
        first_name=first_name,
        last_name=last_name,
        name=f"{first_name} {last_name}",
        mobile_number=mobile_number,
        is_superuser=is_superuser,
    )


def _dummy_order(
    *,
    user_id: uuid.UUID,
    metal: str = "gold",
    grams: Decimal = Decimal("0.5"),
    rate: Decimal = Decimal("7200.00"),
    status: str = "paid",
) -> SimpleNamespace:
    amount_inr = (grams * rate * Decimal("1.03")).quantize(Decimal("0.01"))
    amount_paise = int(amount_inr * 100)
    metal_val = (amount_inr / Decimal("1.03")).quantize(Decimal("0.01"))
    gst_val = amount_inr - metal_val

    return SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user_id,
        razorpay_order_id="order_dummy_12345",
        razorpay_payment_id="pay_dummy_67890",
        bank_rrn="123456789012",
        payment_method="upi",
        customer_contact="9876543210",
        metal=metal,
        amount_paise=amount_paise,
        grams=grams,
        rate_per_gram=rate,
        gst_percent=Decimal("3.00"),
        metal_value_inr=metal_val,
        gst_amount_inr=gst_val,
        created_at=datetime.now(timezone.utc),
        paid_at=datetime.now(timezone.utc),
        status=status,
    )


def test_generate_invoice_pdf_gold():
    user = _dummy_user()
    order = _dummy_order(user_id=user.id, metal="gold")

    pdf_bytes = generate_invoice_pdf(order, user)
    assert isinstance(pdf_bytes, bytes)
    assert len(pdf_bytes) > 1000
    assert pdf_bytes.startswith(b"%PDF")


def test_generate_invoice_pdf_silver():
    user = _dummy_user()
    order = _dummy_order(user_id=user.id, metal="silver", grams=Decimal("50.0"), rate=Decimal("95.0"))

    pdf_bytes = generate_invoice_pdf(order, user)
    assert isinstance(pdf_bytes, bytes)
    assert len(pdf_bytes) > 1000
    assert pdf_bytes.startswith(b"%PDF")


def test_generate_invoice_html():
    user = _dummy_user(first_name="Alice", last_name="Wonderland")
    order = _dummy_order(user_id=user.id, metal="gold")

    html = generate_invoice_html(order, user)
    assert isinstance(html, str)
    assert "Tax Invoice" in html
    assert "Payment Receipt" in html
    assert "Alice Wonderland" in html
    assert "order_dummy_12345" in html
    assert "pay_dummy_67890" in html
    assert "24K Pure Digital Gold" in html


def test_snapshot_data():
    user = _dummy_user()
    order = _dummy_order(user_id=user.id)

    u_snap, o_snap = _snapshot_data(user, order)
    assert u_snap.email == user.email
    assert u_snap.first_name == user.first_name
    assert o_snap.razorpay_order_id == order.razorpay_order_id
    assert o_snap.metal == "gold"
    assert o_snap.grams == order.grams


@pytest.mark.asyncio
async def test_send_invoice_email_async_success():
    user = _dummy_user()
    order = _dummy_order(user_id=user.id)

    mock_smtp_instance = MagicMock()
    mock_smtp_instance.__enter__.return_value = mock_smtp_instance

    with patch("smtplib.SMTP", return_value=mock_smtp_instance), \
         patch.object(settings, "SMTP_ENABLED", True), \
         patch.object(settings, "SMTP_USER", "test_user"), \
         patch.object(settings, "SMTP_PASSWORD", "test_pass"):
        result = await send_invoice_email_async(user, order)
        assert result is True
        mock_smtp_instance.starttls.assert_called_once()
        mock_smtp_instance.login.assert_called_once_with("test_user", "test_pass")
        mock_smtp_instance.send_message.assert_called_once()


@pytest.mark.asyncio
async def test_send_invoice_email_async_no_email():
    user = _dummy_user(email="")
    order = _dummy_order(user_id=user.id)

    with patch.object(settings, "SMTP_ENABLED", True):
        result = await send_invoice_email_async(user, order)
        assert result is False


@pytest.mark.asyncio
async def test_send_invoice_email_async_disabled():
    user = _dummy_user()
    order = _dummy_order(user_id=user.id)

    with patch.object(settings, "SMTP_ENABLED", False):
        result = await send_invoice_email_async(user, order)
        assert result is False


@pytest.mark.asyncio
async def test_gold_payment_get_invoice_pdf():
    user = _dummy_user()
    order = _dummy_order(user_id=user.id, status="paid")

    mock_payment_repo = AsyncMock()
    mock_payment_repo.get.return_value = order
    mock_user_repo = AsyncMock()
    mock_user_repo.get.return_value = user

    service = GoldPaymentService(
        user_repo=mock_user_repo,
        payment_repo=mock_payment_repo,
        metal_prices=AsyncMock(),
        razorpay=AsyncMock(),
    )

    pdf_bytes, filename = await service.get_order_invoice_pdf(user, order.id)
    assert isinstance(pdf_bytes, bytes)
    assert pdf_bytes.startswith(b"%PDF")
    assert filename.startswith("Invoice_INV-AGS-")
    assert filename.endswith(".pdf")


@pytest.mark.asyncio
async def test_gold_payment_get_invoice_unauthorized():
    user1 = _dummy_user()
    user2 = _dummy_user()
    order = _dummy_order(user_id=user1.id, status="paid")

    mock_payment_repo = AsyncMock()
    mock_payment_repo.get.return_value = order
    mock_user_repo = AsyncMock()

    service = GoldPaymentService(
        user_repo=mock_user_repo,
        payment_repo=mock_payment_repo,
        metal_prices=AsyncMock(),
        razorpay=AsyncMock(),
    )

    # user2 is not an admin and does not own the order
    with pytest.raises(NotFoundException):
        await service.get_order_invoice_pdf(user2, order.id)


@pytest.mark.asyncio
async def test_gold_payment_get_invoice_unpaid():
    user = _dummy_user()
    order = _dummy_order(user_id=user.id, status="created")

    mock_payment_repo = AsyncMock()
    mock_payment_repo.get.return_value = order
    mock_user_repo = AsyncMock()

    service = GoldPaymentService(
        user_repo=mock_user_repo,
        payment_repo=mock_payment_repo,
        metal_prices=AsyncMock(),
        razorpay=AsyncMock(),
    )

    with pytest.raises(ValidationException):
        await service.get_order_invoice_pdf(user, order.id)


@pytest.mark.asyncio
async def test_gold_payment_resend_email():
    user = _dummy_user(email="test@example.com")
    order = _dummy_order(user_id=user.id, status="paid")

    mock_payment_repo = AsyncMock()
    mock_payment_repo.get.return_value = order
    mock_user_repo = AsyncMock()
    mock_user_repo.get.return_value = user

    service = GoldPaymentService(
        user_repo=mock_user_repo,
        payment_repo=mock_payment_repo,
        metal_prices=AsyncMock(),
        razorpay=AsyncMock(),
    )

    with patch("app.services.gold_payment.send_invoice_email_async", new_callable=AsyncMock) as mock_send:
        mock_send.return_value = True
        res = await service.resend_order_invoice_email(user, order.id)
        assert res["status"] == "success"
        assert "test@example.com" in res["message"]
        mock_send.assert_awaited_once()
