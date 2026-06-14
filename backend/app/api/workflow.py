import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_current_user, get_workflow_service
from app.core.authorization import require_permission
from app.models.user import User
from app.schemas.pagination import PaginatedResponse
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
    WorkflowRequestType,
    WorkflowRequestUpdate,
    WorkflowSortField,
    WorkflowState,
    WorkflowSubmitRequest,
    SortOrder,
)
from app.services.workflow import WorkflowService

router = APIRouter()


@router.post(
    "/",
    response_model=WorkflowRequestDetailResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a draft workflow request",
)
@require_permission("workflow.create")
async def create_workflow_request(
    body: WorkflowRequestCreate,
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowRequestDetailResponse:
    return await workflow_service.create_request(
        body, performing_user_id=current_user.id
    )


@router.get(
    "/",
    response_model=PaginatedResponse[WorkflowRequestSummary],
    summary="List workflow requests",
)
@require_permission("workflow.view")
async def list_workflow_requests(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    search: Optional[str] = Query(None),
    state: Optional[WorkflowState] = Query(None),
    request_type: Optional[WorkflowRequestType] = Query(None),
    requester_id: Optional[uuid.UUID] = Query(None),
    assignee_id: Optional[uuid.UUID] = Query(None),
    mine_only: bool = Query(False),
    sort_by: WorkflowSortField = Query("created_at"),
    sort_order: SortOrder = Query("desc"),
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[WorkflowRequestSummary]:
    items, total = await workflow_service.list_requests(
        skip=skip,
        limit=limit,
        search=search,
        state=state,
        request_type=request_type,
        requester_id=requester_id,
        assignee_id=assignee_id,
        mine_only=mine_only,
        current_user=current_user,
        sort_by=sort_by,
        sort_order=sort_order,
    )
    return PaginatedResponse(items=items, total=total, skip=skip, limit=limit)


@router.get(
    "/pending/my",
    response_model=PaginatedResponse[WorkflowRequestSummary],
    summary="List pending approvals assigned to current user",
)
@require_permission("workflow.approve")
async def list_my_pending_approvals(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[WorkflowRequestSummary]:
    items, total = await workflow_service.list_my_pending(
        assignee_id=current_user.id, skip=skip, limit=limit, current_user=current_user
    )
    return PaginatedResponse(items=items, total=total, skip=skip, limit=limit)


@router.get(
    "/escalation-rules",
    response_model=list[WorkflowEscalationRuleResponse],
    summary="List escalation rules",
)
@require_permission("workflow.manage")
async def list_escalation_rules(
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> list[WorkflowEscalationRuleResponse]:
    return await workflow_service.list_escalation_rules()


@router.post(
    "/escalation-rules",
    response_model=WorkflowEscalationRuleResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create escalation rule",
)
@require_permission("workflow.manage")
async def create_escalation_rule(
    body: WorkflowEscalationRuleCreate,
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowEscalationRuleResponse:
    return await workflow_service.create_escalation_rule(
        body, performing_user_id=current_user.id
    )


@router.patch(
    "/escalation-rules/{rule_id}",
    response_model=WorkflowEscalationRuleResponse,
    summary="Update escalation rule",
)
@require_permission("workflow.manage")
async def update_escalation_rule(
    rule_id: uuid.UUID,
    body: WorkflowEscalationRuleUpdate,
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowEscalationRuleResponse:
    return await workflow_service.update_escalation_rule(
        rule_id, body, performing_user_id=current_user.id
    )


@router.post(
    "/escalations/process",
    response_model=WorkflowEscalationResult,
    summary="Process pending request escalations",
)
@require_permission("workflow.manage")
async def process_escalations(
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowEscalationResult:
    return await workflow_service.process_escalations(
        performing_user_id=current_user.id
    )


@router.get(
    "/{request_id}",
    response_model=WorkflowRequestDetailResponse,
    summary="Get workflow request detail",
)
@require_permission("workflow.view")
async def get_workflow_request(
    request_id: uuid.UUID,
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowRequestDetailResponse:
    return await workflow_service.get_request(request_id, current_user)


@router.put(
    "/{request_id}",
    response_model=WorkflowRequestDetailResponse,
    summary="Update draft workflow request",
)
@require_permission("workflow.create")
async def update_workflow_request(
    request_id: uuid.UUID,
    body: WorkflowRequestUpdate,
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowRequestDetailResponse:
    return await workflow_service.update_request(
        request_id, body, performing_user_id=current_user.id
    )


@router.post(
    "/{request_id}/submit",
    response_model=WorkflowRequestDetailResponse,
    summary="Submit draft request for approval",
)
@require_permission("workflow.create")
async def submit_workflow_request(
    request_id: uuid.UUID,
    body: WorkflowSubmitRequest,
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowRequestDetailResponse:
    return await workflow_service.submit_request(
        request_id, body, performing_user_id=current_user.id
    )


@router.post(
    "/{request_id}/assign",
    response_model=WorkflowRequestDetailResponse,
    summary="Assign or reassign approver",
)
@require_permission("workflow.approve")
async def assign_workflow_request(
    request_id: uuid.UUID,
    body: WorkflowAssignRequest,
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowRequestDetailResponse:
    return await workflow_service.assign_request(
        request_id, body, performing_user_id=current_user.id
    )


@router.post(
    "/{request_id}/approve",
    response_model=WorkflowRequestDetailResponse,
    summary="Approve pending request",
)
@require_permission("workflow.approve")
async def approve_workflow_request(
    request_id: uuid.UUID,
    body: WorkflowDecisionRequest,
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowRequestDetailResponse:
    return await workflow_service.approve_request(
        request_id, body, performing_user_id=current_user.id
    )


@router.post(
    "/{request_id}/reject",
    response_model=WorkflowRequestDetailResponse,
    summary="Reject pending request",
)
@require_permission("workflow.approve")
async def reject_workflow_request(
    request_id: uuid.UUID,
    body: WorkflowDecisionRequest,
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowRequestDetailResponse:
    return await workflow_service.reject_request(
        request_id, body, performing_user_id=current_user.id
    )


@router.post(
    "/{request_id}/comments",
    response_model=WorkflowRequestDetailResponse,
    summary="Add comment to workflow request",
)
@require_permission("workflow.view")
async def add_workflow_comment(
    request_id: uuid.UUID,
    body: WorkflowCommentCreate,
    workflow_service: WorkflowService = Depends(get_workflow_service),
    current_user: User = Depends(get_current_user),
) -> WorkflowRequestDetailResponse:
    return await workflow_service.add_comment(
        request_id, body, performing_user_id=current_user.id, current_user=current_user
    )
