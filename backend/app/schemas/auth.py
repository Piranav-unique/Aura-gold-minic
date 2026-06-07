import uuid
from datetime import datetime
from typing import Optional
import re
from pydantic import BaseModel, field_validator

EMAIL_REGEX = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")


class LoginRequest(BaseModel):
    """Schema for user login credentials request."""

    email: str
    password: str

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
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    is_active: bool
    is_superuser: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
