import uuid
from typing import List
from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_current_user, get_rbac_service
from app.core.authorization import require_permission
from app.models.user import User
from app.schemas.rbac import (
    RoleCreate,
    RoleUpdate,
    RoleResponse,
    PermissionCreate,
    PermissionResponse,
    UserRolesResponse,
)
from app.schemas.base import MessageResponse
from app.services.rbac import RbacService

router = APIRouter()


@router.post(
    "/roles",
    response_model=RoleResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new role",
)
@require_permission("role:write")
async def create_role(
    role_in: RoleCreate,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> RoleResponse:
    """Create a new role. Requires 'role:write' permission."""
    return await rbac_service.create_role(role_in)


@router.get(
    "/roles",
    response_model=List[RoleResponse],
    status_code=status.HTTP_200_OK,
    summary="List all active roles",
)
@require_permission("role:read")
async def list_roles(
    skip: int = 0,
    limit: int = 100,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> List[RoleResponse]:
    """Retrieve all roles. Requires 'role:read' permission."""
    return await rbac_service.list_roles(skip=skip, limit=limit)


@router.get(
    "/roles/{id}",
    response_model=RoleResponse,
    status_code=status.HTTP_200_OK,
    summary="Get role by ID",
)
@require_permission("role:read")
async def get_role(
    id: uuid.UUID,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> RoleResponse:
    """Retrieve details for a specific role. Requires 'role:read' permission."""
    return await rbac_service.get_role_by_id(id)


@router.put(
    "/roles/{id}",
    response_model=RoleResponse,
    status_code=status.HTTP_200_OK,
    summary="Update role details",
)
@require_permission("role:write")
async def update_role(
    id: uuid.UUID,
    role_in: RoleUpdate,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> RoleResponse:
    """Update role details. Requires 'role:write' permission."""
    return await rbac_service.update_role(id, role_in)


@router.delete(
    "/roles/{id}",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Delete role",
)
@require_permission("role:write")
async def delete_role(
    id: uuid.UUID,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> MessageResponse:
    """Soft delete a role. Requires 'role:write' permission."""
    await rbac_service.delete_role(id)
    return MessageResponse(message="Role deleted successfully")


@router.post(
    "/permissions",
    response_model=PermissionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new permission",
)
@require_permission("role:write")
async def create_permission(
    perm_in: PermissionCreate,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> PermissionResponse:
    """Create a new permission scope. Requires 'role:write' permission."""
    return await rbac_service.create_permission(perm_in)


@router.get(
    "/permissions",
    response_model=List[PermissionResponse],
    status_code=status.HTTP_200_OK,
    summary="List all permissions",
)
@require_permission("role:read")
async def list_permissions(
    skip: int = 0,
    limit: int = 100,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> List[PermissionResponse]:
    """Retrieve all permission scopes. Requires 'role:read' permission."""
    return await rbac_service.list_permissions(skip=skip, limit=limit)


@router.post(
    "/users/{user_id}/roles",
    response_model=UserRolesResponse,
    status_code=status.HTTP_200_OK,
    summary="Assign a role to a user",
)
@require_permission("role:write")
async def assign_role_to_user(
    user_id: uuid.UUID,
    role_id: uuid.UUID,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> UserRolesResponse:
    """Map a role to a user. Requires 'role:write' permission."""
    return await rbac_service.assign_role_to_user(user_id, role_id, performing_user_id=current_user.id)


@router.delete(
    "/users/{user_id}/roles/{role_id}",
    response_model=UserRolesResponse,
    status_code=status.HTTP_200_OK,
    summary="Remove a role from a user",
)
@require_permission("role:write")
async def remove_role_from_user(
    user_id: uuid.UUID,
    role_id: uuid.UUID,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> UserRolesResponse:
    """Remove a role mapping from a user. Requires 'role:write' permission."""
    return await rbac_service.remove_role_from_user(user_id, role_id, performing_user_id=current_user.id)


@router.post(
    "/roles/{role_id}/permissions",
    response_model=RoleResponse,
    status_code=status.HTTP_200_OK,
    summary="Assign a permission to a role",
)
@require_permission("role:write")
async def assign_permission_to_role(
    role_id: uuid.UUID,
    permission_id: uuid.UUID,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> RoleResponse:
    """Map a permission scope to a role. Requires 'role:write' permission."""
    return await rbac_service.assign_permission_to_role(role_id, permission_id, performing_user_id=current_user.id)


@router.delete(
    "/roles/{role_id}/permissions/{permission_id}",
    response_model=RoleResponse,
    status_code=status.HTTP_200_OK,
    summary="Remove a permission from a role",
)
@require_permission("role:write")
async def remove_permission_from_role(
    role_id: uuid.UUID,
    permission_id: uuid.UUID,
    rbac_service: RbacService = Depends(get_rbac_service),
    current_user: User = Depends(get_current_user),
) -> RoleResponse:
    """Remove a permission mapping from a role. Requires 'role:write' permission."""
    return await rbac_service.remove_permission_from_role(role_id, permission_id, performing_user_id=current_user.id)
