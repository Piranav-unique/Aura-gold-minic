from __future__ import annotations

import uuid
from typing import Optional

from pydantic import BaseModel, Field


class OrganizationProfilePublicResponse(BaseModel):
    organization_name: str
    admin_name: str
    support_contact_number: str
    support_email: Optional[str] = None
    office_address: Optional[str] = None
    business_hours: Optional[str] = None
    emergency_contact: Optional[str] = None


class OrganizationProfileResponse(OrganizationProfilePublicResponse):
    id: uuid.UUID
    business_gst: Optional[str] = None
    business_pan: Optional[str] = None
    logo_url: Optional[str] = None
    upi_id: Optional[str] = None
    google_pay_id: Optional[str] = None
    phonepe_id: Optional[str] = None
    paytm_id: Optional[str] = None
    bank_name: Optional[str] = None
    account_number: Optional[str] = None
    ifsc: Optional[str] = None
    qr_code_image: Optional[str] = None
    updated_by: Optional[uuid.UUID] = None

    model_config = {"from_attributes": True}


class OrganizationProfileUpdate(BaseModel):
    organization_name: str = Field(..., min_length=2, max_length=200)
    admin_name: str = Field(..., min_length=2, max_length=200)
    support_contact_number: str = Field(..., min_length=8, max_length=20)
    support_email: Optional[str] = Field(default=None, max_length=255)
    office_address: Optional[str] = Field(default=None, max_length=2000)
    business_gst: Optional[str] = Field(default=None, max_length=32)
    business_pan: Optional[str] = Field(default=None, max_length=16)
    logo_url: Optional[str] = None
    upi_id: Optional[str] = Field(default=None, max_length=100)
    google_pay_id: Optional[str] = Field(default=None, max_length=100)
    phonepe_id: Optional[str] = Field(default=None, max_length=100)
    paytm_id: Optional[str] = Field(default=None, max_length=100)
    bank_name: Optional[str] = Field(default=None, max_length=200)
    account_number: Optional[str] = Field(default=None, max_length=32)
    ifsc: Optional[str] = Field(default=None, max_length=11)
    qr_code_image: Optional[str] = None
    business_hours: Optional[str] = Field(default=None, max_length=200)
    emergency_contact: Optional[str] = Field(default=None, max_length=20)
