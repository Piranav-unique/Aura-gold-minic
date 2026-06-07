import uuid
from datetime import datetime
from typing import List, Optional
import re
from pydantic import BaseModel, Field, field_validator
from app.schemas.rbac import RoleResponse

EMAIL_REGEX = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")


class UserCreate(BaseModel):
    """Schema for creating a new user with password and roles."""

    email: str
    password: str = Field(..., min_length=8)
    first_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, max_length=100)
    is_active: bool = True
    is_superuser: bool = False
    roles: Optional[List[uuid.UUID]] = None

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not EMAIL_REGEX.match(v):
            raise ValueError("Invalid email format")
        return v.lower()


class UserUpdate(BaseModel):
    """Schema for updating an existing user's attributes."""

    email: Optional[str] = None
    password: Optional[str] = Field(None, min_length=8)
    first_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, max_length=100)
    is_active: Optional[bool] = None
    is_superuser: Optional[bool] = None
    roles: Optional[List[uuid.UUID]] = None

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        if not EMAIL_REGEX.match(v):
            raise ValueError("Invalid email format")
        return v.lower()


class UserDetailResponse(BaseModel):
    """Detailed user schema returned by the APIs, containing nested roles."""

    id: uuid.UUID
    email: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    is_active: bool
    is_superuser: bool
    roles: List[RoleResponse] = []
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
