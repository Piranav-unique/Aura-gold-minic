from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.config import settings
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

    for mobile in (settings.ADMIN_MOBILE_NUMBER or "9943795005", "9943795005"):
        with pytest.raises(ValidationException):
            await service.consume_login_otp(mobile, "123456")
    assert otp_repo.get_latest_active.await_count == 2
