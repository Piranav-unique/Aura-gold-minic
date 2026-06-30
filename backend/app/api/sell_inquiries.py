from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_current_user, get_gold_sell_inquiry_service
from app.core.authorization import PermissionChecker
from app.models.user import User
from app.schemas.gold_sell_inquiry import (
    GoldSellInquiryApprove,
    GoldSellInquiryCreate,
    GoldSellInquiryDetailResponse,
    GoldSellInquiryListResponse,
    GoldSellInquiryReject,
    GoldSellInquiryRespond,
    GoldSellInquiryResponse,
)
from app.services.gold_sell_inquiry import GoldSellInquiryService

router = APIRouter()


@router.post(
    "",
    response_model=GoldSellInquiryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Submit a gold sell inquiry",
)
async def create_sell_inquiry(
    body: GoldSellInquiryCreate,
    current_user: User = Depends(get_current_user),
    service: GoldSellInquiryService = Depends(get_gold_sell_inquiry_service),
) -> GoldSellInquiryResponse:
    return await service.create_inquiry(current_user, body)


@router.get(
    "/mine",
    response_model=GoldSellInquiryListResponse,
    summary="List current user's sell inquiries",
)
async def list_my_sell_inquiries(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    service: GoldSellInquiryService = Depends(get_gold_sell_inquiry_service),
) -> GoldSellInquiryListResponse:
    return await service.list_my_inquiries(current_user, skip=skip, limit=limit)


@router.get(
    "",
    response_model=GoldSellInquiryListResponse,
    summary="List all sell inquiries (admin)",
)
async def list_sell_inquiries(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    status: Optional[str] = Query(
        None,
        pattern=r"^(pending|needs_info|approved|rejected|responded|closed|payout_failed)$",
    ),
    current_user: User = Depends(PermissionChecker("transaction.view")),
    service: GoldSellInquiryService = Depends(get_gold_sell_inquiry_service),
) -> GoldSellInquiryListResponse:
    return await service.list_inquiries(skip=skip, limit=limit, status=status)


@router.get(
    "/{inquiry_id}",
    response_model=GoldSellInquiryDetailResponse,
    summary="Sell inquiry detail with customer and payout context",
)
async def get_sell_inquiry_detail(
    inquiry_id: UUID,
    current_user: User = Depends(PermissionChecker("transaction.view")),
    service: GoldSellInquiryService = Depends(get_gold_sell_inquiry_service),
) -> GoldSellInquiryDetailResponse:
    return await service.get_inquiry_detail(inquiry_id, current_user)


@router.patch(
    "/{inquiry_id}/respond",
    response_model=GoldSellInquiryResponse,
    summary="Request more information from customer",
)
async def respond_to_sell_inquiry(
    inquiry_id: UUID,
    body: GoldSellInquiryRespond,
    current_user: User = Depends(PermissionChecker("transaction.view")),
    service: GoldSellInquiryService = Depends(get_gold_sell_inquiry_service),
) -> GoldSellInquiryResponse:
    return await service.respond_to_inquiry(inquiry_id, current_user, body)


@router.post(
    "/{inquiry_id}/approve",
    response_model=GoldSellInquiryResponse,
    summary="Approve sell inquiry and record payout",
)
async def approve_sell_inquiry(
    inquiry_id: UUID,
    body: GoldSellInquiryApprove,
    current_user: User = Depends(PermissionChecker("transaction.view")),
    service: GoldSellInquiryService = Depends(get_gold_sell_inquiry_service),
) -> GoldSellInquiryResponse:
    return await service.approve_inquiry(inquiry_id, current_user, body)


@router.post(
    "/{inquiry_id}/reject",
    response_model=GoldSellInquiryResponse,
    summary="Reject sell inquiry",
)
async def reject_sell_inquiry(
    inquiry_id: UUID,
    body: GoldSellInquiryReject,
    current_user: User = Depends(PermissionChecker("transaction.view")),
    service: GoldSellInquiryService = Depends(get_gold_sell_inquiry_service),
) -> GoldSellInquiryResponse:
    return await service.reject_inquiry(inquiry_id, current_user, body)
