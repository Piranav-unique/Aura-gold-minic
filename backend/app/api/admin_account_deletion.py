import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_account_deletion_service, get_current_user
from app.core.authorization import PermissionChecker
from app.models.user import User
from app.schemas.account_deletion import (
    AccountDeletionDecisionRequest,
    AccountDeletionListResponse,
    AccountDeletionRequestResponse,
)
from app.services.account_deletion import AccountDeletionService

router = APIRouter()


@router.get(
    "",
    response_model=AccountDeletionListResponse,
    status_code=status.HTTP_200_OK,
    summary="List all account deletion requests",
)
async def list_account_deletion_requests(
    status: Optional[str] = Query(None, description="Filter by status (pending, approved, rejected, cancelled)"),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(PermissionChecker("user.view")),
    service: AccountDeletionService = Depends(get_account_deletion_service),
) -> AccountDeletionListResponse:
    skip = (page - 1) * limit
    return await service.list_requests(status=status, skip=skip, limit=limit)


@router.post(
    "/{request_id}/approve",
    response_model=AccountDeletionRequestResponse,
    status_code=status.HTTP_200_OK,
    summary="Approve account deletion request and permanently destroy consumer data",
)
async def approve_account_deletion_request(
    request_id: uuid.UUID,
    body: Optional[AccountDeletionDecisionRequest] = None,
    current_user: User = Depends(PermissionChecker("user.delete")),
    service: AccountDeletionService = Depends(get_account_deletion_service),
) -> AccountDeletionRequestResponse:
    comment = body.comment if body else None
    return await service.approve_request(
        request_id=request_id,
        admin_user=current_user,
        comment=comment,
    )


@router.post(
    "/{request_id}/reject",
    response_model=AccountDeletionRequestResponse,
    status_code=status.HTTP_200_OK,
    summary="Reject account deletion request",
)
async def reject_account_deletion_request(
    request_id: uuid.UUID,
    body: Optional[AccountDeletionDecisionRequest] = None,
    current_user: User = Depends(PermissionChecker("user.delete")),
    service: AccountDeletionService = Depends(get_account_deletion_service),
) -> AccountDeletionRequestResponse:
    comment = body.comment if body else None
    return await service.reject_request(
        request_id=request_id,
        admin_user=current_user,
        comment=comment,
    )
