import hashlib
import hmac
import uuid
from typing import Any

import httpx

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.core.logging import logger


class RazorpayXClient:
    """RazorpayX REST client for contacts, fund accounts, and payouts."""

    BASE_URL = "https://api.razorpay.com/v1"
    DEV_MOCK_PAYOUT_PREFIX = "payout_dev_"

    def __init__(self) -> None:
        self.key_id = settings.RAZORPAY_KEY_ID
        self.key_secret = settings.RAZORPAY_KEY_SECRET
        self.account_number = settings.RAZORPAYX_ACCOUNT_NUMBER

    @property
    def is_configured(self) -> bool:
        return bool(self.key_id and self.key_secret and self.account_number)

    @property
    def use_dev_mock(self) -> bool:
        return (
            settings.ENVIRONMENT == "development"
            and settings.PAYMENT_DEV_MOCK
            and not self.is_configured
        )

    @staticmethod
    def is_dev_mock_payout(payout_id: str) -> bool:
        return payout_id.startswith(RazorpayXClient.DEV_MOCK_PAYOUT_PREFIX)

    async def _request(
        self,
        method: str,
        path: str,
        *,
        json: dict[str, Any] | None = None,
        idempotency_key: str | None = None,
    ) -> dict[str, Any]:
        headers: dict[str, str] = {}
        if idempotency_key:
            headers["X-Payout-Idempotency-Key"] = idempotency_key

        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.request(
                method,
                f"{self.BASE_URL}{path}",
                json=json,
                auth=(self.key_id, self.key_secret),
                headers=headers or None,
            )
        data = response.json() if response.content else {}
        if response.status_code >= 400:
            logger.error(
                "razorpayx_request_failed",
                method=method,
                path=path,
                status=response.status_code,
                body=data,
            )
            message = (
                data.get("error", {}).get("description")
                or "RazorpayX request failed."
            )
            raise ValidationException(message)
        return data

    async def create_contact(
        self,
        *,
        name: str,
        email: str,
        phone: str,
        reference_id: str,
    ) -> dict[str, Any]:
        return await self._request(
            "POST",
            "/contacts",
            json={
                "name": name,
                "email": email,
                "contact": phone,
                "type": "customer",
                "reference_id": reference_id,
            },
        )

    async def create_fund_account(
        self,
        *,
        contact_id: str,
        account_holder_name: str,
        ifsc: str,
        account_number: str,
    ) -> dict[str, Any]:
        return await self._request(
            "POST",
            "/fund_accounts",
            json={
                "contact_id": contact_id,
                "account_type": "bank_account",
                "bank_account": {
                    "name": account_holder_name,
                    "ifsc": ifsc.upper(),
                    "account_number": account_number,
                },
            },
        )

    async def create_payout(
        self,
        *,
        fund_account_id: str,
        amount_paise: int,
        reference_id: str,
        narration: str,
        idempotency_key: str,
        mode: str | None = None,
    ) -> dict[str, Any]:
        if amount_paise < 100:
            raise ValidationException("Minimum payout amount is ₹1.")
        payout_mode = mode or settings.RAZORPAYX_PAYOUT_MODE
        return await self._request(
            "POST",
            "/payouts",
            json={
                "account_number": self.account_number,
                "fund_account_id": fund_account_id,
                "amount": amount_paise,
                "currency": settings.RAZORPAY_CURRENCY,
                "mode": payout_mode,
                "purpose": "payout",
                "queue_if_low_balance": True,
                "reference_id": reference_id,
                "narration": narration[:30],
            },
            idempotency_key=idempotency_key,
        )

    def verify_webhook_signature(self, body: bytes, signature: str) -> bool:
        secret = settings.RAZORPAY_WEBHOOK_SECRET
        if not secret:
            return False
        expected = hmac.new(
            secret.encode(),
            body,
            hashlib.sha256,
        ).hexdigest()
        return hmac.compare_digest(expected, signature)

    def create_dev_mock_payout(
        self,
        *,
        amount_paise: int,
        reference_id: str,
    ) -> dict[str, Any]:
        return {
            "id": f"{self.DEV_MOCK_PAYOUT_PREFIX}{uuid.uuid4().hex[:20]}",
            "entity": "payout",
            "amount": amount_paise,
            "currency": "INR",
            "status": "processed",
            "reference_id": reference_id,
        }
