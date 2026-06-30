from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.exceptions import ValidationException
from app.models.user import User
from app.services.gold_scheme import GoldSchemeService


def _user(**kwargs) -> User:
    user = User(
        email="u@test.com",
        hashed_password="x",
        kyc_status="verified",
        gold_savings_grams=Decimal("0"),
        gold_scheme_status="not_selected",
    )
    for key, value in kwargs.items():
        setattr(user, key, value)
    return user


@pytest.mark.asyncio
async def test_select_scheme_starts_active():
    user = _user()
    repo = MagicMock()
    repo.db = AsyncMock()
    service = GoldSchemeService(repo)

    result = await service.select_scheme(user, target_grams=Decimal("5"))

    assert user.gold_scheme_status == "active"
    assert user.gold_scheme_target_grams == Decimal("5")
    assert result.status == "active"
    assert result.can_sell is False


@pytest.mark.asyncio
async def test_select_scheme_rejects_duplicate():
    user = _user(gold_scheme_status="active", gold_scheme_target_grams=Decimal("1"))
    repo = MagicMock()
    service = GoldSchemeService(repo)

    with pytest.raises(ValidationException):
        await service.select_scheme(user, target_grams=Decimal("5"))


def test_sync_completes_scheme_when_target_reached():
    user = _user(
        gold_scheme_status="active",
        gold_scheme_target_grams=Decimal("1"),
        gold_savings_grams=Decimal("0.5"),
    )
    user.gold_savings_grams = Decimal("1")
    GoldSchemeService.sync_after_gold_purchase(user)
    assert user.gold_scheme_status == "completed"


def test_can_sell_when_user_has_gold_holdings():
    no_gold = _user(gold_scheme_status="active", gold_scheme_target_grams=Decimal("10"))
    with_gold_active = _user(
        gold_scheme_status="active",
        gold_scheme_target_grams=Decimal("10"),
        gold_savings_grams=Decimal("0.5"),
    )
    completed = _user(
        gold_scheme_status="completed",
        gold_scheme_target_grams=Decimal("10"),
        gold_savings_grams=Decimal("10"),
    )
    not_selected = _user(
        gold_scheme_status="not_selected",
        gold_savings_grams=Decimal("1"),
    )
    assert GoldSchemeService.can_sell_gold(no_gold) is False
    assert GoldSchemeService.can_sell_gold(with_gold_active) is False
    assert GoldSchemeService.can_sell_gold(completed) is True
    assert GoldSchemeService.can_sell_gold(not_selected) is False


def test_can_sell_requires_gold_holdings():
    completed_no_gold = _user(
        gold_scheme_status="completed",
        gold_scheme_target_grams=Decimal("1"),
        gold_savings_grams=Decimal("0"),
    )
    assert GoldSchemeService.can_sell_gold(completed_no_gold) is False
    assert (
        GoldSchemeService.sell_locked_reason(completed_no_gold)
        == "Buy gold first to unlock selling."
    )
