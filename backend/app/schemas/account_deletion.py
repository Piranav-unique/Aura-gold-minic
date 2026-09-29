import uuid
from datetime import datetime
from decimal import Decimal
from typing import List, Optional

from pydantic import BaseModel, Field


class CreateAccountDeletionRequest(BaseModel):
    reason: Optional[str] = Field(None, max_length=1000)


class AccountDeletionDecisionRequest(BaseModel):
    comment: Optional[str] = Field(None, max_length=1000)


class AccountDeletionRequestResponse(BaseModel):
    id: uuid.UUID
    user_id: Optional[uuid.UUID] = None
    user_email: str
    user_mobile: Optional[str] = None
    user_name: Optional[str] = None
    status: str
    reason: Optional[str] = None
    gold_balance_grams: Decimal
    silver_balance_grams: Decimal
    admin_comment: Optional[str] = None
    reviewed_by_id: Optional[uuid.UUID] = None
    reviewed_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class AccountDeletionListResponse(BaseModel):
    items: List[AccountDeletionRequestResponse]
    total: int
    skip: int
    limit: int
