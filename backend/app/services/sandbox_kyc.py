import asyncio
import time
from typing import Any, Optional

import httpx

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.core.logging import logger

_token_cache: tuple[float, str] | None = None
_TOKEN_TTL_SECONDS = 23 * 60 * 60


class SandboxKycClient:
    """Client for Sandbox.co.in Aadhaar OTP and PAN–Aadhaar link APIs."""

    def __init__(self) -> None:
        self.base_url = settings.SANDBOX_BASE_URL.rstrip("/")
        self.api_key = settings.SANDBOX_API_KEY
        self.api_secret = settings.SANDBOX_API_SECRET
        self.api_version = settings.SANDBOX_API_VERSION
        self.reason = settings.KYC_VERIFICATION_REASON

    @property
    def is_configured(self) -> bool:
        return bool(self.api_key and self.api_secret)

    async def generate_aadhaar_otp(self, aadhaar_number: str) -> str:
        if not self.is_configured:
            return self._mock_generate_otp(aadhaar_number)

        payload = {
            "@entity": "in.co.sandbox.kyc.aadhaar.okyc.otp.request",
            "aadhaar_number": aadhaar_number,
            "consent": "Y",
            "reason": self.reason,
        }
        data = await self._post("/kyc/aadhaar/okyc/otp", payload)
        reference_id = self._extract_reference_id(data)
        if not reference_id:
            message = (
                self._extract_error_message(data)
                or "Unable to send Aadhaar OTP. Please try again."
            )
            logger.error(
                "sandbox_aadhaar_otp_failed",
                message=message,
                transaction_id=data.get("transaction_id"),
            )
            raise ValidationException(message)
        return reference_id

    async def verify_aadhaar_otp(self, reference_id: str, otp: str) -> dict[str, Any]:
        if not self.is_configured:
            return self._mock_verify_otp(reference_id, otp)

        payload = {
            "@entity": "in.co.sandbox.kyc.aadhaar.okyc.request",
            "reference_id": reference_id,
            "otp": otp,
        }
        body = await self._post("/kyc/aadhaar/okyc/otp/verify", payload)
        data = body.get("data") if isinstance(body.get("data"), dict) else {}
        status = str(data.get("status", "")).upper()
        if status and status not in {"VALID", "SUCCESS"}:
            message = data.get("message") or "Invalid OTP. Please try again."
            raise ValidationException(str(message))
        return body

    async def verify_pan_aadhaar_link(
        self, pan_number: str, aadhaar_number: str
    ) -> dict[str, Any]:
        if not self.is_configured:
            return self._mock_pan_link_response(pan_number, aadhaar_number)

        payload = {
            "@entity": "in.co.sandbox.kyc.pan_aadhaar.status",
            "pan": pan_number,
            "aadhaar_number": aadhaar_number,
            "consent": "Y",
            "reason": self.reason,
        }
        return await self._post("/kyc/pan-aadhaar/status", payload)

    async def verify_pan_details(
        self, pan_number: str, name_as_per_pan: str, date_of_birth: str
    ) -> dict[str, Any]:
        if not self.is_configured:
            return self._mock_pan_details(pan_number, name_as_per_pan)

        payload = {
            "@entity": "in.co.sandbox.kyc.pan_verification.request",
            "pan": pan_number,
            "name_as_per_pan": name_as_per_pan,
            "date_of_birth": date_of_birth,
            "consent": "Y",
            "reason": self.reason,
        }
        return await self._post("/kyc/pan/verify", payload)

    async def _post(
        self, path: str, payload: dict[str, Any], *, max_attempts: int = 3
    ) -> dict[str, Any]:
        last_body: dict[str, Any] = {}
        last_status = 0
        force_refresh = False

        for attempt in range(max_attempts):
            token = await self._get_access_token(force_refresh=force_refresh)
            force_refresh = False
            headers = {
                "x-api-key": self.api_key,
                "authorization": token,
                "x-api-version": self.api_version,
                "Content-Type": "application/json",
                "accept": "application/json",
            }
            url = f"{self.base_url}{path}"

            try:
                async with httpx.AsyncClient(timeout=30.0) as client:
                    response = await client.post(url, json=payload, headers=headers)
            except httpx.HTTPError as exc:
                logger.error("sandbox_kyc_http_error", path=path, error=str(exc))
                if attempt < max_attempts - 1:
                    await asyncio.sleep(2**attempt)
                    continue
                raise ValidationException(
                    "KYC provider is temporarily unavailable. Please try again."
                ) from exc

            last_body = self._parse_json(response)
            last_status = response.status_code

            if response.status_code in {401, 403} and attempt < max_attempts - 1:
                logger.warning(
                    "sandbox_kyc_auth_retry",
                    path=path,
                    status_code=response.status_code,
                    attempt=attempt + 1,
                )
                self.clear_token_cache()
                force_refresh = True
                await asyncio.sleep(2**attempt)
                continue

            if response.status_code == 503 and attempt < max_attempts - 1:
                logger.warning(
                    "sandbox_kyc_source_unavailable_retry",
                    path=path,
                    attempt=attempt + 1,
                    transaction_id=last_body.get("transaction_id"),
                )
                await asyncio.sleep(2**attempt)
                continue

            if response.status_code >= 400:
                message = self._friendly_error_message(last_body, last_status)
                raise ValidationException(message)

            api_code = last_body.get("code")
            if isinstance(api_code, int) and api_code >= 400:
                message = self._friendly_error_message(last_body, api_code)
                raise ValidationException(message)

            return last_body

        message = self._friendly_error_message(last_body, last_status)
        raise ValidationException(message)

    @staticmethod
    def _friendly_error_message(body: dict[str, Any], status_code: int) -> str:
        raw = SandboxKycClient._extract_error_message(body)
        if status_code == 503 or (raw and raw.lower() == "source unavailable"):
            return (
                "UIDAI verification is temporarily unavailable. Wait a minute, "
                "then tap Verify again. If it keeps failing, request a new OTP."
            )
        return raw or "KYC verification failed. Please check your details and try again."

    async def _get_access_token(self, *, force_refresh: bool = False) -> str:
        global _token_cache
        now = time.monotonic()
        if (
            not force_refresh
            and _token_cache
            and (now - _token_cache[0]) < _TOKEN_TTL_SECONDS
        ):
            return _token_cache[1]

        headers = {
            "x-api-key": self.api_key,
            "x-api-secret": self.api_secret,
            "x-api-version": self.api_version,
            "accept": "application/json",
        }
        url = f"{self.base_url}/authenticate"
        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.post(url, headers=headers)
        except httpx.HTTPError as exc:
            logger.error("sandbox_auth_http_error", error=str(exc))
            raise ValidationException(
                "Unable to connect to KYC provider. Please try again later."
            ) from exc

        body = self._parse_json(response)
        if response.status_code >= 400:
            provider_message = self._extract_error_message(body)
            logger.error(
                "sandbox_auth_failed",
                status_code=response.status_code,
                message=provider_message,
                key_prefix=(self.api_key[:12] if self.api_key else ""),
            )
            raise ValidationException(
                "KYC provider authentication failed. "
                "Check SANDBOX_API_KEY and SANDBOX_API_SECRET on the server."
            )

        token = self._extract_access_token(body)
        if not token:
            logger.error(
                "sandbox_auth_missing_token",
                status_code=response.status_code,
                body_keys=sorted(body.keys()),
                message=body.get("message"),
            )
            raise ValidationException("KYC provider authentication failed.")

        _token_cache = (now, token)
        return token

    @staticmethod
    def _extract_access_token(body: dict[str, Any]) -> Optional[str]:
        """Support both nested and top-level Sandbox authenticate responses."""
        data = body.get("data")
        if isinstance(data, dict) and data.get("access_token"):
            return str(data["access_token"])
        if body.get("access_token"):
            return str(body["access_token"])
        return None

    @staticmethod
    def clear_token_cache() -> None:
        global _token_cache
        _token_cache = None

    @staticmethod
    def _parse_json(response: httpx.Response) -> dict[str, Any]:
        try:
            data = response.json()
            return data if isinstance(data, dict) else {}
        except ValueError:
            return {}

    @staticmethod
    def _extract_reference_id(body: dict[str, Any]) -> Optional[str]:
        data = body.get("data")
        if isinstance(data, dict):
            for key in ("reference_id", "ref_id"):
                if data.get(key):
                    return str(data[key])
        return None

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
    def _extract_error_message(body: dict[str, Any]) -> Optional[str]:
        if isinstance(body.get("message"), str):
            return body["message"]
        data = body.get("data")
        if isinstance(data, dict):
            for key in ("message", "error", "remarks"):
                if isinstance(data.get(key), str):
                    return data[key]
        return None

    @staticmethod
    def _mock_generate_otp(aadhaar_number: str) -> str:
        if not aadhaar_number.isdigit() or len(aadhaar_number) != 12:
            raise ValidationException("Enter a valid 12-digit Aadhaar number.")
        return f"mock-ref-{aadhaar_number[-4:]}"

    @staticmethod
    def _mock_verify_otp(reference_id: str, otp: str) -> dict[str, Any]:
        if otp != "123456":
            raise ValidationException("Invalid OTP. Use 123456 in development mode.")
        return {
            "data": {
                "status": "VALID",
                "reference_id": reference_id,
                "name": "Ramesh Kumar",
                "date_of_birth": "15-08-1992",
                "gender": "M",
                "care_of": "S/O: Murugan",
                "full_address": "12, Anna Salai, Chennai, Tamil Nadu - 600002",
                "address": {
                    "house": "12, Anna Salai",
                    "street": "Anna Salai",
                    "district": "Chennai",
                    "state": "Tamil Nadu",
                    "pincode": "600002",
                    "country": "India",
                },
            }
        }

    @staticmethod
    def _mock_pan_link_response(pan_number: str, aadhaar_number: str) -> dict[str, Any]:
        if len(aadhaar_number) != 12:
            raise ValidationException("Aadhaar verification is required first.")
        return {
            "data": {
                "aadhaar_seeding_status": "Y",
                "link_status": "Y",
                "message": "PAN is linked with Aadhaar.",
            }
        }

    @staticmethod
    def _mock_pan_details(pan_number: str, name_as_per_pan: str) -> dict[str, Any]:
        return {
            "data": {
                "pan": pan_number,
                "category": "individual",
                "status": "valid",
                "name_as_per_pan_match": True,
                "date_of_birth_match": True,
                "aadhaar_seeding_status": "Y",
            }
        }
