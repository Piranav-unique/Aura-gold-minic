import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.core import audit_actions
from app.core.exceptions import (
    ForbiddenException,
    NotFoundException,
    ValidationException,
)
from app.core.permissions import user_has_permission
from app.models.user import User
from app.models.workflow import WorkflowEscalationRule, WorkflowRequest
from app.repositories.user import UserRepository
from app.repositories.workflow import WorkflowRepository
from app.schemas.workflow import (
    WorkflowAssignRequest,
    WorkflowCommentCreate,
    WorkflowDecisionRequest,
    WorkflowEscalationResult,
    WorkflowEscalationRuleCreate,
    WorkflowEscalationRuleResponse,
    WorkflowEscalationRuleUpdate,
    WorkflowRequestCreate,
    WorkflowRequestDetailResponse,
    WorkflowRequestSummary,
    WorkflowRequestUpdate,
    WorkflowSubmitRequest,
)
from app.services.audit import AuditService
from app.services.notification import NotificationService

TERMINAL_STATES = {"approved", "rejected"}


class WorkflowService:
    """Workflow and approval engine with escalation support."""

    def __init__(
        self,
        workflow_repo: WorkflowRepository,
        user_repo: UserRepository,
        audit_service: Optional[AuditService] = None,
        notification_service: Optional[NotificationService] = None,
    ):
        self.workflow_repo = workflow_repo
        self.user_repo = user_repo
        self.audit_service = audit_service
        self.notification_service = notification_service

    @staticmethod
    def _can_view_all_requests(user: User) -> bool:
        if user.is_superuser:
            return True
        return user_has_permission(user, "workflow.approve") or user_has_permission(
            user, "workflow.manage"
        )

    @staticmethod
    def _ensure_request_access(user: User, request: WorkflowRequest) -> None:
        if WorkflowService._can_view_all_requests(user):
            return
        if request.requester_id != user.id and request.assignee_id != user.id:
            raise ForbiddenException("You do not have access to this workflow request")

    def _to_summary(self, request: WorkflowRequest) -> WorkflowRequestSummary:
        return WorkflowRequestSummary.model_validate(request)

    def _to_detail(self, request: WorkflowRequest) -> WorkflowRequestDetailResponse:
        return WorkflowRequestDetailResponse.model_validate(request)

    async def _validate_user(self, user_id: uuid.UUID) -> None:
        user = await self.user_repo.get(user_id)
        if not user or user.is_deleted or not user.is_active:
            raise NotFoundException("User not found or inactive")

    async def _find_default_assignee(
        self, exclude_user_id: Optional[uuid.UUID] = None
    ) -> Optional[uuid.UUID]:
        candidates = await self.user_repo.get_user_ids_with_permission(
            "workflow.approve"
        )
        for uid in candidates:
            if exclude_user_id and uid == exclude_user_id:
                continue
            return uid
        return None

    async def _log_audit(
        self,
        action: str,
        user_id: uuid.UUID,
        request: WorkflowRequest,
        metadata: Optional[dict] = None,
    ) -> None:
        if not self.audit_service:
            return
        payload = {
            "request_number": request.request_number,
            "title": request.title,
            "state": request.state,
            "request_type": request.request_type,
        }
        if metadata:
            payload.update(metadata)
        await self.audit_service.log_action(
            user_id=user_id,
            action=action,
            entity_type="WorkflowRequest",
            entity_id=str(request.id),
            metadata=payload,
        )

    async def _notify(
        self,
        user_id: uuid.UUID,
        title: str,
        message: str,
        metadata: Optional[dict] = None,
    ) -> None:
        if not self.notification_service:
            return
        await self.notification_service.create_notification(
            user_id=user_id,
            title=title,
            message=message,
            category=NotificationService.CATEGORY_SYSTEM,
            metadata=metadata,
        )

    async def _record_history(
        self,
        request: WorkflowRequest,
        actor_id: Optional[uuid.UUID],
        action: str,
        from_state: Optional[str],
        to_state: Optional[str],
        comment: Optional[str] = None,
        assignee_id: Optional[uuid.UUID] = None,
        escalation_level: Optional[int] = None,
    ) -> None:
        await self.workflow_repo.add_history(
            {
                "request_id": request.id,
                "actor_id": actor_id,
                "action": action,
                "comment": comment,
                "from_state": from_state,
                "to_state": to_state,
                "assignee_id": assignee_id,
                "escalation_level": escalation_level
                if escalation_level is not None
                else request.escalation_level,
            },
            commit=False,
        )

    async def create_request(
        self,
        data: WorkflowRequestCreate,
        performing_user_id: uuid.UUID,
    ) -> WorkflowRequestDetailResponse:
        if data.assignee_id:
            await self._validate_user(data.assignee_id)

        request_number = await self.workflow_repo.next_request_number()
        request = await self.workflow_repo.create(
            {
                "request_number": request_number,
                "title": data.title,
                "description": data.description,
                "request_type": data.request_type,
                "state": "draft",
                "requester_id": performing_user_id,
                "assignee_id": data.assignee_id,
                "entity_type": data.entity_type,
                "entity_id": data.entity_id,
                "payload": data.payload,
            },
            commit=False,
        )
        await self.workflow_repo.db.flush()
        await self._record_history(
            request,
            performing_user_id,
            "created",
            None,
            "draft",
        )
        await self.workflow_repo.db.commit()
        await self.workflow_repo.db.refresh(request)
        await self._log_audit(
            audit_actions.WORKFLOW_CREATE, performing_user_id, request
        )
        loaded = await self.workflow_repo.get_with_details(request.id)
        return self._to_detail(loaded or request)

    async def update_request(
        self,
        request_id: uuid.UUID,
        data: WorkflowRequestUpdate,
        performing_user_id: uuid.UUID,
    ) -> WorkflowRequestDetailResponse:
        request = await self.workflow_repo.get_for_update(request_id)
        if not request:
            raise NotFoundException("Workflow request not found")
        if request.state != "draft":
            raise ValidationException("Only draft requests can be updated")
        if request.requester_id != performing_user_id:
            raise ForbiddenException("Only the requester can update a draft request")

        updates = data.model_dump(exclude_unset=True)
        if not updates:
            loaded = await self.workflow_repo.get_with_details(request_id)
            return self._to_detail(loaded or request)

        await self.workflow_repo.update(request, updates, commit=False)
        await self.workflow_repo.db.commit()
        await self._log_audit(
            audit_actions.WORKFLOW_UPDATE, performing_user_id, request, updates
        )
        loaded = await self.workflow_repo.get_with_details(request_id)
        return self._to_detail(loaded or request)

    async def submit_request(
        self,
        request_id: uuid.UUID,
        data: WorkflowSubmitRequest,
        performing_user_id: uuid.UUID,
    ) -> WorkflowRequestDetailResponse:
        request = await self.workflow_repo.get_for_update(request_id)
        if not request:
            raise NotFoundException("Workflow request not found")
        if request.state != "draft":
            raise ValidationException("Only draft requests can be submitted")
        if request.requester_id != performing_user_id:
            raise ForbiddenException("Only the requester can submit a draft request")

        assignee_id = data.assignee_id or request.assignee_id
        if assignee_id is None:
            assignee_id = await self._find_default_assignee(
                exclude_user_id=performing_user_id
            )
        if assignee_id is None:
            raise ValidationException(
                "No approver available. Provide assignee_id or configure users with workflow.approve."
            )
        await self._validate_user(assignee_id)

        now = datetime.now(timezone.utc)
        await self.workflow_repo.update(
            request,
            {
                "state": "pending",
                "assignee_id": assignee_id,
                "pending_since": now,
                "submitted_at": now,
            },
            commit=False,
        )
        await self._record_history(
            request,
            performing_user_id,
            "submitted",
            "draft",
            "pending",
            comment=data.comment,
            assignee_id=assignee_id,
        )
        await self.workflow_repo.db.commit()
        await self._log_audit(
            audit_actions.WORKFLOW_SUBMIT,
            performing_user_id,
            request,
            {"assignee_id": str(assignee_id)},
        )
        await self._notify(
            assignee_id,
            "Approval assigned",
            f"Request '{request.title}' ({request.request_number}) awaits your approval.",
            {"request_id": str(request.id), "request_number": request.request_number},
        )
        loaded = await self.workflow_repo.get_with_details(request_id)
        return self._to_detail(loaded or request)

    async def assign_request(
        self,
        request_id: uuid.UUID,
        data: WorkflowAssignRequest,
        performing_user_id: uuid.UUID,
    ) -> WorkflowRequestDetailResponse:
        request = await self.workflow_repo.get_for_update(request_id)
        if not request:
            raise NotFoundException("Workflow request not found")
        if request.state != "pending":
            raise ValidationException("Only pending requests can be reassigned")
        if data.assignee_id == request.assignee_id:
            raise ValidationException("Request is already assigned to this user")

        await self._validate_user(data.assignee_id)
        previous_assignee = request.assignee_id
        now = datetime.now(timezone.utc)
        await self.workflow_repo.update(
            request,
            {
                "assignee_id": data.assignee_id,
                "pending_since": now,
            },
            commit=False,
        )
        await self._record_history(
            request,
            performing_user_id,
            "assigned",
            "pending",
            "pending",
            comment=data.comment,
            assignee_id=data.assignee_id,
        )
        await self.workflow_repo.db.commit()
        await self._log_audit(
            audit_actions.WORKFLOW_ASSIGN,
            performing_user_id,
            request,
            {
                "assignee_id": str(data.assignee_id),
                "previous_assignee_id": str(previous_assignee)
                if previous_assignee
                else None,
            },
        )
        await self._notify(
            data.assignee_id,
            "Approval reassigned",
            f"Request '{request.title}' ({request.request_number}) was assigned to you.",
            {"request_id": str(request.id), "request_number": request.request_number},
        )
        loaded = await self.workflow_repo.get_with_details(request_id)
        return self._to_detail(loaded or request)

    async def approve_request(
        self,
        request_id: uuid.UUID,
        data: WorkflowDecisionRequest,
        performing_user_id: uuid.UUID,
    ) -> WorkflowRequestDetailResponse:
        return await self._resolve_request(
            request_id,
            performing_user_id,
            new_state="approved",
            action="approved",
            audit_action=audit_actions.WORKFLOW_APPROVE,
            notify_requester=True,
            comment=data.comment,
        )

    async def reject_request(
        self,
        request_id: uuid.UUID,
        data: WorkflowDecisionRequest,
        performing_user_id: uuid.UUID,
    ) -> WorkflowRequestDetailResponse:
        return await self._resolve_request(
            request_id,
            performing_user_id,
            new_state="rejected",
            action="rejected",
            audit_action=audit_actions.WORKFLOW_REJECT,
            notify_requester=True,
            comment=data.comment,
        )

    async def _resolve_request(
        self,
        request_id: uuid.UUID,
        performing_user_id: uuid.UUID,
        new_state: str,
        action: str,
        audit_action: str,
        notify_requester: bool,
        comment: Optional[str],
    ) -> WorkflowRequestDetailResponse:
        request = await self.workflow_repo.get_for_update(request_id)
        if not request:
            raise NotFoundException("Workflow request not found")
        if request.state != "pending":
            raise ValidationException(
                "Only pending requests can be approved or rejected"
            )
        if request.assignee_id != performing_user_id:
            raise ForbiddenException(
                "Only the assigned approver can approve or reject this request"
            )

        now = datetime.now(timezone.utc)
        await self.workflow_repo.update(
            request,
            {
                "state": new_state,
                "resolved_at": now,
                "pending_since": None,
            },
            commit=False,
        )
        await self._record_history(
            request,
            performing_user_id,
            action,
            "pending",
            new_state,
            comment=comment,
        )
        await self.workflow_repo.db.commit()
        await self._log_audit(
            audit_action,
            performing_user_id,
            request,
            {"comment": comment} if comment else None,
        )
        if notify_requester:
            verb = "approved" if new_state == "approved" else "rejected"
            await self._notify(
                request.requester_id,
                f"Request {verb}",
                f"Your request '{request.title}' ({request.request_number}) was {verb}.",
                {
                    "request_id": str(request.id),
                    "request_number": request.request_number,
                    "state": new_state,
                },
            )
        loaded = await self.workflow_repo.get_with_details(request_id)
        return self._to_detail(loaded or request)

    async def add_comment(
        self,
        request_id: uuid.UUID,
        data: WorkflowCommentCreate,
        performing_user_id: uuid.UUID,
        current_user: User,
    ) -> WorkflowRequestDetailResponse:
        request = await self.workflow_repo.get(request_id)
        if not request:
            raise NotFoundException("Workflow request not found")
        self._ensure_request_access(current_user, request)
        if request.state in TERMINAL_STATES:
            raise ValidationException("Cannot comment on resolved requests")

        await self.workflow_repo.add_comment(
            {
                "request_id": request_id,
                "author_id": performing_user_id,
                "body": data.body,
            },
            commit=False,
        )
        await self.workflow_repo.db.commit()
        await self._log_audit(
            audit_actions.WORKFLOW_COMMENT,
            performing_user_id,
            request,
            {"comment_preview": data.body[:120]},
        )

        notify_targets = {request.requester_id, request.assignee_id} - {
            performing_user_id,
            None,
        }
        for uid in notify_targets:
            await self._notify(
                uid,
                "New workflow comment",
                f"A comment was added to '{request.title}' ({request.request_number}).",
                {
                    "request_id": str(request.id),
                    "request_number": request.request_number,
                },
            )

        loaded = await self.workflow_repo.get_with_details(request_id)
        return self._to_detail(loaded or request)

    async def get_request(
        self, request_id: uuid.UUID, current_user: User
    ) -> WorkflowRequestDetailResponse:
        request = await self.workflow_repo.get_with_details(request_id)
        if not request:
            raise NotFoundException("Workflow request not found")
        self._ensure_request_access(current_user, request)
        return self._to_detail(request)

    async def list_requests(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        state: Optional[str] = None,
        request_type: Optional[str] = None,
        requester_id: Optional[uuid.UUID] = None,
        assignee_id: Optional[uuid.UUID] = None,
        mine_only: bool = False,
        current_user: Optional[User] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> tuple[list[WorkflowRequestSummary], int]:
        effective_mine_only = mine_only
        if current_user and not self._can_view_all_requests(current_user):
            effective_mine_only = True
        items = await self.workflow_repo.list_filtered(
            skip=skip,
            limit=limit,
            search=search,
            state=state,
            request_type=request_type,
            requester_id=requester_id,
            assignee_id=assignee_id,
            mine_only=effective_mine_only,
            current_user_id=current_user.id if current_user else None,
            sort_by=sort_by,
            sort_order=sort_order,
        )
        total = await self.workflow_repo.count_filtered(
            search=search,
            state=state,
            request_type=request_type,
            requester_id=requester_id,
            assignee_id=assignee_id,
            mine_only=effective_mine_only,
            current_user_id=current_user.id if current_user else None,
        )
        return [self._to_summary(r) for r in items], total

    async def list_my_pending(
        self,
        assignee_id: uuid.UUID,
        skip: int = 0,
        limit: int = 100,
        current_user: Optional[User] = None,
    ) -> tuple[list[WorkflowRequestSummary], int]:
        return await self.list_requests(
            skip=skip,
            limit=limit,
            state="pending",
            assignee_id=assignee_id,
            sort_by="pending_since",
            sort_order="asc",
            current_user=current_user,
        )

    def _matching_rule(
        self, rules: list[WorkflowEscalationRule], request: WorkflowRequest
    ) -> Optional[WorkflowEscalationRule]:
        for rule in rules:
            if rule.escalation_level != request.escalation_level:
                continue
            if rule.request_type not in ("*", request.request_type):
                continue
            return rule
        return None

    async def process_escalations(
        self, performing_user_id: uuid.UUID
    ) -> WorkflowEscalationResult:
        rules = await self.workflow_repo.list_escalation_rules(active_only=True)
        if not rules:
            return WorkflowEscalationResult(escalated_count=0, request_ids=[])

        escalated_ids: list[uuid.UUID] = []
        now = datetime.now(timezone.utc)
        pending = await self.workflow_repo.list_pending_for_escalation(now)

        for request in pending:
            if not request.pending_since:
                continue
            rule = self._matching_rule(rules, request)
            if not rule:
                continue
            due_at = request.pending_since + timedelta(
                hours=rule.hours_until_escalation
            )
            if due_at > now:
                continue

            candidates = await self.user_repo.get_user_ids_with_permission(
                rule.target_permission
            )
            new_assignee = None
            for uid in candidates:
                if uid in (request.requester_id, request.assignee_id):
                    continue
                new_assignee = uid
                break
            if new_assignee is None:
                for uid in candidates:
                    if uid != request.assignee_id:
                        new_assignee = uid
                        break
            if new_assignee is None or new_assignee == request.assignee_id:
                continue

            new_level = request.escalation_level + 1
            await self.workflow_repo.update(
                request,
                {
                    "assignee_id": new_assignee,
                    "escalation_level": new_level,
                    "pending_since": now,
                },
                commit=False,
            )
            await self._record_history(
                request,
                None,
                "escalated",
                "pending",
                "pending",
                comment=f"Escalated by rule '{rule.name}'",
                assignee_id=new_assignee,
                escalation_level=new_level,
            )
            escalated_ids.append(request.id)
            await self._log_audit(
                audit_actions.WORKFLOW_ESCALATE,
                performing_user_id,
                request,
                {
                    "rule_name": rule.name,
                    "new_assignee_id": str(new_assignee),
                    "escalation_level": new_level,
                },
            )
            await self._notify(
                new_assignee,
                "Escalated approval",
                f"Request '{request.title}' ({request.request_number}) was escalated to you.",
                {
                    "request_id": str(request.id),
                    "request_number": request.request_number,
                    "escalation_level": new_level,
                },
            )
            if request.requester_id:
                await self._notify(
                    request.requester_id,
                    "Request escalated",
                    f"Your request '{request.title}' was escalated for faster review.",
                    {"request_id": str(request.id)},
                )

        if escalated_ids:
            await self.workflow_repo.db.commit()
        return WorkflowEscalationResult(
            escalated_count=len(escalated_ids),
            request_ids=escalated_ids,
        )

    async def list_escalation_rules(self) -> list[WorkflowEscalationRuleResponse]:
        rules = await self.workflow_repo.list_escalation_rules(active_only=False)
        return [WorkflowEscalationRuleResponse.model_validate(r) for r in rules]

    async def create_escalation_rule(
        self,
        data: WorkflowEscalationRuleCreate,
        performing_user_id: uuid.UUID,
    ) -> WorkflowEscalationRuleResponse:
        rule = await self.workflow_repo.create_escalation_rule(data.model_dump())
        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action=audit_actions.WORKFLOW_ESCALATION_RULE_CREATE,
                entity_type="WorkflowEscalationRule",
                entity_id=str(rule.id),
                metadata=data.model_dump(),
            )
        return WorkflowEscalationRuleResponse.model_validate(rule)

    async def update_escalation_rule(
        self,
        rule_id: uuid.UUID,
        data: WorkflowEscalationRuleUpdate,
        performing_user_id: uuid.UUID,
    ) -> WorkflowEscalationRuleResponse:
        rule = await self.workflow_repo.get_escalation_rule(rule_id)
        if not rule:
            raise NotFoundException("Escalation rule not found")
        updates = data.model_dump(exclude_unset=True)
        if not updates:
            return WorkflowEscalationRuleResponse.model_validate(rule)
        rule = await self.workflow_repo.update_escalation_rule(rule, updates)
        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action=audit_actions.WORKFLOW_ESCALATION_RULE_UPDATE,
                entity_type="WorkflowEscalationRule",
                entity_id=str(rule.id),
                metadata=updates,
            )
        return WorkflowEscalationRuleResponse.model_validate(rule)
