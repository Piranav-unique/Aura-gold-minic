import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.core.kyc_crypto import encrypt_aadhaar
from app.core.logging import logger
from app.models.user import User
from app.repositories.bank_account import (
    BankLinkChallengeRepository,
    UserBankAccountRepository,
)
from app.schemas.bank_account import (
    BankAccountResponse,
    BankLinkInitiateRequest,
    BankLinkInitiateResponse,
)
from app.services.ifsc import IfscService
from app.utils.mobile import normalize_mobile
from app.services.sms import SmsService

def _hash_bank_otp(user_id: UUID, otp: str) -> str:
    payload = f"bank:{user_id}:{otp}".encode()
    key = settings.SECRET_KEY.encode()
    return hmac.new(key, payload, hashlib.sha256).hexdigest()


def _encrypt_account_number(account_number: str) -> str:
    return encrypt_aadhaar(account_number)


MAX_BANK_ACCOUNTS_PER_USER = 2


class BankAccountService:
    def __init__(
        self,
        bank_repo: UserBankAccountRepository,
        challenge_repo: BankLinkChallengeRepository,
        sms_service: SmsService,
        ifsc_service: IfscService,
    ):
        self.bank_repo = bank_repo
        self.challenge_repo = challenge_repo
        self.sms_service = sms_service
        self.ifsc_service = ifsc_service

    def _require_mobile(self, user: User) -> str:
        mobile = normalize_mobile(user.mobile_number or "")
        if not mobile or not user.mobile_verified:
            raise ValidationException(
                "Verify your mobile number on signup before linking a bank account."
            )
        return mobile

    def _generate_otp(self) -> str:
        length = settings.MSG91_BANK_OTP_LENGTH
        return "".join(str(secrets.randbelow(10)) for _ in range(length))

    async def list_accounts(self, user: User) -> list[BankAccountResponse]:
        rows = await self.bank_repo.list_for_user(user.id)
        return [self._to_response(row) for row in rows]

    async def initiate_link(
        self, user: User, body: BankLinkInitiateRequest
    ) -> BankLinkInitiateResponse:
        mobile = self._require_mobile(user)

        existing = await self.bank_repo.list_for_user(user.id)
        if len(existing) >= MAX_BANK_ACCOUNTS_PER_USER:
            raise ValidationException(
                f"You can link at most {MAX_BANK_ACCOUNTS_PER_USER} bank accounts."
            )

        lookup = await self.ifsc_service.lookup_ifsc(body.ifsc)
        ifsc_bank = str(lookup.get("BANK") or body.bank_name).strip()
        ifsc_branch = str(lookup.get("BRANCH") or body.branch_name).strip()

        use_dev_otp = settings.bank_otp_uses_dev_code()
        otp_to_send = (
            settings.SIGNUP_OTP_DEV_CODE
            if use_dev_otp
            else self._generate_otp()
        )
        otp_hash = _hash_bank_otp(user.id, otp_to_send)

        expires_at = datetime.now(timezone.utc) + timedelta(
            minutes=settings.SIGNUP_OTP_EXPIRE_MINUTES
        )

        await self.challenge_repo.invalidate_pending(user.id)
        await self.challenge_repo.create(
            {
                "user_id": user.id,
                "account_holder_name": body.account_holder_name,
                "account_number_encrypted": _encrypt_account_number(body.account_number),
                "account_number_last4": body.account_number[-4:],
                "ifsc": body.ifsc.upper(),
                "bank_name": ifsc_bank or body.bank_name,
                "branch_name": ifsc_branch or body.branch_name,
                "account_type": body.account_type,
                "otp_hash": otp_hash,
                "expires_at": expires_at,
                "attempts": 0,
                "consumed": False,
            },
            commit=False,
        )

        try:
            if not use_dev_otp:
                await self.sms_service.send_bank_link_otp(mobile, otp_to_send)
            else:
                logger.info(
                    "bank_link_otp_dev_mode",
                    user_id=str(user.id),
                    mobile=mobile,
                    otp=otp_to_send,
                )
        except ValidationException:
            await self.challenge_repo.db.rollback()
            raise
        except Exception as exc:
            await self.challenge_repo.db.rollback()
            logger.warning("bank_link_otp_failed", user_id=str(user.id), error=str(exc))
            raise ValidationException(
                "Unable to send OTP right now. Please try again."
            ) from exc

        await self.challenge_repo.db.commit()
        last4 = mobile[-4:] if len(mobile) >= 4 else None
        return BankLinkInitiateResponse(
            message="OTP sent to your registered mobile number.",
            mobile_last4=last4,
        )

    async def verify_link(self, user: User, otp: str) -> BankAccountResponse:
        self._require_mobile(user)
        code = otp.strip()
        if len(code) != settings.MSG91_BANK_OTP_LENGTH:
            raise ValidationException(
                f"Enter the {settings.MSG91_BANK_OTP_LENGTH}-digit OTP."
            )

        challenge = await self.challenge_repo.get_latest_active(user.id)
        if not challenge:
            raise ValidationException(
                "OTP expired or not found. Save bank details again to resend."
            )

        if challenge.attempts >= settings.SIGNUP_OTP_MAX_ATTEMPTS:
            raise ValidationException("Too many invalid attempts. Request a new OTP.")

        challenge.attempts += 1

        try:
            if _hash_bank_otp(user.id, code) != challenge.otp_hash:
                await self.challenge_repo.db.commit()
                raise ValidationException("Invalid OTP. Please try again.")
        except ValidationException:
            await self.challenge_repo.db.commit()
            raise

        existing = await self.bank_repo.list_for_user(user.id)
        is_primary = len(existing) == 0

        account = await self.bank_repo.create(
            {
                "user_id": user.id,
                "account_holder_name": challenge.account_holder_name,
                "account_number_encrypted": challenge.account_number_encrypted,
                "account_number_last4": challenge.account_number_last4,
                "ifsc": challenge.ifsc,
                "bank_name": challenge.bank_name,
                "branch_name": challenge.branch_name,
                "account_type": challenge.account_type,
                "is_primary": is_primary,
                "verified_at": datetime.now(timezone.utc),
            },
            commit=False,
        )
        challenge.consumed = True
        await self.challenge_repo.db.commit()
        await self.bank_repo.db.refresh(account)
        return self._to_response(account)

    @staticmethod
    def _to_response(account) -> BankAccountResponse:
        return BankAccountResponse(
            id=account.id,
            account_holder_name=account.account_holder_name,
            account_number_masked=f"XXXX{account.account_number_last4}",
            ifsc=account.ifsc,
            bank_name=account.bank_name,
            branch_name=account.branch_name,
            account_type=account.account_type,
            is_primary=account.is_primary,
            verified_at=account.verified_at,
        )
