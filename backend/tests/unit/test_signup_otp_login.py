from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.exceptions import ValidationException
from app.services.signup_otp import SignupOtpService


@pytest.mark.asyncio
async def test_admin_mobile_cannot_log_in_with_default_otp():
    """The admin number must go through a real OTP challenge like any user."""
    otp_repo = MagicMock()
    otp_repo.get_latest_active = AsyncMock(return_value=None)
    sms = MagicMock()
    sms.uses_msg91_native_otp = False
    service = SignupOtpService(otp_repo, MagicMock(), sms)

    with pytest.raises(ValidationException, match="Send OTP"):
        await service.consume_login_otp("9943795005", "123456")
    otp_repo.get_latest_active.assert_awaited_once()
