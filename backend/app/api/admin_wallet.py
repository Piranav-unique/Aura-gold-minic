from __future__ import annotations

import uuid
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_admin_wallet_service, get_current_user
from app.core.authorization import PermissionChecker
from app.models.user import User
from app.schemas.admin_wallet import (
    WalletTransactionDetailResponse,
    WalletTransactionListResponse,
    WalletUserDetailResponse,
    WalletUserSearchResponse,
)
from app.services.admin_wallet import AdminWalletService

router = APIRouter()


@router.get(
    "/users",
    response_model=WalletUserSearchResponse,
    summary="Search end-user wallets by name, mobile, email, or masked KYC",
)
async def search_wallet_users(
    search: Optional[str] = Query(None, min_length=1, max_length=100),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(PermissionChecker("wallet.view")),
    wallet_service: AdminWalletService = Depends(get_admin_wallet_service),
) -> WalletUserSearchResponse:
    skip = (page - 1) * limit
    return await wallet_service.search_users(search=search, skip=skip, limit=limit)


@router.get(
    "/users/{user_id}",
    response_model=WalletUserDetailResponse,
    summary="Get user wallet detail with masked KYC and balance summary",
)
async def get_user_wallet_detail(
    user_id: uuid.UUID,
    current_user: User = Depends(PermissionChecker("wallet.view")),
    wallet_service: AdminWalletService = Depends(get_admin_wallet_service),
) -> WalletUserDetailResponse:
    return await wallet_service.get_user_wallet(
        user_id, admin_user_id=current_user.id
    )


@router.get(
    "/users/{user_id}/transactions",
    response_model=WalletTransactionListResponse,
    summary="List unified wallet transactions for a user",
)
async def list_user_wallet_transactions(
    user_id: uuid.UUID,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    type: Optional[str] = Query(None, alias="type"),
    metal: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    current_user: User = Depends(PermissionChecker("wallet.view")),
    wallet_service: AdminWalletService = Depends(get_admin_wallet_service),
) -> WalletTransactionListResponse:
    skip = (page - 1) * limit
    return await wallet_service.list_user_transactions(
        user_id,
        skip=skip,
        limit=limit,
        transaction_type=type,
        metal=metal,
        status=status,
    )


@router.get(
    "/transactions/recent",
    response_model=WalletTransactionListResponse,
    summary="Recent wallet transactions across all users",
)
async def list_recent_wallet_transactions(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    type: Optional[str] = Query(None, alias="type"),
    metal: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None, min_length=1, max_length=100),
    from_date: Optional[date] = Query(None),
    to_date: Optional[date] = Query(None),
    current_user: User = Depends(PermissionChecker("transaction.view")),
    wallet_service: AdminWalletService = Depends(get_admin_wallet_service),
) -> WalletTransactionListResponse:
    skip = (page - 1) * limit
    return await wallet_service.list_recent_transactions(
        skip=skip,
        limit=limit,
        transaction_type=type,
        metal=metal,
        status=status,
        search=search,
        from_date=from_date,
        to_date=to_date,
    )


@router.get(
    "/transactions/{transaction_id}",
    response_model=WalletTransactionDetailResponse,
    summary="Get wallet transaction detail by composite id (buy:/sell:/referral:/savings:)",
)
async def get_wallet_transaction_detail(
    transaction_id: str,
    current_user: User = Depends(PermissionChecker("wallet.view")),
    wallet_service: AdminWalletService = Depends(get_admin_wallet_service),
) -> WalletTransactionDetailResponse:
    return await wallet_service.get_transaction_detail(
        transaction_id, admin_user_id=current_user.id
    )
