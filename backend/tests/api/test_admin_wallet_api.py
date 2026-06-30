import uuid
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_password_hash
from app.models.payment_order import PaymentOrder
from app.models.user import User
from tests.security.conftest import create_user_with_permissions


@pytest.fixture
async def wallet_end_user(test_db: AsyncSession) -> User:
    now = datetime.now(timezone.utc)
    user = User(
        id=uuid.uuid4(),
        email=f"wallet_user_{uuid.uuid4().hex[:8]}@example.com",
        hashed_password=get_password_hash("password123"),
        first_name="Wallet",
        last_name="Customer",
        mobile_number="9876543210",
        mobile_verified=True,
        is_active=True,
        is_deleted=False,
        kyc_status="verified",
        kyc_aadhaar_last4="1234",
        kyc_pan_last4="5678",
        gold_savings_grams=Decimal("1.5000"),
        silver_savings_grams=Decimal("0.2500"),
        gold_invested_inr=Decimal("8500.00"),
        silver_invested_inr=Decimal("250.00"),
        wallet_balance_inr=Decimal("150.00"),
        created_at=now,
        updated_at=now,
    )
    test_db.add(user)
    await test_db.flush()

    order = PaymentOrder(
        id=uuid.uuid4(),
        user_id=user.id,
        razorpay_order_id=f"order_{uuid.uuid4().hex[:20]}",
        razorpay_payment_id=f"pay_{uuid.uuid4().hex[:20]}",
        metal="gold",
        amount_paise=850000,
        grams=Decimal("1.5000"),
        rate_per_gram=Decimal("5666.67"),
        gst_percent=Decimal("3.00"),
        metal_value_inr=Decimal("8252.43"),
        gst_amount_inr=Decimal("247.57"),
        razorpay_fee_inr=Decimal("19.55"),
        merchant_settlement_inr=Decimal("8280.45"),
        status="paid",
        created_at=now,
        paid_at=now,
    )
    test_db.add(order)
    await test_db.flush()
    return user


@pytest.mark.asyncio
async def test_search_wallet_users_requires_permission(
    db_client: AsyncClient, test_db: AsyncSession, wallet_end_user: User
):
    _, headers = await create_user_with_permissions(test_db, ["customer.view"])
    response = await db_client.get(
        "/api/v1/admin/wallets/users",
        params={"search": "Wallet"},
        headers=headers,
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_search_wallet_users_success(
    db_client: AsyncClient, test_db: AsyncSession, wallet_end_user: User
):
    _, headers = await create_user_with_permissions(test_db, ["wallet.view"])
    response = await db_client.get(
        "/api/v1/admin/wallets/users",
        params={"search": "9876543210"},
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1
    assert any(item["id"] == str(wallet_end_user.id) for item in data["items"])
    item = next(i for i in data["items"] if i["id"] == str(wallet_end_user.id))
    assert item["kyc_aadhaar_last4"] == "1234"
    assert item["kyc_pan_last4"] == "5678"


@pytest.mark.asyncio
async def test_get_user_wallet_detail(
    db_client: AsyncClient, test_db: AsyncSession, wallet_end_user: User
):
    _, headers = await create_user_with_permissions(test_db, ["wallet.view"])
    response = await db_client.get(
        f"/api/v1/admin/wallets/users/{wallet_end_user.id}",
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == wallet_end_user.email
    assert data["kyc_aadhaar_last4"] == "1234"
    assert data["wallet"]["gold_balance_grams"] == "1.5000"
    assert Decimal(data["wallet"]["total_inr_invested"]) == Decimal("8750.00")


@pytest.mark.asyncio
async def test_list_user_wallet_transactions(
    db_client: AsyncClient, test_db: AsyncSession, wallet_end_user: User
):
    _, headers = await create_user_with_permissions(test_db, ["wallet.view"])
    response = await db_client.get(
        f"/api/v1/admin/wallets/users/{wallet_end_user.id}/transactions",
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1
    assert any(txn["transaction_type"] == "BUY" for txn in data["items"])


@pytest.mark.asyncio
async def test_recent_wallet_transactions(
    db_client: AsyncClient, test_db: AsyncSession, wallet_end_user: User
):
    _, headers = await create_user_with_permissions(test_db, ["wallet.view"])
    response = await db_client.get(
        "/api/v1/admin/wallets/transactions/recent",
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1
    assert any(txn["user_id"] == str(wallet_end_user.id) for txn in data["items"])


@pytest.mark.asyncio
async def test_wallet_transaction_detail_buy(
    db_client: AsyncClient, test_db: AsyncSession, wallet_end_user: User
):
    from sqlalchemy import select

    result = await test_db.execute(
        select(PaymentOrder).where(PaymentOrder.user_id == wallet_end_user.id)
    )
    order = result.scalars().first()
    assert order is not None

    _, headers = await create_user_with_permissions(test_db, ["wallet.view"])
    response = await db_client.get(
        f"/api/v1/admin/wallets/transactions/buy:{order.id}",
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["transaction_type"] == "BUY"
    assert data["payment_details"]["razorpay_order_id"] == order.razorpay_order_id
    assert data["platform_fee_inr"] is not None
