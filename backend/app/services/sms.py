import re

import httpx
import structlog

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.utils.mobile import normalize_mobile

logger = structlog.get_logger()

# https://msg91.com/help/api/what-are-the-reason-for-error-codes-received-under-the-api-failed
_MSG91_ERROR_CODES: dict[str, str] = {
    "101": "Mobile number is missing.",
    "102": "Message text is missing.",
    "104": "Username is missing.",
    "105": "Password is missing.",
    "201": "Invalid authentication key or incorrect API request.",
    "202": "Invalid mobile number.",
    "203": "Invalid sender ID or DLT Entity ID is missing.",
    "204": "SMS sending is not enabled for this auth key.",
    "207": "Invalid authentication key.",
    "208": "Your server IP is blacklisted on MSG91.",
    "209": "Default route not found.",
    "210": "Route could not be determined. Contact MSG91 support.",
    "211": "DLT Template ID is missing.",
    "301": "Insufficient MSG91 balance to send SMS.",
    "302": "MSG91 account expired.",
    "303": "MSG91 account banned.",
    "306": "This SMS route is currently unavailable.",
    "307": "Scheduled time is incorrect.",
    "308": "Campaign name cannot exceed 32 characters.",
    "309": "Selected group does not belong to your account.",
    "310": "SMS is too long.",
    "311": "Duplicate OTP to the same number within 10 seconds. Wait and try again.",
    "400": "Template ID is missing, incorrect, or archived on MSG91.",
    "401": "MSG91 flow/template is not yet approved.",
    "402": "Message contains blocked keywords.",
    "403": "MSG91 flow is disabled.",
    "407": "International number blocked or template API misconfigured.",
    "418": "Server IP is not whitelisted on MSG91.",
    "421": "MSG91 service terminated. Contact MSG91 support.",
    "506": "MSG91 internal error. Contact your account manager.",
    "601": "MSG91 internal error. Contact your account manager.",
    "602": "Current route disabled. Select another route in MSG91.",
    "603": "Sender ID is blacklisted. Use a different sender on MSG91.",
    "604": "No valid mobile number provided.",
    "606": "Scheduled date cannot be more than three weeks ahead.",
    "607": "Campaign name is required.",
    "608": "Scheduled SMS time is invalid.",
}

_MSG91_FLOW_URL = "https://control.msg91.com/api/v5/flow"
_MSG91_OTP_URL = "https://control.msg91.com/api/v5/otp"
_MSG91_SENDOTP_URL = "https://control.msg91.com/api/sendotp.php"


class SmsService:
    """Signup OTP via MSG91 (India DLT). Primary: Flow API with sender CP-AURUS-S."""

    def build_signup_otp_message(self, otp: str) -> str:
        return (
            f"Dear Customer, your One Time Password to access "
            f"AURUM GOLD & SILVERS is {otp}. "
            f"Do not share this OTP with anyone for your account safety."
        )

    @property
    def is_live(self) -> bool:
        return bool(settings.MSG91_AUTH_KEY.strip())

    def _dlt_configured(self) -> bool:
        return bool(
            settings.MSG91_DLT_TE_ID.strip()
            and settings.MSG91_DLT_TEMPLATE_ID.strip()
        )

    @property
    def uses_msg91_native_otp(self) -> bool:
        return self.is_live and settings.SIGNUP_OTP_USE_MSG91_VERIFY

    async def _ensure_msg91_balance(self) -> None:
        """Fail fast when the MSG91 wallet cannot fund delivery."""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    "https://api.msg91.com/api/getBalance.php",
                    params={"authkey": settings.MSG91_AUTH_KEY},
                )
                response.raise_for_status()
                rows = response.json()
        except Exception as exc:
            logger.warning("msg91_balance_check_failed", error=str(exc))
            return

        if not isinstance(rows, list):
            return

        total = sum(
            float(row.get("balance", 0))
            for row in rows
            if isinstance(row, dict)
        )
        logger.info("msg91_wallet_balance", total=total, routes=rows)
        if total < 1:
            raise ValidationException(
                "MSG91 SMS balance is zero. Recharge your MSG91 wallet, then try again."
            )

    async def send_bank_link_otp(self, mobile_number: str, otp: str | None = None) -> None:
        """Send bank-account linking OTP via the bank DLT template (Aurum_Bank_Add_OTP)."""
        mobile = normalize_mobile(mobile_number)
        if not mobile:
            raise ValidationException("Registered mobile number is invalid.")

        if settings.bank_otp_uses_dev_code():
            logger.info("bank_link_otp_sms_mock", mobile=mobile, otp=otp)
            return

        if not self.is_live:
            if settings.ENVIRONMENT == "production":
                raise ValidationException(
                    "SMS is not configured on the server. Please try again later."
                )
            logger.info("bank_link_otp_sms_mock", mobile=mobile, otp=otp)
            return

        await self._ensure_msg91_balance()

        template_id = (
            settings.MSG91_BANK_OTP_TEMPLATE_ID.strip()
            or settings.MSG91_OTP_TEMPLATE_ID.strip()
        )
        dlt_template_id = (
            settings.MSG91_BANK_DLT_TEMPLATE_ID.strip()
            or settings.MSG91_DLT_TEMPLATE_ID.strip()
        )
        flow_id = (
            settings.MSG91_BANK_FLOW_ID.strip()
            or settings.MSG91_FLOW_ID.strip()
            or template_id
        )
        dlt_te_id = settings.MSG91_DLT_TE_ID.strip()

        if not flow_id:
            raise ValidationException(
                "Bank SMS Flow ID is not configured. Set MSG91_BANK_FLOW_ID on the server."
            )

        if not dlt_template_id:
            raise ValidationException(
                "Bank DLT template is not configured. Set MSG91_BANK_DLT_TEMPLATE_ID=1207178235534667442."
            )

        logger.info(
            "msg91_bank_otp_config",
            template_id=template_id,
            dlt_template_id=dlt_template_id,
            flow_id=flow_id,
            sender=settings.SMS_SENDER_ID,
            native_verify=settings.MSG91_BANK_OTP_USE_MSG91_VERIFY,
            otp_length=settings.MSG91_BANK_OTP_LENGTH,
        )

        if not otp:
            raise ValidationException(
                "Bank OTP is required. Configure MSG91 bank Flow template."
            )

        channels = self._bank_sms_channels()
        # Aurum_Bank_Add_OTP is a Flow template — v5 /otp and sendotp.php reject its ID (error 400).
        channels = [c for c in channels if c not in {"otp", "sendotp"}]
        if not channels:
            channels = ["flow", "sendhttp"]
        last_error: ValidationException | None = None
        for channel in channels:
            try:
                if channel == "flow":
                    if not otp:
                        raise ValidationException("OTP value required for flow channel.")
                    await self._send_msg91_flow(
                        mobile,
                        otp,
                        flow_id=flow_id,
                        dlt_template_id=dlt_template_id,
                        dlt_te_id=dlt_te_id,
                    )
                elif channel == "otp":
                    await self._send_msg91_otp_v5(
                        mobile,
                        otp,
                        template_id=template_id,
                        dlt_template_id=dlt_template_id,
                        dlt_te_id=dlt_te_id,
                        use_native_verify=settings.MSG91_BANK_OTP_USE_MSG91_VERIFY,
                        otp_length=settings.MSG91_BANK_OTP_LENGTH,
                    )
                elif channel == "sendotp":
                    if not otp:
                        raise ValidationException("OTP value required for sendotp channel.")
                    await self._send_msg91_sendotp(
                        mobile,
                        otp,
                        template_id=template_id,
                        dlt_template_id=dlt_template_id,
                        dlt_te_id=dlt_te_id,
                    )
                elif channel == "sendhttp":
                    if not otp:
                        raise ValidationException("OTP value required for sendhttp channel.")
                    await self._send_msg91_sendhttp(
                        mobile,
                        self.build_bank_link_otp_message(otp),
                        dlt_template_id=dlt_template_id,
                        dlt_te_id=dlt_te_id,
                    )
                else:
                    logger.warning("msg91_bank_unknown_channel", channel=channel)
                    continue

                logger.info(
                    "msg91_bank_otp_dispatched",
                    mobile=mobile,
                    channel=channel,
                )
                return
            except ValidationException as exc:
                last_error = exc
                logger.warning(
                    "msg91_bank_channel_failed",
                    mobile=mobile,
                    channel=channel,
                    error=str(exc),
                )

        if last_error:
            raise last_error
        raise ValidationException("Unable to send OTP right now. Please try again.")

    def build_bank_link_otp_message(self, otp: str) -> str:
        """Must match DLT template Aurum_Bank_Add_OTP (1207178235534667442) exactly."""
        return (
            f"Your OTP {otp} confirms bank account linking on AURUM GOLD & SILVERS. "
            f"Do not share it with anyone."
        )

    @property
    def uses_msg91_native_bank_otp(self) -> bool:
        return self.is_live and settings.MSG91_BANK_OTP_USE_MSG91_VERIFY

    def _bank_sms_channels(self) -> list[str]:
        raw = settings.MSG91_BANK_SMS_CHANNELS.strip() or settings.MSG91_SMS_CHANNELS
        channels = [channel.strip() for channel in raw.split(",") if channel.strip()]
        return channels or ["otp"]

    async def send_signup_otp(self, mobile_number: str, otp: str | None = None) -> None:
        mobile = normalize_mobile(mobile_number)
        if not mobile:
            raise ValidationException("Mobile number is invalid.")
        if not self.is_live:
            logger.info(
                "signup_otp_sms_mock",
                mobile=mobile,
                otp=otp,
            )
            return

        await self._ensure_msg91_balance()

        logger.info(
            "msg91_otp_config",
            template_id=settings.MSG91_OTP_TEMPLATE_ID,
            flow_id=settings.MSG91_FLOW_ID or settings.MSG91_OTP_TEMPLATE_ID,
            channels=settings.MSG91_SMS_CHANNELS,
            sender=settings.SMS_SENDER_ID,
            native_verify=settings.SIGNUP_OTP_USE_MSG91_VERIFY,
            otp_length=settings.SIGNUP_OTP_LENGTH,
        )

        if not self._dlt_configured():
            logger.warning(
                "msg91_dlt_ids_missing",
                mobile=mobile,
                hint="Set MSG91_DLT_TE_ID and MSG91_DLT_TEMPLATE_ID in .env from MSG91/DLT portal",
            )

        channels = [
            channel.strip()
            for channel in settings.MSG91_SMS_CHANNELS.split(",")
            if channel.strip()
        ]
        if not channels:
            channels = ["otp"]

        last_error: ValidationException | None = None
        for channel in channels:
            try:
                if channel == "flow":
                    if not otp:
                        raise ValidationException("OTP value required for flow channel.")
                    await self._send_msg91_flow(mobile, otp)
                elif channel == "otp":
                    await self._send_msg91_otp_v5(mobile, otp)
                elif channel == "sendotp":
                    if not otp:
                        raise ValidationException("OTP value required for sendotp channel.")
                    await self._send_msg91_sendotp(mobile, otp)
                elif channel == "sendhttp":
                    if not otp:
                        raise ValidationException("OTP value required for sendhttp channel.")
                    await self._send_msg91_sendhttp(
                        mobile, self.build_signup_otp_message(otp)
                    )
                else:
                    logger.warning("msg91_unknown_channel", channel=channel)
                    continue

                logger.info(
                    "msg91_signup_otp_dispatched",
                    mobile=mobile,
                    channel=channel,
                )
                return
            except ValidationException as exc:
                last_error = exc
                logger.warning(
                    "msg91_channel_failed",
                    mobile=mobile,
                    channel=channel,
                    error=str(exc),
                )

        if last_error:
            raise last_error
        raise ValidationException("Unable to send OTP right now. Please try again.")

    def _raise_for_msg91_code(self, code: str) -> None:
        normalized = code.strip()
        if normalized in _MSG91_ERROR_CODES:
            raise ValidationException(_MSG91_ERROR_CODES[normalized])
        if normalized.isdigit() and len(normalized) <= 3:
            raise ValidationException(
                _MSG91_ERROR_CODES.get(
                    normalized, f"SMS gateway error (code {normalized})."
                )
            )

    def _ensure_msg91_json_success(self, data: dict) -> str:
        if data.get("type") == "error":
            message = str(data.get("message") or data)
            if message.isdigit():
                self._raise_for_msg91_code(message)
            raise ValidationException(f"SMS gateway error: {message}")

        if data.get("type") != "success":
            message = str(data.get("message") or data)
            if message.isdigit():
                self._raise_for_msg91_code(message)
            raise ValidationException(f"SMS gateway error: {message}")

        request_id = data.get("request_id") or data.get("message") or "ok"
        return str(request_id)

    async def _send_msg91_flow(
        self,
        mobile_number: str,
        otp: str,
        *,
        flow_id: str | None = None,
        dlt_template_id: str | None = None,
        dlt_te_id: str | None = None,
    ) -> None:
        """MSG91 Flow API — DLT template + explicit sender (CP-AURUS-S)."""
        flow_id = (
            flow_id
            or settings.MSG91_FLOW_ID.strip()
            or settings.MSG91_OTP_TEMPLATE_ID.strip()
        )
        if not flow_id:
            raise ValidationException(
                "MSG91 Flow ID is not configured (error 400)."
            )

        headers = {
            "authkey": settings.MSG91_AUTH_KEY,
            "Content-Type": "application/json",
        }
        payload: dict = {
            "flow_id": flow_id,
            "sender": settings.SMS_SENDER_ID,
            "short_url": "0",
            "recipients": [
                {
                    "mobiles": f"91{mobile_number}",
                    # Aurum_Bank_Add_OTP template variable: ##OTP##
                    "OTP": otp,
                    "otp": otp,
                }
            ],
        }
        te_id = (dlt_te_id or settings.MSG91_DLT_TE_ID).strip()
        template_id = (dlt_template_id or settings.MSG91_DLT_TEMPLATE_ID).strip()
        if te_id:
            payload["DLT_TE_ID"] = te_id
        if template_id:
            payload["DLT_TEMPLATE_ID"] = template_id

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(_MSG91_FLOW_URL, headers=headers, json=payload)
            response.raise_for_status()
            try:
                data = response.json()
            except ValueError as exc:
                raise ValidationException(
                    "SMS gateway returned an invalid response."
                ) from exc

        request_id = self._ensure_msg91_json_success(data)
        logger.info(
            "msg91_flow_sent",
            mobile=mobile_number,
            request_id=request_id,
            sender=settings.SMS_SENDER_ID,
            flow_id=flow_id,
        )

    async def _send_msg91_otp_v5(
        self,
        mobile_number: str,
        otp: str | None = None,
        *,
        template_id: str | None = None,
        dlt_template_id: str | None = None,
        dlt_te_id: str | None = None,
        use_native_verify: bool | None = None,
        otp_length: int | None = None,
    ) -> None:
        """MSG91 v5 OTP — exact Postman payload (MSG91 generates OTP when otp omitted)."""
        template_id = (template_id or settings.MSG91_OTP_TEMPLATE_ID).strip()
        if not template_id:
            raise ValidationException(
                "MSG91 template ID is not configured (error 400)."
            )

        headers = {
            "authkey": settings.MSG91_AUTH_KEY,
            "Content-Type": "application/json",
        }
        payload: dict = {
            "template_id": template_id,
            "mobile": f"91{mobile_number}",
            "otp_length": otp_length or settings.SIGNUP_OTP_LENGTH,
        }
        te_id = (dlt_te_id or settings.MSG91_DLT_TE_ID).strip()
        dlt_id = (dlt_template_id or settings.MSG91_DLT_TEMPLATE_ID).strip()
        if te_id:
            payload["DLT_TE_ID"] = te_id
        if dlt_id:
            payload["DLT_TEMPLATE_ID"] = dlt_id
        native_verify = (
            settings.SIGNUP_OTP_USE_MSG91_VERIFY
            if use_native_verify is None
            else use_native_verify
        )
        if otp and not native_verify:
            payload["otp"] = otp

        url = settings.MSG91_OTP_URL.rstrip("/")
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            try:
                data = response.json()
            except ValueError as exc:
                raise ValidationException(
                    "SMS gateway returned an invalid response."
                ) from exc

        request_id = self._ensure_msg91_json_success(data)
        logger.info(
            "msg91_otp_v5_sent",
            mobile=mobile_number,
            request_id=request_id,
            template_id=template_id,
            sender=settings.SMS_SENDER_ID,
            response=data,
        )

    async def verify_msg91_otp(self, mobile_number: str, otp: str) -> None:
        """Verify OTP via MSG91 v5 API (matches Postman send flow)."""
        mobile = normalize_mobile(mobile_number)
        if not mobile:
            raise ValidationException("Registered mobile number is invalid.")
        headers = {
            "authkey": settings.MSG91_AUTH_KEY,
            "Content-Type": "application/json",
        }
        payload = {
            "mobile": f"91{mobile}",
            "otp": otp.strip(),
        }
        verify_url = settings.MSG91_OTP_URL.rstrip("/") + "/verify"
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(verify_url, headers=headers, json=payload)
            response.raise_for_status()
            try:
                data = response.json()
            except ValueError as exc:
                raise ValidationException(
                    "SMS gateway returned an invalid response."
                ) from exc

        if data.get("type") != "success":
            message = str(data.get("message") or data)
            if "not found" in message.lower() or "invalid" in message.lower():
                raise ValidationException("Invalid OTP. Please try again.")
            raise ValidationException(f"SMS gateway error: {message}")

        logger.info("msg91_otp_verified", mobile=mobile)

    async def _send_msg91_sendotp(
        self,
        mobile_number: str,
        otp: str,
        *,
        template_id: str | None = None,
        dlt_template_id: str | None = None,
        dlt_te_id: str | None = None,
    ) -> None:
        """SendOTP API fallback — template-driven."""
        template_id = (template_id or settings.MSG91_OTP_TEMPLATE_ID).strip()
        if not template_id:
            raise ValidationException(
                "MSG91 template ID is not configured (error 400)."
            )

        data: dict[str, str] = {
            "authkey": settings.MSG91_AUTH_KEY,
            "mobile": f"91{mobile_number}",
            "sender": settings.SMS_SENDER_ID,
            "otp": otp,
            "otp_expiry": str(settings.SIGNUP_OTP_EXPIRE_MINUTES),
            "template_id": template_id,
        }
        te_id = (dlt_te_id or settings.MSG91_DLT_TE_ID).strip()
        dlt_id = (dlt_template_id or settings.MSG91_DLT_TEMPLATE_ID).strip()
        if te_id:
            data["DLT_TE_ID"] = te_id
        if dlt_id:
            data["DLT_TEMPLATE_ID"] = dlt_id

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(_MSG91_SENDOTP_URL, data=data)
            response.raise_for_status()
            body = response.text.strip()

        request_id = self._ensure_msg91_json_or_text_success(body)
        logger.info(
            "msg91_sendotp_sent",
            mobile=mobile_number,
            request_id=request_id,
            sender=settings.SMS_SENDER_ID,
            template_id=template_id,
        )

    def _ensure_msg91_json_or_text_success(self, body: str) -> str:
        import json

        try:
            data = json.loads(body)
        except ValueError:
            return self._ensure_msg91_success(body)

        return self._ensure_msg91_json_success(data)

    def _parse_msg91_response(self, body: str) -> str:
        raw = body.strip()
        if re.fullmatch(r"[0-9a-fA-F]+", raw) and len(raw) % 2 == 0:
            try:
                decoded = bytes.fromhex(raw).decode("utf-8").strip()
                if decoded:
                    return decoded
            except (ValueError, UnicodeDecodeError):
                pass
        return raw

    def _ensure_msg91_success(self, body: str) -> str:
        parsed = self._parse_msg91_response(body)
        if parsed in _MSG91_ERROR_CODES:
            raise ValidationException(_MSG91_ERROR_CODES[parsed])
        if parsed.isdigit() and len(parsed) <= 3:
            self._raise_for_msg91_code(parsed)
        if "error" in parsed.lower() or "invalid" in parsed.lower():
            raise ValidationException(f"SMS gateway error: {parsed[:120]}")
        return parsed

    async def _send_msg91_sendhttp(
        self,
        mobile_number: str,
        message: str,
        *,
        dlt_template_id: str | None = None,
        dlt_te_id: str | None = None,
    ) -> None:
        te_id = (dlt_te_id or settings.MSG91_DLT_TE_ID).strip()
        dlt_id = (dlt_template_id or settings.MSG91_DLT_TEMPLATE_ID).strip()
        if not te_id or not dlt_id:
            raise ValidationException(
                "DLT Template ID and Entity ID are required for sendhttp (error 203/211). "
                "Add MSG91_DLT_TE_ID and MSG91_DLT_TEMPLATE_ID to backend/.env."
            )

        payload: dict[str, str] = {
            "authkey": settings.MSG91_AUTH_KEY,
            "mobiles": f"91{mobile_number}",
            "message": message,
            "sender": settings.SMS_SENDER_ID,
            "route": settings.SMS_ROUTE,
            "country": "91",
            "DLT_TE_ID": te_id,
            "DLT_TEMPLATE_ID": dlt_id,
        }

        url = settings.MSG91_SEND_URL.rstrip("/")
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, data=payload)
            response.raise_for_status()
            request_id = self._ensure_msg91_success(response.text)

        logger.info(
            "msg91_sendhttp_sent",
            mobile=mobile_number,
            request_id=request_id,
            sender=settings.SMS_SENDER_ID,
        )
