import uuid
from datetime import datetime
from typing import Optional
import re
from pydantic import BaseModel, Field, field_validator, model_validator

EMAIL_REGEX = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")
_INDIAN_MOBILE = re.compile(r"^[6-9]\d{9}$")


def _normalize_mobile_input(raw: str) -> str:
    digits = re.sub(r"\D", "", raw or "")
    if digits.startswith("91") and len(digits) == 12:
        digits = digits[2:]
    return digits


def _validate_device_id_field(v: str) -> str:
    from app.utils.device_binding import validate_device_id

    return validate_device_id(v)


class LoginRequest(BaseModel):
    """Schema for user login credentials request."""

    password: str
    email: Optional[str] = None
    mobile_number: Optional[str] = None

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        if not EMAIL_REGEX.match(v):
            raise ValueError("Invalid email format")
        return v.lower()

    @field_validator("mobile_number")
    @classmethod
    def validate_mobile(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        digits = _normalize_mobile_input(v)
        if not _INDIAN_MOBILE.match(digits):
            raise ValueError("Invalid mobile number")
        return digits

    @model_validator(mode="after")
    def require_identifier(self) -> "LoginRequest":
        if not self.email and not self.mobile_number:
            raise ValueError("Email or mobile number is required")
        return self


class SignupOtpSendRequest(BaseModel):
    mobile_number: str

    @field_validator("mobile_number")
    @classmethod
    def validate_mobile(cls, v: str) -> str:
        digits = _normalize_mobile_input(v)
        if not _INDIAN_MOBILE.match(digits):
            raise ValueError("Invalid mobile number")
        return digits


class LoginOtpSendRequest(BaseModel):
    mobile_number: str
    device_id: str = Field(..., min_length=36, max_length=36)

    @field_validator("mobile_number")
    @classmethod
    def validate_mobile(cls, v: str) -> str:
        digits = _normalize_mobile_input(v)
        if not _INDIAN_MOBILE.match(digits):
            raise ValueError("Invalid mobile number")
        return digits

    @field_validator("device_id")
    @classmethod
    def validate_device_id(cls, v: str) -> str:
        return _validate_device_id_field(v)


class MobileLoginRequest(BaseModel):
    """End-user login with mobile OTP."""

    mobile_number: str
    otp: str = Field(..., min_length=4, max_length=6)
    device_id: str = Field(..., min_length=36, max_length=36)

    @field_validator("mobile_number")
    @classmethod
    def validate_mobile(cls, v: str) -> str:
        digits = _normalize_mobile_input(v)
        if not _INDIAN_MOBILE.match(digits):
            raise ValueError("Invalid mobile number")
        return digits

    @field_validator("device_id")
    @classmethod
    def validate_device_id(cls, v: str) -> str:
        return _validate_device_id_field(v)


class TrustedMobileLoginRequest(BaseModel):
    """First sign-in on the registration device without OTP."""

    mobile_number: str
    device_id: str = Field(..., min_length=36, max_length=36)

    @field_validator("mobile_number")
    @classmethod
    def validate_mobile(cls, v: str) -> str:
        digits = _normalize_mobile_input(v)
        if not _INDIAN_MOBILE.match(digits):
            raise ValueError("Invalid mobile number")
        return digits

    @field_validator("device_id")
    @classmethod
    def validate_device_id(cls, v: str) -> str:
        return _validate_device_id_field(v)


class SignupOtpVerifyRequest(BaseModel):
    mobile_number: str
    otp: str = Field(..., min_length=4, max_length=6)

    @field_validator("mobile_number")
    @classmethod
    def validate_mobile(cls, v: str) -> str:
        digits = _normalize_mobile_input(v)
        if not _INDIAN_MOBILE.match(digits):
            raise ValueError("Invalid mobile number")
        return digits


class RegisterRequest(BaseModel):
    """Schema for public end-user self-registration with mobile OTP."""

    name: str = Field(..., min_length=2, max_length=200)
    mobile_number: str
    otp: str = Field(..., min_length=4, max_length=6)
    email: str
    password: str = Field(..., min_length=8)
    referral_code: Optional[str] = Field(default=None, max_length=16)
    referral_scheme_grams: Optional[int] = None
    device_id: str = Field(..., min_length=36, max_length=36)

    @field_validator("device_id")
    @classmethod
    def validate_device_id(cls, v: str) -> str:
        return _validate_device_id_field(v)

    @field_validator("referral_code")
    @classmethod
    def normalize_referral_code(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        cleaned = v.strip().upper()
        return cleaned or None

    @field_validator("referral_scheme_grams")
    @classmethod
    def validate_referral_scheme(cls, v: Optional[int]) -> Optional[int]:
        if v is None:
            return v
        if v not in {1, 5, 10}:
            raise ValueError("Referral scheme must be 1, 5, or 10 grams")
        return v

    @field_validator("mobile_number")
    @classmethod
    def validate_mobile(cls, v: str) -> str:
        digits = _normalize_mobile_input(v)
        if not _INDIAN_MOBILE.match(digits):
            raise ValueError("Invalid mobile number")
        return digits

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not EMAIL_REGEX.match(v):
            raise ValueError("Invalid email format")
        return v.lower()


class RefreshRequest(BaseModel):
    """Schema for token refresh request."""

    refresh_token: str


class Token(BaseModel):
    """Schema representing the pair of JWT access and refresh tokens returned."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenPayload(BaseModel):
    """Schema representing the decoded JWT payload."""

    sub: str
    type: str
    jti: Optional[str] = None
    exp: int


class UserResponse(BaseModel):
    """Schema representing user public/profile info returned from routes."""

    id: uuid.UUID
    email: str
    mobile_number: Optional[str] = None
    mobile_verified: bool = False
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    is_active: bool
    is_superuser: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
