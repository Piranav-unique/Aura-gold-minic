import pytest

from app.services.sms import SmsService


def test_parse_msg91_hex_success_id():
    service = SmsService()
    parsed = service._parse_msg91_response("366678726b73564547733433")
    assert parsed == "6fxrksVEGs43"


def test_ensure_msg91_success_accepts_request_id():
    service = SmsService()
    assert service._ensure_msg91_success("6fxrksVEGs43") == "6fxrksVEGs43"


def test_ensure_msg91_raises_on_invalid_auth():
    service = SmsService()
    with pytest.raises(Exception) as exc:
        service._ensure_msg91_success("201")
    assert "authentication" in str(exc.value).lower()


def test_ensure_msg91_raises_on_template_error():
    service = SmsService()
    with pytest.raises(Exception) as exc:
        service._ensure_msg91_json_success(
            {"type": "error", "message": "400"}
        )
    assert "template" in str(exc.value).lower()


def test_ensure_msg91_raises_on_duplicate_otp():
    service = SmsService()
    with pytest.raises(Exception) as exc:
        service._ensure_msg91_json_success(
            {"type": "error", "message": "311"}
        )
    assert "duplicate" in str(exc.value).lower() or "10 seconds" in str(exc.value).lower()


def test_build_bank_link_otp_message_matches_dlt_template():
    service = SmsService()
    message = service.build_bank_link_otp_message("789455")
    assert message == (
        "Your OTP 789455 confirms bank account linking on AURUM GOLD & SILVERS. "
        "Do not share it with anyone."
    )


def test_bank_sms_channels_default_to_otp_sendotp(monkeypatch):
    monkeypatch.setattr("app.services.sms.settings.MSG91_BANK_SMS_CHANNELS", "")
    service = SmsService()
    assert service._bank_sms_channels() == ["otp", "sendotp"]
