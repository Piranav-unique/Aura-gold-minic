import pytest
from app.core.email_utils import is_placeholder_email
from app.schemas.profile import ProfileUpdate
from pydantic import ValidationError


def test_is_placeholder_email_identifies_placeholders():
    assert is_placeholder_email(None) is True
    assert is_placeholder_email("") is True
    assert is_placeholder_email("   ") is True
    assert is_placeholder_email("invalid-email") is True
    assert is_placeholder_email("user@") is True
    assert is_placeholder_email("@gmail.com") is True

    # System generated signup placeholder
    assert is_placeholder_email("9442733154@mobile.agsgold.com") is True
    assert is_placeholder_email("7010196231@mobile.agsgold.com") is True
    assert is_placeholder_email("user@agsgold.com") is True

    # User-created phone or agsgold placeholder pattern
    assert is_placeholder_email("phoneno.agsgold@gmail.com") is True
    assert is_placeholder_email("9442733154.agsgold@gmail.com") is True
    assert is_placeholder_email("agsgold.user@gmail.com") is True

    # Phone number as local part
    assert is_placeholder_email("9442733154@gmail.com") is True
    # Non-gmail addresses
    assert is_placeholder_email("nathan@student.tce.edu") is True
    assert is_placeholder_email("john.doe@company.in") is True
    assert is_placeholder_email("user@yahoo.com") is True


def test_is_placeholder_email_accepts_valid_personal_emails():
    assert is_placeholder_email("piranav.richu2006@gmail.com") is False
    assert is_placeholder_email("name.someone@gmail.com") is False
    assert is_placeholder_email("aurumgoldsilvers@gmail.com") is False


def test_profile_update_schema_rejects_placeholder_email():
    with pytest.raises(ValidationError):
        ProfileUpdate(email="9442733154@mobile.agsgold.com")

    with pytest.raises(ValidationError):
        ProfileUpdate(email="phoneno.agsgold@gmail.com")

    with pytest.raises(ValidationError):
        ProfileUpdate(email="7010196231@gmail.com")

    with pytest.raises(ValidationError):
        ProfileUpdate(email="nathan@student.tce.edu")

    with pytest.raises(ValidationError):
        ProfileUpdate(email="user@yahoo.com")

    # Valid personal Gmail passes
    valid = ProfileUpdate(email="piranav.richu2006@gmail.com")
    assert valid.email == "piranav.richu2006@gmail.com"
