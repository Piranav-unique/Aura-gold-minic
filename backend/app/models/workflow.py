from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class WorkflowRequest(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Approval request with draft → pending → approved/rejected lifecycle."""

    __tablename__ = "workflow_requests"

    request_number: Mapped[str] = mapped_column(String(40), nullable=False, unique=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    request_type: Mapped[str] = mapped_column(
        String(50), nullable=False, default="general"
    )
    state: Mapped[str] = mapped_column(String(20), nullable=False, default="draft")
    requester_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    assignee_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    entity_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    entity_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    payload: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    escalation_level: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    pending_since: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    submitted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    resolved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    requester: Mapped["User"] = relationship("User", foreign_keys=[requester_id])
    assignee: Mapped["User | None"] = relationship("User", foreign_keys=[assignee_id])
    history: Mapped[list["WorkflowApprovalHistory"]] = relationship(
        "WorkflowApprovalHistory",
        back_populates="request",
        cascade="all, delete-orphan",
        order_by="WorkflowApprovalHistory.created_at",
    )
    comments: Mapped[list["WorkflowComment"]] = relationship(
        "WorkflowComment",
        back_populates="request",
        cascade="all, delete-orphan",
        order_by="WorkflowComment.created_at",
    )

    __table_args__ = (
        Index("ix_workflow_requests_state", "state"),
        Index("ix_workflow_requests_request_type", "request_type"),
        Index("ix_workflow_requests_requester_id", "requester_id"),
        Index("ix_workflow_requests_assignee_id", "assignee_id"),
        Index("ix_workflow_requests_pending_since", "pending_since"),
        Index("ix_workflow_requests_created_at", "created_at"),
        CheckConstraint(
            "state IN ('draft', 'pending', 'approved', 'rejected')",
            name="ck_workflow_requests_state",
        ),
        CheckConstraint(
            "request_type IN ('general', 'transaction', 'inventory', 'customer')",
            name="ck_workflow_requests_type",
        ),
    )


class WorkflowApprovalHistory(Base, UUIDPrimaryKeyMixin):
    """Immutable approval history entry for audit trail."""

    __tablename__ = "workflow_approval_history"

    request_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("workflow_requests.id", ondelete="CASCADE"),
        nullable=False,
    )
    actor_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    action: Mapped[str] = mapped_column(String(30), nullable=False)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    from_state: Mapped[str | None] = mapped_column(String(20), nullable=True)
    to_state: Mapped[str | None] = mapped_column(String(20), nullable=True)
    assignee_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    escalation_level: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("now()"), nullable=False
    )

    request: Mapped["WorkflowRequest"] = relationship(
        "WorkflowRequest", back_populates="history"
    )
    actor: Mapped["User | None"] = relationship("User", foreign_keys=[actor_id])
    assignee: Mapped["User | None"] = relationship("User", foreign_keys=[assignee_id])

    __table_args__ = (
        Index("ix_workflow_approval_history_request_id", "request_id"),
        Index("ix_workflow_approval_history_created_at", "created_at"),
        CheckConstraint(
            "action IN ('created', 'submitted', 'assigned', 'approved', 'rejected', 'escalated')",
            name="ck_workflow_approval_history_action",
        ),
    )


class WorkflowComment(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """User comment on a workflow request."""

    __tablename__ = "workflow_comments"

    request_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("workflow_requests.id", ondelete="CASCADE"),
        nullable=False,
    )
    author_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    body: Mapped[str] = mapped_column(Text, nullable=False)

    request: Mapped["WorkflowRequest"] = relationship(
        "WorkflowRequest", back_populates="comments"
    )
    author: Mapped["User"] = relationship("User")

    __table_args__ = (
        Index("ix_workflow_comments_request_id", "request_id"),
        Index("ix_workflow_comments_created_at", "created_at"),
    )


class WorkflowEscalationRule(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Configurable escalation rule for pending approval requests."""

    __tablename__ = "workflow_escalation_rules"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    request_type: Mapped[str] = mapped_column(String(50), nullable=False, default="*")
    hours_until_escalation: Mapped[int] = mapped_column(Integer, nullable=False)
    target_permission: Mapped[str] = mapped_column(String(100), nullable=False)
    escalation_level: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_active: Mapped[bool] = mapped_column(default=True, nullable=False)

    __table_args__ = (
        Index("ix_workflow_escalation_rules_request_type", "request_type"),
        Index("ix_workflow_escalation_rules_is_active", "is_active"),
        CheckConstraint(
            "hours_until_escalation > 0",
            name="ck_workflow_escalation_rules_hours_pos",
        ),
        CheckConstraint(
            "escalation_level >= 0",
            name="ck_workflow_escalation_rules_level_nonneg",
        ),
    )
