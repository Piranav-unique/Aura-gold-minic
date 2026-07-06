import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.core.logging import logger
from app.repositories.signup_otp import SignupOtpRepository
from app.repositories.user import UserRepository
from app.services.sms import SmsService
from app.utils.mobile import normalize_mobile
from app.utils.device_binding import normalize_device_id

_MSG91_NATIVE_SENTINEL = "msg91-native"


def _hash_otp(mobile_number: str, otp: str) -> str:
    payload = f"{mobile_number}:{otp}".encode()
    key = settings.SECRET_KEY.encode()
    return hmac.new(key, payload, hashlib.sha256).hexdigest()


class SignupOtpService:
    def __init__(
        self,
        otp_repo: SignupOtpRepository,
        user_repo: UserRepository,
        sms_service: SmsService,
    ):
        self.otp_repo = otp_repo
        self.user_repo = user_repo
        self.sms_service = sms_service

    def _generate_otp(self) -> str:
        length = settings.SIGNUP_OTP_LENGTH
        return "".join(str(secrets.randbelow(10)) for _ in range(length))

    def _uses_msg91_native(self) -> bool:
        return self.sms_service.uses_msg91_native_otp

    async def _send_otp_challenge(self, mobile: str) -> None:
        since = datetime.now(timezone.utc) - timedelta(
            hours=settings.SIGNUP_OTP_SEND_COOLDOWN_HOURS
        )
        recent = await self.otp_repo.count_recent_sends(mobile, since)
        if recent >= settings.SIGNUP_OTP_MAX_SENDS_PER_HOUR:
            raise ValidationException(
                "Too many OTP requests. Please try again in about an hour."
            )

        latest = await self.otp_repo.get_latest_send(mobile)
        if latest and latest.created_at:
            elapsed = (
                datetime.now(timezone.utc) - latest.created_at
            ).total_seconds()
            if elapsed < settings.SIGNUP_OTP_MIN_RESEND_SECONDS:
                wait = int(settings.SIGNUP_OTP_MIN_RESEND_SECONDS - elapsed)
                raise ValidationException(
                    f"Please wait {wait} seconds before requesting another OTP."
                )

        use_msg91_native = self._uses_msg91_native()
        if use_msg91_native:
            otp_to_send = None
            otp_hash = _hash_otp(mobile, _MSG91_NATIVE_SENTINEL)
        else:
            otp_to_send = self._generate_otp()
            if (
                not settings.MSG91_AUTH_KEY.strip()
                and settings.ENVIRONMENT == "development"
            ):
                otp_to_send = settings.SIGNUP_OTP_DEV_CODE
            otp_hash = _hash_otp(mobile, otp_to_send)

        expires_at = datetime.now(timezone.utc) + timedelta(
            minutes=settings.SIGNUP_OTP_EXPIRE_MINUTES
        )

        await self.otp_repo.invalidate_pending(mobile)
        await self.otp_repo.create(
            {
                "mobile_number": mobile,
                "otp_hash": otp_hash,
                "expires_at": expires_at,
                "attempts": 0,
                "verified": False,
                "consumed": False,
            },
            commit=False,
        )

        try:
            await self.sms_service.send_signup_otp(mobile, otp_to_send)
        except ValidationException:
            await self.otp_repo.db.rollback()
            raise
        except Exception as exc:
            await self.otp_repo.db.rollback()
            logger.warning("signup_otp_sms_failed", mobile=mobile, error=str(exc))
            if settings.MSG91_AUTH_KEY.strip():
                raise ValidationException(
                    "Unable to send OTP right now. Please try again."
                ) from exc
            return

        await self.otp_repo.db.commit()

    async def send_signup_otp(self, mobile_number: str) -> None:
        mobile = normalize_mobile(mobile_number)
        existing = await self.user_repo.get_by_mobile(mobile)
        if existing:
            raise ValidationException("This mobile number is already registered.")
        await self._send_otp_challenge(mobile)

    async def send_login_otp(self, mobile_number: str, device_id: str) -> None:
        mobile = normalize_mobile(mobile_number)
        normalized_device = normalize_device_id(device_id)
        user = await self.user_repo.get_by_mobile(mobile)
        if (
            not user
            or not user.mobile_verified
            or not user.is_active
            or user.is_deleted
        ):
            raise ValidationException("No account found for this mobile number.")
        if user.is_superuser:
            raise ValidationException("Use email and password to sign in as staff.")
        if (
            user.registered_device_id
            and user.registered_device_id != normalized_device
        ):
            raise ValidationException(
                "This account is registered on another device. "
                "Please sign in using the phone you signed up with."
            )
        await self._send_otp_challenge(mobile)

    async def consume_login_otp(self, mobile_number: str, otp: str) -> None:
        await self._check_otp_code(mobile_number, otp, consume=True)

    async def _check_otp_code(
        self, mobile_number: str, otp: str, *, consume: bool
    ) -> None:
        mobile = normalize_mobile(mobile_number)
        code = otp.strip()
        if len(code) != settings.SIGNUP_OTP_LENGTH:
            raise ValidationException(
                f"Enter the {settings.SIGNUP_OTP_LENGTH}-digit OTP."
            )

        challenge = await self.otp_repo.get_latest_active(mobile)
        if not challenge:
            raise ValidationException(
                "OTP expired or not found. Tap Send OTP to request a new code."
            )

        if challenge.attempts >= settings.SIGNUP_OTP_MAX_ATTEMPTS:
            raise ValidationException("Too many invalid attempts. Request a new OTP.")

        if challenge.verified:
            if consume:
                challenge.consumed = True
                await self.otp_repo.db.commit()
                return
            raise ValidationException("Mobile number already verified.")

        challenge.attempts += 1

        try:
            if self._uses_msg91_native():
                await self.sms_service.verify_msg91_otp(mobile, code)
            elif _hash_otp(mobile, code) != challenge.otp_hash:
                await self.otp_repo.db.commit()
                raise ValidationException("Invalid OTP. Please try again.")
        except ValidationException:
            await self.otp_repo.db.commit()
            raise

        challenge.verified = True
        if consume:
            challenge.consumed = True
        await self.otp_repo.db.commit()

    async def verify_signup_otp(self, mobile_number: str, otp: str) -> None:
        await self._check_otp_code(mobile_number, otp, consume=False)

    async def consume_verified_otp(self, mobile_number: str, otp: str) -> None:
        await self._check_otp_code(mobile_number, otp, consume=True)
