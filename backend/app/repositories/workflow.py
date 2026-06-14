import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import asc, desc, func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.workflow import (
    WorkflowApprovalHistory,
    WorkflowComment,
    WorkflowEscalationRule,
    WorkflowRequest,
)
from app.repositories.base import BaseRepository

SORT_COLUMNS = {
    "request_number": WorkflowRequest.request_number,
    "title": WorkflowRequest.title,
    "state": WorkflowRequest.state,
    "request_type": WorkflowRequest.request_type,
    "created_at": WorkflowRequest.created_at,
    "submitted_at": WorkflowRequest.submitted_at,
    "pending_since": WorkflowRequest.pending_since,
}


class WorkflowRepository(BaseRepository[WorkflowRequest]):
    """Repository for workflow requests, history, comments, and escalation rules."""

    def __init__(self, db_session: AsyncSession):
        super().__init__(WorkflowRequest, db_session)

    def _apply_filters(
        self,
        query,
        search: Optional[str] = None,
        state: Optional[str] = None,
        request_type: Optional[str] = None,
        requester_id: Optional[uuid.UUID] = None,
        assignee_id: Optional[uuid.UUID] = None,
        mine_only: bool = False,
        current_user_id: Optional[uuid.UUID] = None,
    ):
        if search:
            pattern = f"%{search}%"
            query = query.where(
                or_(
                    WorkflowRequest.request_number.ilike(pattern),
                    WorkflowRequest.title.ilike(pattern),
                )
            )
        if state is not None:
            query = query.where(WorkflowRequest.state == state)
        if request_type is not None:
            query = query.where(WorkflowRequest.request_type == request_type)
        if requester_id is not None:
            query = query.where(WorkflowRequest.requester_id == requester_id)
        if assignee_id is not None:
            query = query.where(WorkflowRequest.assignee_id == assignee_id)
        if mine_only and current_user_id is not None:
            query = query.where(
                or_(
                    WorkflowRequest.requester_id == current_user_id,
                    WorkflowRequest.assignee_id == current_user_id,
                )
            )
        return query

    def _apply_sort(self, query, sort_by: str, sort_order: str):
        column = SORT_COLUMNS.get(sort_by, WorkflowRequest.created_at)
        direction = asc if sort_order == "asc" else desc
        return query.order_by(direction(column))

    async def get_with_details(
        self, request_id: uuid.UUID
    ) -> Optional[WorkflowRequest]:
        query = (
            select(WorkflowRequest)
            .options(
                selectinload(WorkflowRequest.requester),
                selectinload(WorkflowRequest.assignee),
                selectinload(WorkflowRequest.history).selectinload(
                    WorkflowApprovalHistory.actor
                ),
                selectinload(WorkflowRequest.history).selectinload(
                    WorkflowApprovalHistory.assignee
                ),
                selectinload(WorkflowRequest.comments).selectinload(
                    WorkflowComment.author
                ),
            )
            .where(WorkflowRequest.id == request_id)
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_for_update(self, request_id: uuid.UUID) -> Optional[WorkflowRequest]:
        query = (
            select(WorkflowRequest)
            .where(WorkflowRequest.id == request_id)
            .with_for_update()
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def list_filtered(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        state: Optional[str] = None,
        request_type: Optional[str] = None,
        requester_id: Optional[uuid.UUID] = None,
        assignee_id: Optional[uuid.UUID] = None,
        mine_only: bool = False,
        current_user_id: Optional[uuid.UUID] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> list[WorkflowRequest]:
        query = select(WorkflowRequest).options(
            selectinload(WorkflowRequest.requester),
            selectinload(WorkflowRequest.assignee),
        )
        query = self._apply_filters(
            query,
            search=search,
            state=state,
            request_type=request_type,
            requester_id=requester_id,
            assignee_id=assignee_id,
            mine_only=mine_only,
            current_user_id=current_user_id,
        )
        query = self._apply_sort(query, sort_by, sort_order)
        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def count_filtered(
        self,
        search: Optional[str] = None,
        state: Optional[str] = None,
        request_type: Optional[str] = None,
        requester_id: Optional[uuid.UUID] = None,
        assignee_id: Optional[uuid.UUID] = None,
        mine_only: bool = False,
        current_user_id: Optional[uuid.UUID] = None,
    ) -> int:
        query = select(func.count()).select_from(WorkflowRequest)
        query = self._apply_filters(
            query,
            search=search,
            state=state,
            request_type=request_type,
            requester_id=requester_id,
            assignee_id=assignee_id,
            mine_only=mine_only,
            current_user_id=current_user_id,
        )
        result = await self.db.execute(query)
        return int(result.scalar() or 0)

    async def next_request_number(self) -> str:
        today = datetime.now(timezone.utc).strftime("%Y%m%d")
        prefix = f"WR-{today}-"
        await self.db.execute(
            text("SELECT pg_advisory_xact_lock(hashtext(:lock_key))"),
            {"lock_key": f"workflow_request_number_{today}"},
        )
        query = select(func.max(WorkflowRequest.request_number)).where(
            WorkflowRequest.request_number.like(f"{prefix}%")
        )
        result = await self.db.execute(query)
        current_max = result.scalar()
        if current_max:
            seq = int(current_max.rsplit("-", 1)[-1]) + 1
        else:
            seq = 1
        return f"{prefix}{seq:04d}"

    async def add_history(
        self, entry: dict, commit: bool = False
    ) -> WorkflowApprovalHistory:
        return await self._create_model(WorkflowApprovalHistory, entry, commit=commit)

    async def add_comment(self, comment: dict, commit: bool = False) -> WorkflowComment:
        return await self._create_model(WorkflowComment, comment, commit=commit)

    async def _create_model(self, model, data: dict, commit: bool = True):
        obj = model(**data)
        self.db.add(obj)
        if commit:
            await self.db.commit()
            await self.db.refresh(obj)
        else:
            await self.db.flush()
        return obj

    async def list_pending_for_escalation(
        self, before: datetime
    ) -> list[WorkflowRequest]:
        query = (
            select(WorkflowRequest)
            .where(
                WorkflowRequest.state == "pending",
                WorkflowRequest.pending_since.isnot(None),
                WorkflowRequest.pending_since <= before,
            )
            .with_for_update(skip_locked=True)
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_escalation_rules(
        self, active_only: bool = True
    ) -> list[WorkflowEscalationRule]:
        query = select(WorkflowEscalationRule)
        if active_only:
            query = query.where(WorkflowEscalationRule.is_active.is_(True))
        query = query.order_by(
            WorkflowEscalationRule.request_type,
            WorkflowEscalationRule.escalation_level,
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def get_escalation_rule(
        self, rule_id: uuid.UUID
    ) -> Optional[WorkflowEscalationRule]:
        return await self.db.get(WorkflowEscalationRule, rule_id)

    async def create_escalation_rule(self, data: dict) -> WorkflowEscalationRule:
        return await self._create_model(WorkflowEscalationRule, data)

    async def update_escalation_rule(
        self, rule: WorkflowEscalationRule, data: dict
    ) -> WorkflowEscalationRule:
        return await self.update(rule, data)

    async def count_pending(self, assignee_id: Optional[uuid.UUID] = None) -> int:
        query = (
            select(func.count())
            .select_from(WorkflowRequest)
            .where(WorkflowRequest.state == "pending")
        )
        if assignee_id is not None:
            query = query.where(WorkflowRequest.assignee_id == assignee_id)
        result = await self.db.execute(query)
        return int(result.scalar() or 0)
