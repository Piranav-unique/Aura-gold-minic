import uuid
from fastapi import APIRouter, Depends, status

from app.api.dependencies import (
    get_auth_service,
    get_current_user,
    get_signup_otp_service,
    get_user_service,
)
from app.core.security import create_access_token, create_refresh_token
from app.models.user import User
from app.schemas.auth import (
    LoginRequest,
    LoginOtpSendRequest,
    MobileLoginRequest,
    RefreshRequest,
    RegisterRequest,
    SignupOtpSendRequest,
    SignupOtpVerifyRequest,
    TrustedMobileLoginRequest,
    Token,
    UserResponse,
)
from app.schemas.base import MessageResponse
from app.schemas.user import UserDetailResponse
from app.services.auth import AuthService
from app.services.signup_otp import SignupOtpService
from app.services.user import UserService

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
    """Authenticate using email or mobile number and password."""
    user = await auth_service.authenticate_user(
        password=login_data.password,
        email=login_data.email,
        mobile_number=login_data.mobile_number,
    )

    jti = str(uuid.uuid4())
    token_version = user.token_version or 0
    access_token = create_access_token(subject=user.id, token_version=token_version)
    refresh_token = create_refresh_token(
        subject=user.id, jti=jti, token_version=token_version
    )

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post(
    "/login/otp/send",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Send login OTP to a registered mobile number",
)
async def send_login_otp(
    payload: LoginOtpSendRequest,
    otp_service: SignupOtpService = Depends(get_signup_otp_service),
) -> MessageResponse:
    await otp_service.send_login_otp(
        payload.mobile_number, payload.device_id
    )
    return MessageResponse(message="OTP sent to your mobile number.")


@router.post(
    "/login/mobile",
    response_model=Token,
    status_code=status.HTTP_200_OK,
    summary="End-user login with mobile OTP",
)
async def login_with_mobile(
    payload: MobileLoginRequest,
    auth_service: AuthService = Depends(get_auth_service),
    otp_service: SignupOtpService = Depends(get_signup_otp_service),
) -> Token:
    await otp_service.consume_login_otp(payload.mobile_number, payload.otp)
    user = await auth_service.authenticate_user_by_mobile(
        payload.mobile_number, payload.device_id
    )
    await auth_service.complete_mobile_login(user)
    return await auth_service.issue_tokens_for_user(user, login_method="mobile_otp")


@router.post(
    "/login/mobile/trusted",
    response_model=Token,
    status_code=status.HTTP_200_OK,
    summary="First end-user sign-in on registration device (no OTP)",
)
async def login_with_trusted_mobile(
    payload: TrustedMobileLoginRequest,
    auth_service: AuthService = Depends(get_auth_service),
) -> Token:
    user = await auth_service.authenticate_trusted_first_mobile_login(
        payload.mobile_number, payload.device_id
    )
    return await auth_service.issue_tokens_for_user(
        user, login_method="mobile_trusted"
    )


@router.post(
    "/signup/otp/send",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Send signup OTP to mobile number",
)
async def send_signup_otp(
    payload: SignupOtpSendRequest,
    otp_service: SignupOtpService = Depends(get_signup_otp_service),
) -> MessageResponse:
    await otp_service.send_signup_otp(payload.mobile_number)
    return MessageResponse(message="OTP sent to your mobile number.")


@router.post(
    "/signup/otp/verify",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Verify signup OTP before registration",
)
async def verify_signup_otp(
    payload: SignupOtpVerifyRequest,
    otp_service: SignupOtpService = Depends(get_signup_otp_service),
) -> MessageResponse:
    await otp_service.verify_signup_otp(payload.mobile_number, payload.otp)
    return MessageResponse(message="Mobile number verified.")


@router.post(
    "/register",
    response_model=UserDetailResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new end-user account",
)
async def register(
    register_data: RegisterRequest,
    user_service: UserService = Depends(get_user_service),
    otp_service: SignupOtpService = Depends(get_signup_otp_service),
) -> UserDetailResponse:
    """Public self-registration with verified mobile OTP."""
    await otp_service.consume_verified_otp(
        register_data.mobile_number, register_data.otp
    )
    return await user_service.register_public_user(
        email=register_data.email,
        password=register_data.password,
        mobile_number=register_data.mobile_number,
        name=register_data.name,
        referral_code=register_data.referral_code,
        referral_scheme_grams=register_data.referral_scheme_grams,
        device_id=register_data.device_id,
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
