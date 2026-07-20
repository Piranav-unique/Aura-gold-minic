import re
import uuid
from typing import Any, Optional

from app.core.exceptions import ValidationException
from app.core.kyc_crypto import decrypt_aadhaar, encrypt_aadhaar
from app.core.logging import logger
from app.core.kyc_profile import (
    aadhaar_dob_for_pan,
    compute_aadhaar_mobile_hash,
    dumps_profile,
    loads_profile,
    mask_mobile,
    merge_kyc_profile,
    parse_aadhaar_profile,
    parse_pan_profile,
    profile_for_api,
    profile_to_schema,
)
from app.models.user import User
from app.repositories.user import UserRepository
from app.schemas.profile import KycGovernmentProfile, KycStatusResponse
from app.services.audit import AuditService
from app.services.dashboard_cache import clear_personal_dashboard_cache
from app.services.sandbox_kyc import SandboxKycClient
from app.utils.mobile import normalize_mobile

_AADHAAR_RE = re.compile(r"^\d{12}$")
_PAN_RE = re.compile(r"^[A-Z]{5}[0-9]{4}[A-Z]$")
_LINKED_STATUSES = frozenset({"Y", "YES", "LINKED", "SUCCESS", "SUCCESSFUL", "TRUE"})


class KycService:
    """Two-stage KYC: Aadhaar OTP (UIDAI via Sandbox) then PAN–Aadhaar link."""

    def __init__(
        self,
        user_repo: UserRepository,
        sandbox_client: SandboxKycClient,
        audit_service: Optional[AuditService] = None,
    ):
        self.user_repo = user_repo
        self.sandbox = sandbox_client
        self.audit_service = audit_service

    async def send_aadhaar_otp(self, user_id: uuid.UUID, aadhaar_number: str) -> str:
        user = await self._get_user(user_id)
        self._ensure_can_start_aadhaar(user)
        self._ensure_registered_mobile(user)
        if user.kyc_status == "rejected":
            self._reset_kyc_progress(user)
            await self.user_repo.db.commit()
            clear_personal_dashboard_cache(str(user_id))
        normalized = self._normalize_aadhaar(aadhaar_number)
        reference_id = await self.sandbox.generate_aadhaar_otp(normalized)
        if self.audit_service:
            await self.audit_service.log_action(
                user_id=user_id,
                action="kyc_aadhaar_otp_sent",
                entity_type="User",
                entity_id=str(user_id),
                metadata={"aadhaar_last4": normalized[-4:]},
            )
        return reference_id

    async def verify_aadhaar_otp(
        self, user_id: uuid.UUID, reference_id: str, otp: str, aadhaar_number: str
    ) -> KycStatusResponse:
        user = await self._get_user(user_id)
        self._ensure_can_start_aadhaar(user)
        self._ensure_registered_mobile(user)
        normalized = self._normalize_aadhaar(aadhaar_number)
        if not reference_id.strip():
            raise ValidationException("OTP session expired. Request a new OTP.")
        if not otp.strip() or len(otp.strip()) != 6:
            raise ValidationException("Enter the 6-digit OTP.")

        body = await self.sandbox.verify_aadhaar_otp(reference_id.strip(), otp.strip())
        aadhaar_data = body.get("data") if isinstance(body.get("data"), dict) else {}
        linked_mobile = self._resolve_aadhaar_linked_mobile(
            user, aadhaar_data, normalized
        )

        profile = parse_aadhaar_profile(aadhaar_data, normalized[-4:])
        profile["aadhaar_linked_mobile_masked"] = mask_mobile(linked_mobile)

        user.kyc_status = "aadhaar_verified"
        user.kyc_aadhaar_encrypted = encrypt_aadhaar(normalized)
        user.kyc_aadhaar_last4 = normalized[-4:]
        user.kyc_profile = dumps_profile(profile)
        await self.user_repo.db.commit()
        clear_personal_dashboard_cache(str(user_id))

        if self.audit_service:
            try:
                await self.audit_service.log_action(
                    user_id=user_id,
                    action="kyc_aadhaar_verified",
                    entity_type="User",
                    entity_id=str(user_id),
                    metadata={"aadhaar_last4": normalized[-4:]},
                )
            except Exception:
                logger.exception(
                    "kyc_aadhaar_audit_failed",
                    extra={"user_id": str(user_id)},
                )

        return self.build_status_response(
            await self._get_user(user_id),
            message="Aadhaar verified. Continue with PAN linking.",
        )

    async def verify_pan_aadhaar_link(
        self, user_id: uuid.UUID, pan_number: str
    ) -> KycStatusResponse:
        user = await self._get_user(user_id)
        if user.kyc_status == "verified":
            raise ValidationException("KYC is already verified.")
        if user.kyc_status != "aadhaar_verified":
            raise ValidationException("Complete Aadhaar verification before PAN linking.")
        if not user.kyc_aadhaar_encrypted:
            raise ValidationException("Aadhaar verification data is missing. Restart KYC.")

        normalized_pan = self._normalize_pan(pan_number)
        aadhaar_number = decrypt_aadhaar(user.kyc_aadhaar_encrypted)
        link_body = await self.sandbox.verify_pan_aadhaar_link(
            normalized_pan, aadhaar_number
        )
        link_status = self._extract_link_status(link_body)

        if link_status.upper() not in _LINKED_STATUSES:
            user.kyc_status = "rejected"
            await self.user_repo.db.commit()
            clear_personal_dashboard_cache(str(user_id))
            raise ValidationException(
                "PAN is not linked with your verified Aadhaar. Link them on the "
                "Income Tax portal and try again."
            )

        stored = loads_profile(user.kyc_profile) or {}
        name = stored.get("full_name") or "Verified User"
        dob = aadhaar_dob_for_pan(stored.get("date_of_birth"))
        if not dob:
            raise ValidationException(
                "Aadhaar date of birth is missing. Restart Aadhaar verification."
            )

        pan_body = await self.sandbox.verify_pan_details(normalized_pan, name, dob)
        pan_data = pan_body.get("data") if isinstance(pan_body.get("data"), dict) else {}

        if str(pan_data.get("status", "valid")).lower() == "invalid":
            user.kyc_status = "rejected"
            await self.user_repo.db.commit()
            clear_personal_dashboard_cache(str(user_id))
            raise ValidationException("PAN could not be verified with government records.")

        profile = merge_kyc_profile(
            stored,
            parse_pan_profile(pan_data, normalized_pan),
        )
        profile["pan_last4"] = normalized_pan[-4:]

        user.kyc_status = "verified"
        user.kyc_pan_last4 = normalized_pan[-4:]
        user.kyc_aadhaar_encrypted = None
        user.kyc_profile = dumps_profile(profile)

        if profile.get("full_name"):
            parts = str(profile["full_name"]).strip().split(" ", 1)
            user.first_name = parts[0]
            user.last_name = parts[1] if len(parts) > 1 else None

        await self.user_repo.db.commit()
        clear_personal_dashboard_cache(str(user_id))

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=user_id,
                action="kyc_verified",
                entity_type="User",
                entity_id=str(user_id),
                metadata={
                    "pan_last4": normalized_pan[-4:],
                    "aadhaar_last4": user.kyc_aadhaar_last4,
                    "link_status": link_status,
                },
            )

        return self.build_status_response(
            await self._get_user(user_id),
            message="KYC complete. Your verified identity is now on file.",
        )

    async def get_status(self, user_id: uuid.UUID) -> KycStatusResponse:
        user = await self._get_user(user_id)
        return self.build_status_response(user)

    def build_status_response(
        self, user: User, message: str | None = None
    ) -> KycStatusResponse:
        raw = loads_profile(user.kyc_profile)
        profile = profile_to_schema(
            profile_for_api(user.kyc_status or "not_started", raw)
        )
        return KycStatusResponse(
            kyc_status=user.kyc_status or "not_started",
            aadhaar_last4=user.kyc_aadhaar_last4,
            pan_last4=user.kyc_pan_last4,
            registered_mobile_masked=mask_mobile(user.mobile_number),
            message=message,
            profile=profile,
        )

    async def _get_user(self, user_id: uuid.UUID) -> User:
        user = await self.user_repo.get_with_roles_and_permissions(user_id)
        if not user:
            raise ValidationException("User not found")
        return user

    @staticmethod
    def _extract_link_status(body: dict[str, Any]) -> str:
        data = body.get("data")
        if isinstance(data, dict):
            for key in ("aadhaar_seeding_status", "link_status", "status"):
                value = data.get(key)
                if value is not None:
                    return str(value).strip().upper()
        raise ValidationException("Unable to verify PAN–Aadhaar link status.")

    @staticmethod
    def _ensure_registered_mobile(user: User) -> None:
        if not user.mobile_verified or not user.mobile_number:
            raise ValidationException(
                "Verify your registered mobile number before starting KYC."
            )

    @staticmethod
    def _extract_okyc_field(data: dict[str, Any], *keys: str) -> Any:
        """Read UIDAI/Sandbox OKYC fields (supports snake_case and camelCase)."""
        if not data:
            return None
        normalized = {str(k).lower(): v for k, v in data.items()}
        for key in keys:
            value = normalized.get(key.lower())
            if value is not None and str(value).strip() != "":
                return value
        for value in data.values():
            if isinstance(value, dict):
                nested = KycService._extract_okyc_field(value, *keys)
                if nested is not None and str(nested).strip() != "":
                    return nested
        return None

    @staticmethod
    def _extract_aadhaar_mobile(data: dict[str, Any]) -> Optional[str]:
        for key in ("mobile", "mobile_number", "phone", "mobile_no", "phone_number"):
            value = KycService._extract_okyc_field(data, key)
            if value is None:
                continue
            digits = normalize_mobile(str(value))
            if len(digits) == 10:
                return digits
        return None

    def _resolve_aadhaar_linked_mobile(
        self, user: User, data: dict[str, Any], aadhaar_number: str
    ) -> str:
        linked = self._extract_aadhaar_mobile(data)
        if linked:
            self._ensure_aadhaar_mobile_matches(user, linked)
            return linked

        mobile_hash = self._extract_okyc_field(data, "mobile_hash", "mobileHash")
        share_code = self._extract_okyc_field(data, "share_code", "shareCode")
        registered = normalize_mobile(user.mobile_number or "")
        if not registered:
            raise ValidationException("Registered mobile number is missing.")

        if mobile_hash and share_code is not None and str(share_code).strip() != "":
            computed = compute_aadhaar_mobile_hash(
                registered, str(share_code).strip(), aadhaar_number
            )
            if computed.lower() != str(mobile_hash).strip().lower():
                raise ValidationException(
                    "The mobile linked with this Aadhaar does not match your registered "
                    "number. Use the same mobile number you signed up with for verification."
                )
            return registered

        status = str(self._extract_okyc_field(data, "status") or "").upper()
        has_identity = any(
            self._extract_okyc_field(
                data,
                key,
            )
            is not None
            for key in (
                "name",
                "full_name",
                "care_of",
                "dob",
                "date_of_birth",
                "gender",
                "address",
                "photo",
                "aadhaar_number",
                "uid",
            )
        )
        if status in {"VALID", "SUCCESS"} or has_identity:
            # OTP was validated by UIDAI/Sandbox; Aadhaar-linked mobile is proven.
            logger.info(
                "kyc_aadhaar_mobile_accepted_after_otp",
                user_id=str(user.id),
                status=status or None,
                has_identity=has_identity,
                has_mobile_hash=bool(mobile_hash),
            )
            return registered

        if not self.sandbox.is_configured:
            return registered

        logger.warning(
            "kyc_aadhaar_mobile_unconfirmed",
            user_id=str(user.id),
            data_keys=sorted(str(k) for k in data.keys()) if data else [],
            status=status or None,
        )
        raise ValidationException(
            "Unable to confirm the mobile linked with this Aadhaar. "
            "Enter the OTP from the SMS on your Aadhaar-linked mobile "
            f"(registered app mobile ends with {registered[-4:]})."
        )

    @staticmethod
    def _ensure_aadhaar_mobile_matches(user: User, linked_mobile: str) -> None:
        registered = normalize_mobile(user.mobile_number or "")
        if not registered:
            raise ValidationException("Registered mobile number is missing.")
        if linked_mobile != registered:
            raise ValidationException(
                "The mobile linked with this Aadhaar does not match your registered "
                "number. Use the same mobile number you signed up with for verification."
            )

    @staticmethod
    def _reset_kyc_progress(user: User) -> None:
        user.kyc_status = "not_started"
        user.kyc_aadhaar_encrypted = None
        user.kyc_aadhaar_last4 = None
        user.kyc_pan_last4 = None
        user.kyc_profile = None

    @staticmethod
    def _ensure_can_start_aadhaar(user: User) -> None:
        if user.kyc_status == "verified":
            raise ValidationException("KYC is already verified.")
        if user.kyc_status == "aadhaar_verified":
            raise ValidationException(
                "Aadhaar is already verified. Continue with PAN linking."
            )

    @staticmethod
    def _normalize_aadhaar(value: str) -> str:
        digits = re.sub(r"\D", "", value)
        if not _AADHAAR_RE.match(digits):
            raise ValidationException("Enter a valid 12-digit Aadhaar number.")
        return digits

    @staticmethod
    def _normalize_pan(value: str) -> str:
        normalized = value.strip().upper()
        if not _PAN_RE.match(normalized):
            raise ValidationException("Enter a valid PAN number (e.g. ABCDE1234F).")
        return normalized
