import uuid
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.exceptions import ValidationException
from app.models.payment_order import PaymentOrder
from app.models.user import User
from app.services.gold_payment import GoldPaymentService


def _make_user(**kwargs) -> User:
    defaults = {
        "id": uuid.uuid4(),
        "email": "customer@gmail.com",
        "first_name": "Test",
        "last_name": "Customer",
        "mobile_number": "9876543210",
        "is_active": True,
        "is_deleted": False,
        "kyc_status": "verified",
        "gold_scheme_status": "active",
        "gold_scheme_target_grams": Decimal("1"),
        "gold_savings_grams": Decimal("0"),
        "silver_savings_grams": Decimal("0"),
        "gold_invested_inr": Decimal("0"),
        "silver_invested_inr": Decimal("0"),
    }
    defaults.update(kwargs)
    return User(**defaults)


def _setup_service():
    user_repo = MagicMock()
    user_repo.db = MagicMock()
    user_repo.db.commit = AsyncMock()
    user_repo.db.refresh = AsyncMock()
    user_repo.get = AsyncMock()

    payment_repo = MagicMock()
    payment_repo.create = AsyncMock()
    payment_repo.get_by_razorpay_order_id = AsyncMock()

    metal_prices = MagicMock()
    quote = MagicMock()
    quote.retail_price = Decimal("15728")
    prices = MagicMock()
    prices.gold = quote
    prices.silver = quote
    metal_prices.get_prices = AsyncMock(return_value=prices)

    razorpay = MagicMock()
    razorpay.use_dev_mock = False
    razorpay.key_id = "rzp_test_live_key"
    razorpay.create_order = AsyncMock(
        return_value={"id": f"order_{uuid.uuid4().hex[:16]}"}
    )
    razorpay.verify_payment_signature = MagicMock(return_value=True)

    digital_inventory = MagicMock()
    digital_inventory.ensure_available = AsyncMock()
    digital_inventory.consume_for_paid_order = AsyncMock()
    digital_inventory.notify_metal_status = AsyncMock()

    service = GoldPaymentService(
        user_repo=user_repo,
        payment_repo=payment_repo,
        metal_prices=metal_prices,
        razorpay=razorpay,
        digital_inventory_service=digital_inventory,
    )
    return service, user_repo, payment_repo, razorpay


# ==============================================================================
# 1. MODE A: Amount-based Purchases (Customer enters INR amount)
# Exact entered amount must be charged to Razorpay in paise.
# ==============================================================================

@pytest.mark.asyncio
async def test_mode_a_1_rupee():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    response = await service.create_buy_order(
        user,
        metal="silver",
        purchase_mode="amount",
        amount_inr=Decimal("1.00"),
    )

    # 1. Authoritative exact amount
    assert response.amount_inr == Decimal("1.00")
    assert response.amount_paise == 100
    assert response.purchase_mode == "amount"

    # 2. Razorpay received exact paise
    razorpay.create_order.assert_called_once()
    call_kwargs = razorpay.create_order.call_args.kwargs
    assert call_kwargs["amount_paise"] == 100
    assert call_kwargs["notes"]["purchase_mode"] == "amount"
    assert call_kwargs["notes"]["amount_inr"] == "1.00"

    # 3. High precision (6 decimal places / microgram) grams calculated
    # Metal value = 0.97, rate = 15728 => 0.97 / 15728 = 0.000062 g
    assert response.grams == Decimal("0.000062")

    # 4. DB record stores exact amount, mode, and grams
    payment_repo.create.assert_called_once()
    db_payload = payment_repo.create.call_args[0][0]
    assert db_payload["amount_paise"] == 100
    assert db_payload["purchase_mode"] == "amount"
    assert db_payload["grams"] == Decimal("0.000062")
    assert db_payload["metal_value_inr"] == Decimal("0.97")
    assert db_payload["gst_amount_inr"] == Decimal("0.03")


@pytest.mark.asyncio
async def test_mode_a_5_rupees():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    response = await service.create_buy_order(
        user,
        metal="silver",
        purchase_mode="amount",
        amount_inr=Decimal("5.00"),
    )

    # Exact ₹5.00 -> 500 paise, NOT ₹4.85!
    assert response.amount_inr == Decimal("5.00")
    assert response.amount_paise == 500
    assert razorpay.create_order.call_args.kwargs["amount_paise"] == 500
    # Metal value = 4.85, rate = 15728 => 4.85 / 15728 = 0.000308 g
    assert response.grams == Decimal("0.000308")


@pytest.mark.asyncio
async def test_mode_a_10_rupees():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    response = await service.create_buy_order(
        user,
        metal="silver",
        purchase_mode="amount",
        amount_inr=Decimal("10.00"),
    )

    assert response.amount_inr == Decimal("10.00")
    assert response.amount_paise == 1000
    assert razorpay.create_order.call_args.kwargs["amount_paise"] == 1000
    # Metal value = 9.71, rate = 15728 => 9.71 / 15728 = 0.000617 g
    assert response.grams == Decimal("0.000617")


@pytest.mark.asyncio
async def test_mode_a_100_rupees():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    response = await service.create_buy_order(
        user,
        metal="gold",
        purchase_mode="amount",
        amount_inr=Decimal("100.00"),
    )

    # Exact ₹100.00 -> 10000 paise, NOT ₹99.99!
    assert response.amount_inr == Decimal("100.00")
    assert response.amount_paise == 10000
    assert razorpay.create_order.call_args.kwargs["amount_paise"] == 10000
    # Metal value = 97.09, rate = 15728 => 97.09 / 15728 = 0.006173 g
    assert response.grams == Decimal("0.006173")


@pytest.mark.asyncio
async def test_mode_a_500_rupees():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    response = await service.create_buy_order(
        user,
        metal="gold",
        purchase_mode="amount",
        amount_inr=Decimal("500.00"),
    )

    assert response.amount_inr == Decimal("500.00")
    assert response.amount_paise == 50000
    assert razorpay.create_order.call_args.kwargs["amount_paise"] == 50000
    # Metal value = 485.44, rate = 15728 => 485.44 / 15728 = 0.030865 g
    assert response.grams == Decimal("0.030865")


# ==============================================================================
# 2. MODE B: Grams-based Purchases (Customer enters weight)
# Exact entered weight is authoritative; payable amount is metal_value + 3% GST.
# ==============================================================================

@pytest.mark.asyncio
async def test_mode_b_0_001_grams():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    response = await service.create_buy_order(
        user,
        metal="silver",
        purchase_mode="grams",
        grams=Decimal("0.001"),
    )

    # 1. Exact weight preserved
    assert response.grams == Decimal("0.001000")
    assert response.purchase_mode == "grams"

    # 2. Metal value = 0.001 * 15728 = 15.73
    # GST (3%) = 15.73 * 0.03 = 0.47
    # Total payable = 16.20 INR -> 1620 paise
    assert response.amount_inr == Decimal("16.20")
    assert response.amount_paise == 1620
    assert razorpay.create_order.call_args.kwargs["amount_paise"] == 1620
    assert razorpay.create_order.call_args.kwargs["notes"]["purchase_mode"] == "grams"


@pytest.mark.asyncio
async def test_mode_b_1_gram():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    response = await service.create_buy_order(
        user,
        metal="gold",
        purchase_mode="grams",
        grams=Decimal("1.0"),
    )

    # 1. Exact 1.0 g preserved
    assert response.grams == Decimal("1.000000")
    # 2. Metal value = 1.0 * 15728 = 15728.00
    # GST (3%) = 15728 * 0.03 = 471.84
    # Total payable = 16199.84 INR -> 1619984 paise
    assert response.amount_inr == Decimal("16199.84")
    assert response.amount_paise == 1619984
    assert razorpay.create_order.call_args.kwargs["amount_paise"] == 1619984


# ==============================================================================
# 3. Mode Independence: Amount Mode Ignores Extraneous Grams
# ==============================================================================

@pytest.mark.asyncio
async def test_amount_mode_strictly_authoritative_over_grams():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    # Even if an erroneous rounded grams value is passed alongside amount,
    # purchase_mode="amount" strictly uses amount_inr.
    response = await service.create_buy_order(
        user,
        metal="gold",
        purchase_mode="amount",
        amount_inr=Decimal("100.00"),
        grams=Decimal("0.006"),  # Misleading rounded input
    )

    assert response.purchase_mode == "amount"
    assert response.amount_inr == Decimal("100.00")
    assert response.amount_paise == 10000
    assert response.grams == Decimal("0.006173")


# ==============================================================================
# 4. Payment Verification & Wallet Credit
# ==============================================================================

@pytest.mark.asyncio
async def test_verify_payment_credits_gold_and_invested_inr():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    # Create mock payment order in DB
    order_id = uuid.uuid4()
    rz_order_id = "order_rzp_123456"
    mock_order = PaymentOrder(
        id=order_id,
        user_id=user.id,
        razorpay_order_id=rz_order_id,
        metal="gold",
        purchase_mode="amount",
        amount_paise=10000,  # ₹100.00
        grams=Decimal("0.006173"),
        rate_per_gram=Decimal("15728"),
        gst_percent=Decimal("3"),
        metal_value_inr=Decimal("97.09"),
        gst_amount_inr=Decimal("2.91"),
        status="created",
    )
    payment_repo.get_by_razorpay_order_id = AsyncMock(return_value=mock_order)

    with patch("app.services.gold_payment.send_invoice_email_async", new=AsyncMock()):
        result = await service.verify_payment(
            user,
            razorpay_order_id=rz_order_id,
            razorpay_payment_id="pay_123456",
            razorpay_signature="sig_valid",
        )

    # Status updated to paid
    assert mock_order.status == "paid"
    assert mock_order.razorpay_payment_id == "pay_123456"

    # User balance accurately credited
    assert user.gold_savings_grams == Decimal("0.006173")
    assert user.gold_invested_inr == Decimal("100.00")

    # DB committed
    user_repo.db.commit.assert_called()


# ==============================================================================
# 5. Idempotency: Duplicate Verify Call Does Not Double Credit
# ==============================================================================

@pytest.mark.asyncio
async def test_duplicate_verify_payment_idempotent():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user(
        gold_savings_grams=Decimal("0.006173"),
        gold_invested_inr=Decimal("100.00"),
    )

    mock_order = PaymentOrder(
        id=uuid.uuid4(),
        user_id=user.id,
        razorpay_order_id="order_rzp_already_paid",
        metal="gold",
        purchase_mode="amount",
        amount_paise=10000,
        grams=Decimal("0.006173"),
        rate_per_gram=Decimal("15728"),
        status="paid",  # already marked paid
        razorpay_payment_id="pay_already_recorded",
    )
    payment_repo.get_by_razorpay_order_id = AsyncMock(return_value=mock_order)
    user_repo.get = AsyncMock(return_value=user)

    # Call verify on already paid order
    result = await service.verify_payment(
        user,
        razorpay_order_id="order_rzp_already_paid",
        razorpay_payment_id="pay_already_recorded",
        razorpay_signature="sig_valid",
    )

    # Balances must NOT be added a second time
    assert user.gold_savings_grams == Decimal("0.006173")
    assert user.gold_invested_inr == Decimal("100.00")


# ==============================================================================
# 6. Payment Failure: No Gold Credited
# ==============================================================================

@pytest.mark.asyncio
async def test_payment_failure_marks_order_failed_no_credit():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    mock_order = PaymentOrder(
        id=uuid.uuid4(),
        user_id=user.id,
        razorpay_order_id="order_rzp_fail",
        metal="gold",
        purchase_mode="amount",
        amount_paise=10000,
        grams=Decimal("0.006173"),
        rate_per_gram=Decimal("15728"),
        status="created",
    )
    payment_repo.get_by_razorpay_order_id = AsyncMock(return_value=mock_order)
    # Signature verification fails
    razorpay.verify_payment_signature = MagicMock(return_value=False)

    with pytest.raises(ValidationException, match="Payment verification failed"):
        await service.verify_payment(
            user,
            razorpay_order_id="order_rzp_fail",
            razorpay_payment_id="pay_bad",
            razorpay_signature="sig_bad",
        )

    # Order marked failed
    assert mock_order.status == "failed"
    # Wallet remains 0
    assert user.gold_savings_grams == Decimal("0")
    assert user.gold_invested_inr == Decimal("0")


# ==============================================================================
# 7. Validations: Minimum Purchase & Profile Constraints
# ==============================================================================

@pytest.mark.asyncio
async def test_minimum_amount_under_1_rupee_rejected():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user()

    with pytest.raises(ValidationException, match="Minimum purchase amount is ₹1"):
        await service.create_buy_order(
            user,
            metal="silver",
            purchase_mode="amount",
            amount_inr=Decimal("0.50"),
        )


@pytest.mark.asyncio
async def test_placeholder_email_rejected_for_invoice_compliance():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user(email="9876543210@mobile.agsgold.com")

    with pytest.raises(ValidationException, match="Please add your personal email"):
        await service.create_buy_order(
            user,
            metal="gold",
            purchase_mode="amount",
            amount_inr=Decimal("100.00"),
        )


@pytest.mark.asyncio
async def test_gold_scheme_10g_enforces_2000_minimum():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user(gold_scheme_target_grams=Decimal("10"), gold_invested_inr=Decimal("2000"))

    # Less than ₹2000 rejected
    with pytest.raises(ValidationException, match="Minimum deposit for your 10g scheme is ₹2,000"):
        await service.create_buy_order(
            user,
            metal="gold",
            purchase_mode="amount",
            amount_inr=Decimal("1999.00"),
        )

    # ₹2000 accepted
    response = await service.create_buy_order(
        user,
        metal="gold",
        purchase_mode="amount",
        amount_inr=Decimal("2000.00"),
    )
    assert response.amount_inr == Decimal("2000.00")
    assert response.amount_paise == 200000


@pytest.mark.asyncio
async def test_gold_scheme_5g_enforces_1000_minimum():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user(gold_scheme_target_grams=Decimal("5"), gold_invested_inr=Decimal("1000"))

    # Less than ₹1000 rejected
    with pytest.raises(ValidationException, match="Minimum deposit for your 5g scheme is ₹1,000"):
        await service.create_buy_order(
            user,
            metal="gold",
            purchase_mode="amount",
            amount_inr=Decimal("999.00"),
        )

    # ₹1000 accepted
    response = await service.create_buy_order(
        user,
        metal="gold",
        purchase_mode="amount",
        amount_inr=Decimal("1000.00"),
    )
    assert response.amount_inr == Decimal("1000.00")
    assert response.amount_paise == 100000


@pytest.mark.asyncio
async def test_gold_scheme_1g_enforces_50_minimum():
    service, user_repo, payment_repo, razorpay = _setup_service()
    user = _make_user(gold_scheme_target_grams=Decimal("1"), gold_invested_inr=Decimal("100"))

    # Less than ₹50 rejected
    with pytest.raises(ValidationException, match="Minimum deposit for your 1g scheme is ₹50"):
        await service.create_buy_order(
            user,
            metal="gold",
            purchase_mode="amount",
            amount_inr=Decimal("49.00"),
        )

    # ₹50 accepted
    response = await service.create_buy_order(
        user,
        metal="gold",
        purchase_mode="amount",
        amount_inr=Decimal("50.00"),
    )
    assert response.amount_inr == Decimal("50.00")
    assert response.amount_paise == 5000


@pytest.mark.asyncio
async def test_gold_scheme_1g_referred_first_deposit_enforces_100():
    service, user_repo, payment_repo, razorpay = _setup_service()
    referrer_id = uuid.uuid4()
    user = _make_user(
        gold_scheme_target_grams=Decimal("1"),
        gold_invested_inr=Decimal("0"),
        referred_by_user_id=referrer_id,
    )

    # For a referred user making first deposit, ₹50 is rejected, must be at least ₹100
    with pytest.raises(ValidationException, match="Minimum deposit for your 1g scheme is ₹100"):
        await service.create_buy_order(
            user,
            metal="gold",
            purchase_mode="amount",
            amount_inr=Decimal("50.00"),
        )

    # ₹100 accepted
    response = await service.create_buy_order(
        user,
        metal="gold",
        purchase_mode="amount",
        amount_inr=Decimal("100.00"),
    )
    assert response.amount_inr == Decimal("100.00")
    assert response.amount_paise == 10000
