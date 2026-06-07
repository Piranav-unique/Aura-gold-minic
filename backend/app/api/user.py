import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_current_user, get_user_service
from app.core.authorization import require_permission
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate, UserDetailResponse
from app.schemas.base import MessageResponse
from app.services.user import UserService

router = APIRouter()


@router.post(
    "/",
    response_model=UserDetailResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new user",
)
@require_permission("user.create")
async def create_user(
    user_in: UserCreate,
    user_service: UserService = Depends(get_user_service),
    current_user: User = Depends(get_current_user),
) -> UserDetailResponse:
    """Create a new user. Requires 'user.create' permission."""
    return await user_service.create_user(user_in, performing_user_id=current_user.id)


@router.get(
    "/",
    response_model=List[UserDetailResponse],
    status_code=status.HTTP_200_OK,
    summary="List users with search, pagination and filtering",
)
@require_permission("user.view")
async def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    search: Optional[str] = Query(None, description="Search term matching first_name, last_name, or email"),
    is_active: Optional[bool] = Query(None, description="Filter by active status"),
    is_superuser: Optional[bool] = Query(None, description="Filter by superuser status"),
    role_id: Optional[uuid.UUID] = Query(None, description="Filter by mapped role ID"),
    user_service: UserService = Depends(get_user_service),
    current_user: User = Depends(get_current_user),
) -> List[UserDetailResponse]:
    """Retrieve users matching parameters. Requires 'user.view' permission."""
    return await user_service.list_users(
        skip=skip,
        limit=limit,
        search=search,
        is_active=is_active,
        is_superuser=is_superuser,
        role_id=role_id,
    )


@router.get(
    "/{id}",
    response_model=UserDetailResponse,
    status_code=status.HTTP_200_OK,
    summary="Get user details by ID",
)
@require_permission("user.view")
async def get_user(
    id: uuid.UUID,
    user_service: UserService = Depends(get_user_service),
    current_user: User = Depends(get_current_user),
) -> UserDetailResponse:
    """Retrieve details of a specific user. Requires 'user.view' permission."""
    return await user_service.get_user_by_id(id)


@router.put(
    "/{id}",
    response_model=UserDetailResponse,
    status_code=status.HTTP_200_OK,
    summary="Update user attributes",
)
@require_permission("user.update")
async def update_user(
    id: uuid.UUID,
    user_in: UserUpdate,
    user_service: UserService = Depends(get_user_service),
    current_user: User = Depends(get_current_user),
) -> UserDetailResponse:
    """Update user attributes. Requires 'user.update' permission."""
    return await user_service.update_user(id, user_in, performing_user_id=current_user.id)


@router.delete(
    "/{id}",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Delete user (soft delete)",
)
@require_permission("user.delete")
async def delete_user(
    id: uuid.UUID,
    user_service: UserService = Depends(get_user_service),
    current_user: User = Depends(get_current_user),
) -> MessageResponse:
    """Soft delete a user. Requires 'user.delete' permission."""
    await user_service.delete_user(id, performing_user_id=current_user.id)
    return MessageResponse(message="User deleted successfully")
