import uuid
from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_auth_service, get_current_user
from app.core.security import create_access_token, create_refresh_token
from app.models.user import User
from app.schemas.auth import LoginRequest, RefreshRequest, Token, UserResponse
from app.schemas.base import MessageResponse
from app.services.auth import AuthService

router = APIRouter()


@router.post(
    "/login",
    response_model=Token,
    status_code=status.HTTP_200_OK,
    summary="Authenticate user and return access/refresh tokens",
)
async def login(
    login_data: LoginRequest,
    auth_service: AuthService = Depends(get_auth_service),
) -> Token:
    """Authenticate a user using email and password, returning JWT access and refresh tokens."""
    user = await auth_service.authenticate_user(
        login_data.email, login_data.password
    )

    # Generate a unique ID for the refresh token
    jti = str(uuid.uuid4())
    access_token = create_access_token(subject=user.id)
    refresh_token = create_refresh_token(subject=user.id, jti=jti)

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post(
    "/refresh",
    response_model=Token,
    status_code=status.HTTP_200_OK,
    summary="Refresh access token using a valid refresh token",
)
async def refresh(
    refresh_data: RefreshRequest,
    auth_service: AuthService = Depends(get_auth_service),
) -> Token:
    """Perform Refresh Token Rotation (RTR). The old refresh token is blacklisted, and a new token pair is returned."""
    return await auth_service.refresh_tokens(refresh_data.refresh_token)


@router.post(
    "/logout",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Revoke refresh token and logout",
)
async def logout(
    refresh_data: RefreshRequest,
    auth_service: AuthService = Depends(get_auth_service),
) -> MessageResponse:
    """Log out the user by blacklisting the supplied refresh token."""
    await auth_service.logout_user(refresh_data.refresh_token)
    return MessageResponse(message="Successfully logged out")


@router.get(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current authenticated user info",
)
async def get_me(
    current_user: User = Depends(get_current_user),
) -> UserResponse:
    """Retrieve the profile details of the currently authenticated user using their bearer access token."""
    return current_user
