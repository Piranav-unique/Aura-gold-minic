import uuid
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_password_hash
from app.models.digital_metal_inventory import (
    DigitalMetalInventory,
    DigitalMetalInventoryMovement,
)
from app.models.payment_order import PaymentOrder
from app.models.user import User
from app.repositories.digital_metal_inventory import (
    DigitalMetalInventoryMovementRepository,
    DigitalMetalInventoryRepository,
)
from app.repositories.payment_order import PaymentOrderRepository
from app.repositories.user import UserRepository
from app.services.digital_metal_inventory import (
    DigitalMetalInventoryService,
    INSUFFICIENT_STOCK_MESSAGE,
)
from app.services.gold_payment import GoldPaymentService
from app.services.metal_prices import MetalPriceService
from app.services.razorpay_client import RazorpayClient
from app.core.exceptions import ValidationException


async def _buy_ready_user(test_db: AsyncSession) -> User:
    now = datetime.now(timezone.utc)
    user = User(
        id=uuid.uuid4(),
        email=f"buyer_{uuid.uuid4().hex[:8]}@example.com",
        hashed_password=get_password_hash("password123"),
        first_name="Buyer",
        last_name="Test",
        mobile_number="9876501234",
        mobile_verified=True,
        is_active=True,
        is_deleted=False,
        kyc_status="verified",
        gold_scheme_status="active",
        gold_scheme_target_grams=Decimal("10"),
        gold_savings_grams=Decimal("0"),
        silver_savings_grams=Decimal("0"),
        created_at=now,
        updated_at=now,
    )
    test_db.add(user)
    await test_db.flush()
    return user


async def _set_gold_available(test_db: AsyncSession, grams: Decimal) -> DigitalMetalInventory:
    result = await test_db.execute(
        select(DigitalMetalInventory).where(
            DigitalMetalInventory.metal_type == "gold"
        )
    )
    row = result.scalars().first()
    assert row is not None
    row.total_weight_grams = grams
    row.used_weight_grams = Decimal("0")
    await test_db.flush()
    return row


def _build_payment_service(test_db: AsyncSession) -> GoldPaymentService:
    inventory_service = DigitalMetalInventoryService(
        DigitalMetalInventoryRepository(test_db),
        DigitalMetalInventoryMovementRepository(test_db),
    )
    metal_prices = MagicMock(spec=MetalPriceService)
    quote = MagicMock()
    quote.retail_price = Decimal("6000")
    prices = MagicMock()
    prices.gold = quote
    prices.silver = quote
    metal_prices.get_prices = AsyncMock(return_value=prices)

    razorpay = MagicMock(spec=RazorpayClient)
    razorpay.use_dev_mock = True
    razorpay.key_id = RazorpayClient.DEV_MOCK_KEY_ID

    return GoldPaymentService(
        UserRepository(test_db),
        PaymentOrderRepository(test_db),
        metal_prices,
        razorpay,
        inventory_service,
    )


@pytest.mark.asyncio
async def test_create_buy_order_blocked_when_insufficient_stock(
    test_db: AsyncSession,
):
    await _set_gold_available(test_db, Decimal("1"))
    user = await _buy_ready_user(test_db)
    service = _build_payment_service(test_db)

    with pytest.raises(ValidationException, match=INSUFFICIENT_STOCK_MESSAGE):
        await service.create_buy_order(user, metal="gold", grams=Decimal("2"))


@pytest.mark.asyncio
async def test_verify_payment_reduces_inventory(test_db: AsyncSession):
    await _set_gold_available(test_db, Decimal("10"))
    user = await _buy_ready_user(test_db)
    service = _build_payment_service(test_db)

    order = await service.create_buy_order(user, metal="gold", grams=Decimal("1"))
    result = await service.verify_payment(
        user,
        razorpay_order_id=order.order_id,
        razorpay_payment_id="pay_dev_mock",
        razorpay_signature="dev_mock",
    )
    assert result.status == "paid"

    inv = await test_db.execute(
        select(DigitalMetalInventory).where(
            DigitalMetalInventory.metal_type == "gold"
        )
    )
    row = inv.scalars().first()
    assert row is not None
    assert Decimal(str(row.used_weight_grams)) == Decimal("1")

    movements = await test_db.execute(
        select(DigitalMetalInventoryMovement).where(
            DigitalMetalInventoryMovement.movement_type == "purchase_debit"
        )
    )
    assert movements.scalars().first() is not None


@pytest.mark.asyncio
async def test_sync_payment_marks_captured_razorpay_payment(test_db: AsyncSession):
    await _set_gold_available(test_db, Decimal("10"))
    user = await _buy_ready_user(test_db)
    service = _build_payment_service(test_db)

    order = await service.create_buy_order(user, metal="gold", grams=Decimal("1"))

    live_order_id = f"order_live_{uuid.uuid4().hex[:24]}"
    payment_order = await test_db.execute(
        select(PaymentOrder).where(PaymentOrder.razorpay_order_id == order.order_id)
    )
    po = payment_order.scalars().first()
    assert po is not None
    po.razorpay_order_id = live_order_id
    await test_db.flush()

    razorpay = service.razorpay
    razorpay.use_dev_mock = False
    razorpay.is_configured = True
    razorpay.fetch_order_payments = AsyncMock(
        return_value=[{"id": "pay_live_1", "status": "captured"}]
    )

    result = await service.sync_payment(user, razorpay_order_id=live_order_id)

    assert result.status == "paid"
    assert result.grams_purchased == Decimal("1")

    payment_order = await test_db.execute(
        select(PaymentOrder).where(PaymentOrder.razorpay_order_id == live_order_id)
    )
    po = payment_order.scalars().first()
    assert po is not None
    assert po.status == "paid"
    assert po.razorpay_payment_id == "pay_live_1"


@pytest.mark.asyncio
async def test_sync_payment_returns_pending_without_capture(test_db: AsyncSession):
    await _set_gold_available(test_db, Decimal("10"))
    user = await _buy_ready_user(test_db)
    service = _build_payment_service(test_db)

    order = await service.create_buy_order(user, metal="gold", grams=Decimal("1"))

    live_order_id = f"order_live_{uuid.uuid4().hex[:24]}"
    payment_order = await test_db.execute(
        select(PaymentOrder).where(PaymentOrder.razorpay_order_id == order.order_id)
    )
    po = payment_order.scalars().first()
    assert po is not None
    po.razorpay_order_id = live_order_id
    await test_db.flush()

    razorpay = service.razorpay
    razorpay.use_dev_mock = False
    razorpay.is_configured = True
    razorpay.fetch_order_payments = AsyncMock(return_value=[])

    result = await service.sync_payment(user, razorpay_order_id=live_order_id)

    assert result.status == "pending"


@pytest.mark.asyncio
async def test_failed_verify_does_not_reduce_inventory(test_db: AsyncSession):
    await _set_gold_available(test_db, Decimal("10"))
    user = await _buy_ready_user(test_db)
    service = _build_payment_service(test_db)

    order = await service.create_buy_order(user, metal="gold", grams=Decimal("1"))

    razorpay = service.razorpay
    razorpay.use_dev_mock = False
    razorpay.verify_payment_signature = MagicMock(return_value=False)

    with pytest.raises(ValidationException, match="Payment verification failed"):
        await service.verify_payment(
            user,
            razorpay_order_id=order.order_id,
            razorpay_payment_id="pay_bad",
            razorpay_signature="invalid",
        )

    inv = await test_db.execute(
        select(DigitalMetalInventory).where(
            DigitalMetalInventory.metal_type == "gold"
        )
    )
    row = inv.scalars().first()
    assert row is not None
    assert Decimal(str(row.used_weight_grams)) == Decimal("0")

    payment_order = await test_db.execute(
        select(PaymentOrder).where(PaymentOrder.razorpay_order_id == order.order_id)
    )
    po = payment_order.scalars().first()
    assert po is not None
    assert po.status == "failed"
