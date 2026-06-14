import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_current_user, get_supplier_service
from app.core.authorization import require_permission
from app.models.user import User
from app.schemas.base import MessageResponse
from app.schemas.pagination import PaginatedResponse
from app.schemas.supplier import (
    SortOrder,
    SupplierCreate,
    SupplierResponse,
    SupplierSortField,
    SupplierUpdate,
)
from app.services.supplier import SupplierService

router = APIRouter()


@router.post(
    "/",
    response_model=SupplierResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new supplier",
)
@require_permission("inventory.create")
async def create_supplier(
    supplier_in: SupplierCreate,
    supplier_service: SupplierService = Depends(get_supplier_service),
    current_user: User = Depends(get_current_user),
) -> SupplierResponse:
    return await supplier_service.create_supplier(
        supplier_in, performing_user_id=current_user.id
    )


@router.get(
    "/",
    response_model=PaginatedResponse[SupplierResponse],
    status_code=status.HTTP_200_OK,
    summary="List suppliers",
)
@require_permission("inventory.view")
async def list_suppliers(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    search: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    sort_by: SupplierSortField = Query("created_at"),
    sort_order: SortOrder = Query("desc"),
    supplier_service: SupplierService = Depends(get_supplier_service),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[SupplierResponse]:
    items, total = await supplier_service.list_suppliers(
        skip=skip,
        limit=limit,
        search=search,
        is_active=is_active,
        sort_by=sort_by,
        sort_order=sort_order,
    )
    return PaginatedResponse(items=items, total=total, skip=skip, limit=limit)


@router.get(
    "/{supplier_id}",
    response_model=SupplierResponse,
    status_code=status.HTTP_200_OK,
    summary="Get supplier by ID",
)
@require_permission("inventory.view")
async def get_supplier(
    supplier_id: uuid.UUID,
    supplier_service: SupplierService = Depends(get_supplier_service),
    current_user: User = Depends(get_current_user),
) -> SupplierResponse:
    return await supplier_service.get_supplier_by_id(supplier_id)


@router.put(
    "/{supplier_id}",
    response_model=SupplierResponse,
    status_code=status.HTTP_200_OK,
    summary="Update supplier",
)
@require_permission("inventory.update")
async def update_supplier(
    supplier_id: uuid.UUID,
    supplier_in: SupplierUpdate,
    supplier_service: SupplierService = Depends(get_supplier_service),
    current_user: User = Depends(get_current_user),
) -> SupplierResponse:
    return await supplier_service.update_supplier(
        supplier_id, supplier_in, performing_user_id=current_user.id
    )


@router.delete(
    "/{supplier_id}",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Delete supplier",
)
@require_permission("inventory.delete")
async def delete_supplier(
    supplier_id: uuid.UUID,
    supplier_service: SupplierService = Depends(get_supplier_service),
    current_user: User = Depends(get_current_user),
) -> MessageResponse:
    await supplier_service.delete_supplier(
        supplier_id, performing_user_id=current_user.id
    )
    return MessageResponse(message="Supplier deleted successfully")
