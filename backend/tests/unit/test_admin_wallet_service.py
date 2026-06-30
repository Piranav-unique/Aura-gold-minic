import uuid
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.user import User
from app.repositories.admin_wallet import AdminWalletRepository
from app.services.admin_wallet import AdminWalletService
from app.core.exceptions import NotFoundException


@pytest.fixture
def wallet_repo():
    return MagicMock(spec=AdminWalletRepository)


@pytest.fixture
def audit_service():
    svc = MagicMock()
    svc.log_action = AsyncMock()
    return svc


@pytest.fixture
def wallet_service(wallet_repo, audit_service):
    return AdminWalletService(wallet_repo, audit_service)


@pytest.mark.asyncio
async def test_get_user_wallet_not_found(wallet_service, wallet_repo):
    wallet_repo.get_wallet_user = AsyncMock(return_value=None)
    with pytest.raises(NotFoundException):
        await wallet_service.get_user_wallet(
            uuid.uuid4(), admin_user_id=uuid.uuid4()
        )


@pytest.mark.asyncio
async def test_get_user_wallet_audits_view(wallet_service, wallet_repo, audit_service):
    now = datetime.now(timezone.utc)
    user = User(
        id=uuid.uuid4(),
        email="u@example.com",
        hashed_password="x",
        first_name="Test",
        last_name="User",
        is_active=True,
        is_deleted=False,
        kyc_status="verified",
        kyc_aadhaar_last4="9999",
        kyc_pan_last4="8888",
        gold_savings_grams=Decimal("1"),
        silver_savings_grams=Decimal("0"),
        gold_invested_inr=Decimal("100"),
        silver_invested_inr=Decimal("0"),
        wallet_balance_inr=Decimal("0"),
        created_at=now,
        updated_at=now,
    )
    wallet_repo.get_wallet_user = AsyncMock(return_value=user)
    wallet_repo.sum_paid_grams = AsyncMock(return_value=Decimal("1"))
    wallet_repo.count_pending_sell_inquiries = AsyncMock(return_value=0)
    wallet_repo.sum_referral_rewards = AsyncMock(
        return_value=(Decimal("0"), Decimal("0"))
    )

    admin_id = uuid.uuid4()
    result = await wallet_service.get_user_wallet(user.id, admin_user_id=admin_id)

    assert result.kyc_aadhaar_last4 == "9999"
    assert result.wallet.gold_balance_grams == Decimal("1")
    audit_service.log_action.assert_awaited_once()
