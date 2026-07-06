from datetime import datetime, timezone
from decimal import Decimal

from app.core.exceptions import ValidationException
from app.models.user import User
from app.repositories.user import UserRepository
from app.schemas.gold_scheme import GoldSchemeResponse
from app.services.dashboard_cache import clear_personal_dashboard_cache
from app.services.referral import ReferralService

SCHEME_TIERS: tuple[Decimal, ...] = (Decimal("1"), Decimal("5"), Decimal("10"))


class GoldSchemeService:
    def __init__(
        self,
        user_repo: UserRepository,
        referral_service: ReferralService | None = None,
    ):
        self.user_repo = user_repo
        self.referral_service = referral_service

    async def select_scheme(self, user: User, *, target_grams: Decimal) -> GoldSchemeResponse:
        if user.kyc_status != "verified":
            raise ValidationException("Complete KYC verification before choosing a gold scheme.")
        if user.gold_scheme_status != "not_selected":
            raise ValidationException("You have already chosen a gold savings scheme.")
        if target_grams not in SCHEME_TIERS:
            raise ValidationException("Choose a valid scheme: 1 g, 5 g, or 10 g.")

        holdings = Decimal(str(user.gold_savings_grams or 0))
        if holdings > target_grams:
            raise ValidationException(
                f"Your current gold balance ({holdings} g) exceeds the {target_grams} g scheme. "
                f"Choose a higher scheme."
            )

        user.gold_scheme_target_grams = target_grams
        user.gold_scheme_started_at = datetime.now(timezone.utc)
        if holdings >= target_grams:
            user.gold_scheme_status = "completed"
        else:
            user.gold_scheme_status = "active"

        await self.user_repo.db.commit()
        await self.user_repo.db.refresh(user)
        clear_personal_dashboard_cache(str(user.id))
        if self.referral_service:
            await self.referral_service.maybe_credit_referrer(user, target_grams)
        return self.build_response(user)

    async def upgrade_scheme(
        self, user: User, *, target_grams: Decimal
    ) -> GoldSchemeResponse:
        if user.kyc_status != "verified":
            raise ValidationException("Complete KYC verification before upgrading.")
        if user.gold_scheme_status != "completed":
            raise ValidationException(
                "Finish your current gold savings scheme before choosing a new plan."
            )
        if target_grams not in SCHEME_TIERS:
            raise ValidationException("Choose a valid scheme: 1 g, 5 g, or 10 g.")

        current = Decimal(str(user.gold_scheme_target_grams or 0))
        if target_grams <= current:
            raise ValidationException(
                f"Choose a higher scheme than your completed {current} g plan."
            )

        holdings = Decimal(str(user.gold_savings_grams or 0))
        if holdings > target_grams:
            raise ValidationException(
                f"Your current gold balance ({holdings} g) exceeds the {target_grams} g "
                f"scheme. Choose a higher scheme."
            )

        user.gold_scheme_target_grams = target_grams
        user.gold_scheme_started_at = datetime.now(timezone.utc)
        if holdings >= target_grams:
            user.gold_scheme_status = "completed"
        else:
            user.gold_scheme_status = "active"

        await self.user_repo.db.commit()
        await self.user_repo.db.refresh(user)
        clear_personal_dashboard_cache(str(user.id))
        return self.build_response(user)

    @staticmethod
    def sync_after_gold_purchase(user: User) -> None:
        if user.gold_scheme_status != "active":
            return
        target = Decimal(str(user.gold_scheme_target_grams or 0))
        holdings = Decimal(str(user.gold_savings_grams or 0))
        if target > 0 and holdings >= target:
            user.gold_scheme_status = "completed"

    @staticmethod
    def can_sell_gold(user: User) -> bool:
        return GoldSchemeService.sell_locked_reason(user) is None

    @staticmethod
    def can_submit_sell_inquiry(user: User) -> bool:
        return GoldSchemeService.sell_inquiry_blocked_reason(user) is None

    @staticmethod
    def sell_locked_reason(user: User) -> str | None:
        if user.kyc_status != "verified":
            return "Complete your KYC before selling."
        holdings = Decimal(str(user.gold_savings_grams or 0))
        if holdings <= 0:
            return "Buy gold first to unlock selling."
        scheme_status = user.gold_scheme_status or "not_selected"
        if scheme_status == "active":
            return "Your savings scheme has not yet matured for selling."
        if scheme_status == "not_selected":
            return "Choose and complete your gold savings scheme before selling."
        return None

    @staticmethod
    def sell_inquiry_blocked_reason(user: User) -> str | None:
        if user.kyc_status != "verified":
            return "Complete your KYC before selling."
        holdings = Decimal(str(user.gold_savings_grams or 0))
        if holdings <= 0:
            return "Buy gold first to unlock selling."
        scheme_status = user.gold_scheme_status or "not_selected"
        if scheme_status == "not_selected":
            return "Choose a gold savings scheme before selling."
        return None

    @classmethod
    def build_response(cls, user: User) -> GoldSchemeResponse:
        status = user.gold_scheme_status or "not_selected"
        saved = Decimal(str(user.gold_savings_grams or 0))
        target = (
            Decimal(str(user.gold_scheme_target_grams))
            if user.gold_scheme_target_grams is not None
            else None
        )
        progress = Decimal("0")
        if target and target > 0:
            progress = min(Decimal("100"), (saved / target * Decimal("100")).quantize(Decimal("0.01")))

        can_sell = cls.can_sell_gold(user)
        can_sell_inquiry = cls.can_submit_sell_inquiry(user)
        return GoldSchemeResponse(
            status=status,  # type: ignore[arg-type]
            target_grams=target,
            saved_grams=saved,
            progress_percent=progress,
            can_sell=can_sell,
            can_sell_inquiry=can_sell_inquiry,
            sell_locked_reason=None if can_sell else cls.sell_locked_reason(user),
            started_at=user.gold_scheme_started_at,
        )
