import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class PermissionCreate(BaseModel):
    """Schema for creating a permission."""

    name: str = Field(..., max_length=100, pattern=r"^[a-zA-Z0-9_:-]+$")
    description: Optional[str] = Field(None, max_length=255)


class PermissionResponse(BaseModel):
    """Schema representing permission query results."""

    id: uuid.UUID
    name: str
    description: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class RoleCreate(BaseModel):
    """Schema for creating a role."""

    name: str = Field(..., max_length=100)
    description: Optional[str] = Field(None, max_length=255)


class RoleUpdate(BaseModel):
    """Schema for updating a role's attributes."""

    name: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = Field(None, max_length=255)


class RoleResponse(BaseModel):
    """Schema representing role details, including nested permissions."""

    id: uuid.UUID
    name: str
    description: Optional[str] = None
    permissions: List[PermissionResponse] = []
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class UserRolesResponse(BaseModel):
    """Schema representing a user's details and mapped roles."""

    id: uuid.UUID
    email: str
    roles: List[RoleResponse] = []

    model_config = {"from_attributes": True}
