import secrets
import uuid
from decimal import Decimal

from app.core.exceptions import ValidationException
from app.models.user import User
from app.repositories.referral_reward import ReferralRewardRepository
from app.repositories.user import UserRepository
from app.schemas.referral import (
    REFERRAL_REWARD_INR,
    ReferralRewardItem,
    ReferralSummaryResponse,
    ReferralTierInfo,
)

_VALID_SCHEME_GRAMS = frozenset({Decimal("1"), Decimal("5"), Decimal("10")})


class ReferralService:
    def __init__(
        self,
        user_repo: UserRepository,
        reward_repo: ReferralRewardRepository,
    ):
        self.user_repo = user_repo
        self.reward_repo = reward_repo

    async def ensure_referral_code(self, user: User) -> str:
        if user.referral_code:
            return user.referral_code
        for _ in range(8):
            code = secrets.token_hex(4).upper()
            existing = await self.user_repo.get_by_referral_code(code)
            if not existing:
                user.referral_code = code
                await self.user_repo.db.commit()
                await self.user_repo.db.refresh(user)
                return code
        raise ValidationException("Unable to generate referral code. Try again.")

    async def apply_signup_referral(
        self,
        user: User,
        *,
        referral_code: str | None,
        scheme_grams: int | None,
    ) -> None:
        await self.ensure_referral_code(user)
        if not referral_code or not referral_code.strip():
            return

        referrer = await self.user_repo.get_by_referral_code(referral_code.strip().upper())
        if not referrer:
            raise ValidationException("Invalid referral code.")
        if referrer.id == user.id:
            raise ValidationException("You cannot use your own referral code.")

        user.referred_by_user_id = referrer.id
        if scheme_grams is not None:
            grams = Decimal(str(scheme_grams))
            if grams not in _VALID_SCHEME_GRAMS:
                raise ValidationException("Invalid referral scheme. Choose 1 g, 5 g, or 10 g.")
            user.referral_scheme_grams = grams

        await self.user_repo.db.commit()
        await self.user_repo.db.refresh(user)

    async def maybe_credit_referrer(
        self, referee: User, selected_grams: Decimal
    ) -> Decimal | None:
        if not referee.referred_by_user_id:
            return None

        referrer = await self.user_repo.get_with_roles_and_permissions(
            referee.referred_by_user_id
        )
        if not referrer:
            return None

        existing = await self.reward_repo.get_for_pair(referrer.id, referee.id)
        if existing:
            return None

        expected = (
            Decimal(str(referee.referral_scheme_grams))
            if referee.referral_scheme_grams is not None
            else selected_grams
        )
        if selected_grams != expected:
            return None

        reward_inr = REFERRAL_REWARD_INR.get(int(expected))
        if reward_inr is None:
            return None

        await self.reward_repo.create(
            {
                "id": uuid.uuid4(),
                "referrer_id": referrer.id,
                "referee_id": referee.id,
                "scheme_grams": expected,
                "reward_inr": reward_inr,
            },
            commit=False,
        )
        referrer.wallet_balance_inr = Decimal(str(referrer.wallet_balance_inr or 0)) + reward_inr
        await self.user_repo.db.commit()
        return reward_inr

    async def get_summary(self, user: User) -> ReferralSummaryResponse:
        code = await self.ensure_referral_code(user)
        count, earned = await self.reward_repo.count_and_sum_for_referrer(user.id)
        rewards = await self.reward_repo.list_for_referrer(user.id, limit=10)

        recent: list[ReferralRewardItem] = []
        for reward in rewards:
            referee = await self.user_repo.get_with_roles_and_permissions(reward.referee_id)
            name = _display_name(referee) if referee else "Friend"
            recent.append(
                ReferralRewardItem(
                    referee_name=name,
                    scheme_grams=reward.scheme_grams,
                    reward_inr=reward.reward_inr,
                    created_at=reward.created_at.isoformat(),
                )
            )

        tiers = [
            ReferralTierInfo(scheme_grams=grams, reward_inr=amount)
            for grams, amount in sorted(REFERRAL_REWARD_INR.items())
        ]

        return ReferralSummaryResponse(
            referral_code=code,
            wallet_balance_inr=Decimal(str(user.wallet_balance_inr or 0)),
            total_referrals=count,
            total_earned_inr=earned,
            tiers=tiers,
            recent_rewards=recent,
        )


def _display_name(user: User) -> str:
    parts = [p for p in (user.first_name, user.last_name) if p]
    return " ".join(parts) if parts else user.email
