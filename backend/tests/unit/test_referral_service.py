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
        gold_invested_inr=Decimal("0"),
    )
    base.update(kwargs)
    return User(**base)


@pytest.mark.asyncio
async def test_maybe_credit_referrer_for_matching_scheme():
    referrer = _user(referral_code="ABCD1234", gold_savings_grams=Decimal("0"))
    referee = _user(
        referred_by_user_id=referrer.id,
        referral_scheme_grams=Decimal("5"),
        gold_invested_inr=Decimal("1000"),
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
        referee, Decimal("5"), live_gold_rate=Decimal("7000"), purchase_amount_inr=Decimal("1000")
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
        gold_invested_inr=Decimal("1000"),
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
    # At live rate ₹7,200/g: 550 / 7200 = 0.0764 g pure digital gold; purchase = ₹2,000 meets threshold
    credited = await service.maybe_credit_referrer_on_purchase(
        referee=referee,
        live_gold_rate=Decimal("7200"),
        purchase_amount_inr=Decimal("2000"),
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
        gold_invested_inr=Decimal("100"),
    )

    user_repo = MagicMock()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=referrer)

    reward_repo = MagicMock()
    reward_repo.get_for_pair = AsyncMock(return_value=MagicMock())  # already exists

    service = ReferralService(user_repo, reward_repo)
    credited = await service.maybe_credit_referrer_on_purchase(
        referee=referee,
        live_gold_rate=Decimal("7000"),
        purchase_amount_inr=Decimal("100"),
    )

    assert credited is None
    reward_repo.create.assert_not_called()


@pytest.mark.asyncio
async def test_referee_below_min_purchase_blocks_reward_1g():
    referrer = _user(referral_code="GOLD1000")
    referee = _user(
        referred_by_user_id=referrer.id,
        referral_scheme_grams=Decimal("1"),
        gold_invested_inr=Decimal("0"),
    )

    user_repo = MagicMock()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=referrer)
    reward_repo = MagicMock()
    reward_repo.get_for_pair = AsyncMock(return_value=None)
    reward_repo.create = AsyncMock()

    service = ReferralService(user_repo, reward_repo)
    # Referee only paid ₹50 (below ₹100 threshold for 1g scheme)
    credited = await service.maybe_credit_referrer_on_purchase(
        referee=referee,
        live_gold_rate=Decimal("7000"),
        purchase_amount_inr=Decimal("50"),
    )

    assert credited is None
    reward_repo.create.assert_not_called()


@pytest.mark.asyncio
async def test_referee_meets_min_purchase_credits_reward_1g():
    referrer = _user(referral_code="GOLD1000")
    referee = _user(
        referred_by_user_id=referrer.id,
        referral_scheme_grams=Decimal("1"),
    )

    user_repo = MagicMock()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=referrer)
    user_repo.db = MagicMock()
    user_repo.db.commit = AsyncMock()

    reward_repo = MagicMock()
    reward_repo.get_for_pair = AsyncMock(return_value=None)
    reward_repo.create = AsyncMock()

    service = ReferralService(user_repo, reward_repo)
    # Referee paid ₹100 (qualifies for 1g scheme) -> awards ₹150 coupon reward
    credited = await service.maybe_credit_referrer_on_purchase(
        referee=referee,
        live_gold_rate=Decimal("7000"),
        purchase_amount_inr=Decimal("100"),
    )

    assert credited == Decimal("150")
    assert referrer.wallet_balance_inr == Decimal("150")
    reward_repo.create.assert_awaited_once()


@pytest.mark.asyncio
async def test_referee_scheme_5g_blocks_below_1000_and_credits_at_1000():
    referrer = _user(referral_code="GOLD1000")
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

    # 1. Payment of ₹800 is below ₹1000 threshold -> Blocked
    credited = await service.maybe_credit_referrer_on_purchase(
        referee=referee,
        live_gold_rate=Decimal("7000"),
        purchase_amount_inr=Decimal("800"),
    )
    assert credited is None
    reward_repo.create.assert_not_called()

    # 2. Payment of ₹1000 meets threshold -> Credits ₹350
    credited = await service.maybe_credit_referrer_on_purchase(
        referee=referee,
        live_gold_rate=Decimal("7000"),
        purchase_amount_inr=Decimal("1000"),
    )
    assert credited == Decimal("350")
    assert referrer.wallet_balance_inr == Decimal("350")
    reward_repo.create.assert_awaited_once()


@pytest.mark.asyncio
async def test_referee_scheme_10g_blocks_below_2000_and_credits_at_2000():
    referrer = _user(referral_code="GOLD1000")
    referee = _user(
        referred_by_user_id=referrer.id,
        referral_scheme_grams=Decimal("10"),
    )

    user_repo = MagicMock()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=referrer)
    user_repo.db = MagicMock()
    user_repo.db.commit = AsyncMock()

    reward_repo = MagicMock()
    reward_repo.get_for_pair = AsyncMock(return_value=None)
    reward_repo.create = AsyncMock()

    service = ReferralService(user_repo, reward_repo)

    # 1. Payment of ₹1500 is below ₹2000 threshold -> Blocked
    credited = await service.maybe_credit_referrer_on_purchase(
        referee=referee,
        live_gold_rate=Decimal("7000"),
        purchase_amount_inr=Decimal("1500"),
    )
    assert credited is None
    reward_repo.create.assert_not_called()

    # 2. Payment of ₹2000 meets threshold -> Credits ₹550
    credited = await service.maybe_credit_referrer_on_purchase(
        referee=referee,
        live_gold_rate=Decimal("7000"),
        purchase_amount_inr=Decimal("2000"),
    )
    assert credited == Decimal("550")
    assert referrer.wallet_balance_inr == Decimal("550")
    reward_repo.create.assert_awaited_once()


@pytest.mark.asyncio
async def test_referral_summary_contains_min_purchase_inr():
    user = _user(referral_code="MYREFCODE")
    user_repo = MagicMock()
    user_repo.get_by_referral_code = AsyncMock(return_value=None)
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=None)

    reward_repo = MagicMock()
    reward_repo.count_and_sum_for_referrer = AsyncMock(return_value=(0, Decimal("0")))
    reward_repo.list_for_referrer = AsyncMock(return_value=[])

    service = ReferralService(user_repo, reward_repo)
    summary = await service.get_summary(user)

    assert len(summary.tiers) == 3
    # Check 1g tier
    assert summary.tiers[0].scheme_grams == 1
    assert summary.tiers[0].reward_inr == Decimal("150")
    assert summary.tiers[0].min_purchase_inr == Decimal("100")
    # Check 5g tier
    assert summary.tiers[1].scheme_grams == 5
    assert summary.tiers[1].reward_inr == Decimal("350")
    assert summary.tiers[1].min_purchase_inr == Decimal("1000")
    # Check 10g tier
    assert summary.tiers[2].scheme_grams == 10
    assert summary.tiers[2].reward_inr == Decimal("550")
    assert summary.tiers[2].min_purchase_inr == Decimal("2000")
