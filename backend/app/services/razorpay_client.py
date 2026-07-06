import hashlib
import hmac
from typing import Any

import httpx

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.core.logging import logger


class RazorpayClient:
    """Minimal Razorpay REST client for orders and signature verification."""

    BASE_URL = "https://api.razorpay.com/v1"
    DEV_MOCK_KEY_ID = "dev_mock"

    def __init__(self) -> None:
        self.key_id = settings.RAZORPAY_KEY_ID
        self.key_secret = settings.RAZORPAY_KEY_SECRET

    @property
    def is_configured(self) -> bool:
        return bool(self.key_id and self.key_secret)

    @property
    def use_dev_mock(self) -> bool:
        return (
            settings.ENVIRONMENT == "development"
            and settings.PAYMENT_DEV_MOCK
            and not self.is_configured
        )

    @staticmethod
    def is_dev_mock_order(order_id: str) -> bool:
        return order_id.startswith("order_dev_")

    async def create_order(
        self,
        *,
        amount_paise: int,
        receipt: str,
        notes: dict[str, str],
    ) -> dict[str, Any]:
        if not self.is_configured:
            raise ValidationException("Razorpay is not configured on the server.")
        if amount_paise < 100:
            raise ValidationException("Minimum payment amount is ₹1.")

        payload = {
            "amount": amount_paise,
            "currency": settings.RAZORPAY_CURRENCY,
            "receipt": receipt,
            "notes": notes,
        }
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self.BASE_URL}/orders",
                json=payload,
                auth=(self.key_id, self.key_secret),
            )
        data = response.json() if response.content else {}
        if response.status_code >= 400:
            logger.error(
                "razorpay_create_order_failed",
                status=response.status_code,
                body=data,
            )
            message = (
                data.get("error", {}).get("description")
                or "Unable to create payment order."
            )
            raise ValidationException(message)
        return data

    async def fetch_order_payments(self, order_id: str) -> list[dict[str, Any]]:
        """Return Razorpay payments linked to an order (captured = paid)."""
        if not self.is_configured:
            return []
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                f"{self.BASE_URL}/orders/{order_id}/payments",
                auth=(self.key_id, self.key_secret),
            )
        data = response.json() if response.content else {}
        if response.status_code >= 400:
            logger.error(
                "razorpay_fetch_order_payments_failed",
                status=response.status_code,
                body=data,
                extra={"order_id": order_id},
            )
            return []
        items = data.get("items")
        return items if isinstance(items, list) else []

    def verify_payment_signature(
        self,
        *,
        razorpay_order_id: str,
        razorpay_payment_id: str,
        razorpay_signature: str,
    ) -> bool:
        if not self.key_secret:
            return False
        body = f"{razorpay_order_id}|{razorpay_payment_id}".encode()
        expected = hmac.new(
            self.key_secret.encode(),
            body,
            hashlib.sha256,
        ).hexdigest()
        return hmac.compare_digest(expected, razorpay_signature)
