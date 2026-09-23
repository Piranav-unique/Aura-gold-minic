import uuid
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.user import User
from app.services.referral import ReferralService


def _user(**kwargs) -> User:
    base = dict(
        id=uuid.uuid4(),
        email="user@test.com",
        hashed_password="x",
        first_name="Test",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        mobile_verified=True,
        wallet_balance_inr=Decimal("0"),
    )
    base.update(kwargs)
    return User(**base)


@pytest.mark.asyncio
async def test_maybe_credit_referrer_for_matching_scheme():
    referrer = _user(referral_code="ABCD1234", gold_savings_grams=Decimal("0"))
    referee = _user(
        referred_by_user_id=referrer.id,
        referral_scheme_grams=Decimal("5"),
    )

    user_repo = MagicMock()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=referrer)
    user_repo.db = MagicMock()
    user_repo.db.commit = AsyncMock()

    reward_repo = MagicMock()
    reward_repo.get_for_pair = AsyncMock(return_value=None)
    reward_repo.create = AsyncMock()

    service = ReferralService(user_repo, reward_repo)
    credited = await service.maybe_credit_referrer(
        referee, Decimal("5"), live_gold_rate=Decimal("7000")
    )

    assert credited == Decimal("350")
    assert referrer.wallet_balance_inr == Decimal("350")
    assert referrer.gold_savings_grams == Decimal("0.0500")
    assert referrer.gold_invested_inr == Decimal("350")
    reward_repo.create.assert_awaited_once()


@pytest.mark.asyncio
async def test_maybe_credit_referrer_skips_mismatched_scheme():
    referrer = _user(referral_code="ABCD1234")
    referee = _user(
        referred_by_user_id=referrer.id,
        referral_scheme_grams=Decimal("5"),
    )

    user_repo = MagicMock()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=referrer)
    reward_repo = MagicMock()
    reward_repo.get_for_pair = AsyncMock(return_value=None)

    service = ReferralService(user_repo, reward_repo)
    credited = await service.maybe_credit_referrer(referee, Decimal("1"))

    assert credited is None
    reward_repo.create.assert_not_called()


@pytest.mark.asyncio
async def test_maybe_credit_referrer_on_purchase_awards_digital_gold():
    referrer = _user(referral_code="GOLD1000", gold_savings_grams=Decimal("0.1000"))
    referee = _user(
        referred_by_user_id=referrer.id,
        referral_scheme_grams=Decimal("10"),
        gold_scheme_target_grams=Decimal("10"),
    )

    user_repo = MagicMock()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=referrer)
    user_repo.db = MagicMock()
    user_repo.db.commit = AsyncMock()

    reward_repo = MagicMock()
    reward_repo.get_for_pair = AsyncMock(return_value=None)
    reward_repo.create = AsyncMock()

    service = ReferralService(user_repo, reward_repo)
    # At live rate ₹7,200/g: 550 / 7200 = 0.0764 g pure digital gold
    credited = await service.maybe_credit_referrer_on_purchase(
        referee=referee,
        live_gold_rate=Decimal("7200"),
    )

    assert credited == Decimal("550")
    assert referrer.wallet_balance_inr == Decimal("550")
    assert referrer.gold_invested_inr == Decimal("550")
    assert referrer.gold_savings_grams == Decimal("0.1764")  # 0.1000 + 0.0764
    reward_repo.create.assert_awaited_once()


@pytest.mark.asyncio
async def test_maybe_credit_referrer_on_purchase_blocks_duplicate_reward():
    referrer = _user(referral_code="GOLD1000")
    referee = _user(
        referred_by_user_id=referrer.id,
        referral_scheme_grams=Decimal("1"),
    )

    user_repo = MagicMock()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=referrer)

    reward_repo = MagicMock()
    reward_repo.get_for_pair = AsyncMock(return_value=MagicMock())  # already exists

    service = ReferralService(user_repo, reward_repo)
    credited = await service.maybe_credit_referrer_on_purchase(
        referee=referee,
        live_gold_rate=Decimal("7000"),
    )

    assert credited is None
    reward_repo.create.assert_not_called()

