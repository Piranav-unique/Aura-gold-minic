from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.core.exceptions import ValidationException
from app.utils.mobile import normalize_mobile

_IFSC_PATTERN = r"^[A-Z]{4}0[A-Z0-9]{6}$"


class BankAccountResponse(BaseModel):
    id: UUID
    account_holder_name: str
    account_number_masked: str
    ifsc: str
    bank_name: str
    branch_name: str
    account_type: str
    is_primary: bool
    verified_at: datetime

    model_config = {"from_attributes": True}


class BankLinkInitiateRequest(BaseModel):
    account_holder_name: str = Field(..., min_length=2, max_length=200)
    account_number: str = Field(..., min_length=8, max_length=18)
    ifsc: str = Field(..., min_length=11, max_length=11)
    bank_name: str = Field(..., min_length=2, max_length=200)
    branch_name: str = Field(..., min_length=2, max_length=200)
    account_type: str = Field(default="savings", pattern=r"^(savings|current)$")
    bank_registered_mobile: str = Field(
        ...,
        min_length=10,
        max_length=15,
        description="10-digit mobile number registered with the bank account",
    )

    @field_validator("account_holder_name", "bank_name", "branch_name")
    @classmethod
    def strip_text(cls, value: str) -> str:
        return " ".join(value.strip().split())

    @field_validator("account_number")
    @classmethod
    def validate_account_number(cls, value: str) -> str:
        digits = "".join(ch for ch in value if ch.isdigit())
        if len(digits) < 8:
            raise ValueError("Enter a valid account number.")
        return digits

    @field_validator("ifsc")
    @classmethod
    def validate_ifsc(cls, value: str) -> str:
        code = value.strip().upper()
        import re

        if not re.fullmatch(_IFSC_PATTERN, code):
            raise ValueError("Enter a valid IFSC code.")
        return code

    @field_validator("bank_registered_mobile")
    @classmethod
    def validate_bank_registered_mobile(cls, value: str) -> str:
        try:
            return normalize_mobile(value)
        except ValidationException as exc:
            raise ValueError(str(exc)) from exc


class BankLinkVerifyRequest(BaseModel):
    otp: str = Field(..., min_length=6, max_length=6)


class BankLinkInitiateResponse(BaseModel):
    message: str
    mobile_last4: Optional[str] = None
    dev_otp_hint: Optional[str] = None


class IfscLookupResponse(BaseModel):
    bank: str
    branch: str
    ifsc: str
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
