import uuid
from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field

WorkflowState = Literal["draft", "pending", "approved", "rejected"]
WorkflowRequestType = Literal["general", "transaction", "inventory", "customer"]
WorkflowHistoryAction = Literal[
    "created", "submitted", "assigned", "approved", "rejected", "escalated"
]
WorkflowSortField = Literal[
    "request_number",
    "title",
    "state",
    "request_type",
    "created_at",
    "submitted_at",
    "pending_since",
]
SortOrder = Literal["asc", "desc"]


class WorkflowUserSummary(BaseModel):
    id: uuid.UUID
    email: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None

    model_config = {"from_attributes": True}

    @property
    def display_name(self) -> str:
        parts = [p for p in (self.first_name, self.last_name) if p]
        return " ".join(parts) if parts else self.email


class WorkflowHistoryEntry(BaseModel):
    id: uuid.UUID
    actor_id: Optional[uuid.UUID] = None
    actor: Optional[WorkflowUserSummary] = None
    action: str
    comment: Optional[str] = None
    from_state: Optional[str] = None
    to_state: Optional[str] = None
    assignee_id: Optional[uuid.UUID] = None
    assignee: Optional[WorkflowUserSummary] = None
    escalation_level: int
    created_at: datetime

    model_config = {"from_attributes": True}


class WorkflowCommentResponse(BaseModel):
    id: uuid.UUID
    author_id: uuid.UUID
    author: Optional[WorkflowUserSummary] = None
    body: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class WorkflowRequestCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=5000)
    request_type: WorkflowRequestType = "general"
    entity_type: Optional[str] = Field(None, max_length=50)
    entity_id: Optional[uuid.UUID] = None
    payload: Optional[dict[str, Any]] = None
    assignee_id: Optional[uuid.UUID] = None


class WorkflowRequestUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=5000)
    request_type: Optional[WorkflowRequestType] = None
    entity_type: Optional[str] = Field(None, max_length=50)
    entity_id: Optional[uuid.UUID] = None
    payload: Optional[dict[str, Any]] = None


class WorkflowSubmitRequest(BaseModel):
    assignee_id: Optional[uuid.UUID] = None
    comment: Optional[str] = Field(None, max_length=2000)


class WorkflowAssignRequest(BaseModel):
    assignee_id: uuid.UUID
    comment: Optional[str] = Field(None, max_length=2000)


class WorkflowDecisionRequest(BaseModel):
    comment: Optional[str] = Field(None, max_length=2000)


class WorkflowCommentCreate(BaseModel):
    body: str = Field(..., min_length=1, max_length=5000)


class WorkflowRequestSummary(BaseModel):
    id: uuid.UUID
    request_number: str
    title: str
    description: Optional[str] = None
    request_type: str
    state: str
    requester_id: uuid.UUID
    requester: Optional[WorkflowUserSummary] = None
    assignee_id: Optional[uuid.UUID] = None
    assignee: Optional[WorkflowUserSummary] = None
    entity_type: Optional[str] = None
    entity_id: Optional[uuid.UUID] = None
    escalation_level: int
    pending_since: Optional[datetime] = None
    submitted_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class WorkflowRequestDetailResponse(WorkflowRequestSummary):
    payload: Optional[dict[str, Any]] = None
    history: list[WorkflowHistoryEntry] = []
    comments: list[WorkflowCommentResponse] = []


class WorkflowEscalationRuleCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    request_type: str = Field(default="*", max_length=50)
    hours_until_escalation: int = Field(..., gt=0, le=8760)
    target_permission: str = Field(..., min_length=1, max_length=100)
    escalation_level: int = Field(default=0, ge=0)
    is_active: bool = True


class WorkflowEscalationRuleUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    request_type: Optional[str] = Field(None, max_length=50)
    hours_until_escalation: Optional[int] = Field(None, gt=0, le=8760)
    target_permission: Optional[str] = Field(None, min_length=1, max_length=100)
    escalation_level: Optional[int] = Field(None, ge=0)
    is_active: Optional[bool] = None


class WorkflowEscalationRuleResponse(BaseModel):
    id: uuid.UUID
    name: str
    request_type: str
    hours_until_escalation: int
    target_permission: str
    escalation_level: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class WorkflowEscalationResult(BaseModel):
    escalated_count: int
    request_ids: list[uuid.UUID]
