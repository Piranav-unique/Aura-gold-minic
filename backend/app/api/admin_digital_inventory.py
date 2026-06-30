from __future__ import annotations

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_digital_metal_inventory_service
from app.core.authorization import PermissionChecker
from app.models.user import User
from app.schemas.digital_metal_inventory import (
    DigitalMetalInventoryAlertsResponse,
    DigitalMetalInventoryListResponse,
    DigitalMetalInventoryMovementListResponse,
    DigitalMetalInventoryResponse,
    DigitalMetalInventoryUpdate,
)
from app.services.digital_metal_inventory import DigitalMetalInventoryService

router = APIRouter()


@router.get(
    "/metals",
    response_model=DigitalMetalInventoryListResponse,
    summary="List GOLD and SILVER digital stock pools",
)
async def list_digital_metals(
    current_user: User = Depends(PermissionChecker("inventory.view")),
    service: DigitalMetalInventoryService = Depends(get_digital_metal_inventory_service),
) -> DigitalMetalInventoryListResponse:
    return await service.list_metals()


@router.put(
    "/metals/{metal_type}",
    response_model=DigitalMetalInventoryResponse,
    summary="Update total digital metal stock and low-stock threshold",
)
async def update_digital_metal(
    metal_type: str,
    body: DigitalMetalInventoryUpdate,
    current_user: User = Depends(PermissionChecker("inventory.update")),
    service: DigitalMetalInventoryService = Depends(get_digital_metal_inventory_service),
) -> DigitalMetalInventoryResponse:
    return await service.update_metal(
        metal_type, body, admin_user_id=current_user.id
    )


@router.get(
    "/metals/{metal_type}/movements",
    response_model=DigitalMetalInventoryMovementListResponse,
    summary="Movement history for a digital metal pool",
)
async def list_digital_metal_movements(
    metal_type: str,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(PermissionChecker("inventory.view")),
    service: DigitalMetalInventoryService = Depends(get_digital_metal_inventory_service),
) -> DigitalMetalInventoryMovementListResponse:
    skip = (page - 1) * limit
    return await service.list_movements(metal_type, skip=skip, limit=limit)


@router.get(
    "/alerts",
    response_model=DigitalMetalInventoryAlertsResponse,
    summary="Low-stock and out-of-stock digital metal alerts",
)
async def list_digital_metal_alerts(
    current_user: User = Depends(PermissionChecker("inventory.view")),
    service: DigitalMetalInventoryService = Depends(get_digital_metal_inventory_service),
) -> DigitalMetalInventoryAlertsResponse:
    return await service.get_alerts()
