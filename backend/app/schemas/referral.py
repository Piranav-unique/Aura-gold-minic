from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field

ReferralSchemeTier = Literal[1, 5, 10]

REFERRAL_REWARD_INR: dict[int, Decimal] = {
    1: Decimal("150"),
    5: Decimal("350"),
    10: Decimal("550"),
}

REFERRAL_MIN_PURCHASE_INR: dict[int, Decimal] = {
    1: Decimal("100"),
    5: Decimal("1000"),
    10: Decimal("2000"),
}


class ReferralTierInfo(BaseModel):
    scheme_grams: int
    reward_inr: Decimal
    min_purchase_inr: Decimal = Decimal("100")


class ReferralRewardItem(BaseModel):
    referee_name: str
    scheme_grams: Decimal
    reward_inr: Decimal
    created_at: str


class ReferralSummaryResponse(BaseModel):
    referral_code: str
    wallet_balance_inr: Decimal
    total_referrals: int = 0
    total_earned_inr: Decimal = Decimal("0")
    tiers: list[ReferralTierInfo] = Field(default_factory=list)
    recent_rewards: list[ReferralRewardItem] = Field(default_factory=list)
