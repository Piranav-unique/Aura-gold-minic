import uuid
from datetime import datetime
from typing import List, Optional
import re
from pydantic import BaseModel, Field, field_validator
from app.schemas.rbac import RoleResponse
from app.schemas.audit_log import AuditLogResponse

EMAIL_REGEX = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")


class ProfileUpdate(BaseModel):
    first_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, max_length=100)
    email: Optional[str] = None
    current_password: Optional[str] = Field(
        None, description="Required when changing email"
    )

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        if not EMAIL_REGEX.match(v):
            raise ValueError("Invalid email format")
        return v.lower()


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8)


class AvatarUploadRequest(BaseModel):
    avatar_base64: str
    content_type: str = Field(..., pattern=r"^image/(jpeg|png|gif|webp)$")


class UserSettingsResponse(BaseModel):
    locale: str
    notification_email_enabled: bool
    notification_push_enabled: bool
    notification_security_alerts: bool
    notification_system_updates: bool

    model_config = {"from_attributes": True}


class UserSettingsUpdate(BaseModel):
    locale: Optional[str] = Field(None, max_length=10)
    notification_email_enabled: Optional[bool] = None
    notification_push_enabled: Optional[bool] = None
    notification_security_alerts: Optional[bool] = None
    notification_system_updates: Optional[bool] = None


class ProfileResponse(BaseModel):
    id: uuid.UUID
    email: str
    mobile_number: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    is_active: bool
    is_superuser: bool
    roles: List[RoleResponse] = []
    has_avatar: bool = False
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ProfileActivityResponse(BaseModel):
    items: List[AuditLogResponse]
    total: int


class AadhaarOtpRequest(BaseModel):
    aadhaar_number: str = Field(..., min_length=12, max_length=14)

    @field_validator("aadhaar_number")
    @classmethod
    def validate_aadhaar(cls, v: str) -> str:
        digits = re.sub(r"\D", "", v)
        if len(digits) != 12:
            raise ValueError("Enter a valid 12-digit Aadhaar number")
        return digits


class AadhaarOtpResponse(BaseModel):
    reference_id: str
    message: str = "OTP sent to your Aadhaar-linked mobile number."
    registered_mobile_masked: Optional[str] = None


class AadhaarVerifyRequest(BaseModel):
    reference_id: str
    otp: str = Field(..., min_length=6, max_length=6)
    aadhaar_number: str = Field(..., min_length=12, max_length=14)

    @field_validator("aadhaar_number")
    @classmethod
    def validate_aadhaar(cls, v: str) -> str:
        digits = re.sub(r"\D", "", v)
        if len(digits) != 12:
            raise ValueError("Enter a valid 12-digit Aadhaar number")
        return digits


class PanLinkVerifyRequest(BaseModel):
    pan_number: str = Field(..., min_length=10, max_length=10)

    @field_validator("pan_number")
    @classmethod
    def validate_pan(cls, v: str) -> str:
        normalized = v.strip().upper()
        if not re.match(r"^[A-Z]{5}[0-9]{4}[A-Z]$", normalized):
            raise ValueError("Enter a valid PAN number (e.g. ABCDE1234F)")
        return normalized


class KycGovernmentProfile(BaseModel):
    full_name: Optional[str] = None
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    care_of: Optional[str] = None
    full_address: Optional[str] = None
    state: Optional[str] = None
    district: Optional[str] = None
    pincode: Optional[str] = None
    aadhaar_last4: Optional[str] = None
    aadhaar_linked_mobile_masked: Optional[str] = None
    pan_number_masked: Optional[str] = None
    pan_category: Optional[str] = None
    pan_status: Optional[str] = None
    name_as_per_pan_match: Optional[bool] = None
    date_of_birth_match: Optional[bool] = None
    aadhaar_seeding_status: Optional[str] = None
    verified_at: Optional[str] = None


class KycStatusResponse(BaseModel):
    kyc_status: str
    aadhaar_last4: Optional[str] = None
    pan_last4: Optional[str] = None
    registered_mobile_masked: Optional[str] = None
    message: Optional[str] = None
    profile: Optional[KycGovernmentProfile] = None
