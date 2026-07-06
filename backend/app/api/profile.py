from fastapi import APIRouter, Depends, Query, status
from typing import Optional

from fastapi.responses import Response


from app.api.dependencies import (
    get_admin_wallet_service,
    get_current_user,
    get_kyc_service,
    get_profile_service,
)

from app.models.user import User

from app.schemas.profile import (
    ProfileResponse,
    ProfileUpdate,
    ChangePasswordRequest,
    AvatarUploadRequest,
    ProfileActivityResponse,
    UserSettingsResponse,
    UserSettingsUpdate,
    AadhaarOtpRequest,
    AadhaarOtpResponse,
    AadhaarVerifyRequest,
    PanLinkVerifyRequest,
    KycStatusResponse,
)

from app.schemas.base import MessageResponse

from app.core.kyc_profile import mask_mobile
from app.schemas.admin_wallet import WalletTransactionListResponse
from app.services.profile import ProfileService
from app.services.kyc import KycService
from app.services.admin_wallet import AdminWalletService


router = APIRouter()


def _to_profile_response(user: User) -> ProfileResponse:

    return ProfileResponse(
        id=user.id,
        email=user.email,
        mobile_number=user.mobile_number,
        first_name=user.first_name,
        last_name=user.last_name,
        is_active=user.is_active,
        is_superuser=user.is_superuser,
        roles=user.roles,
        has_avatar=bool(user.avatar_base64),
        created_at=user.created_at,
        updated_at=user.updated_at,
    )


@router.get(
    "/",
    response_model=ProfileResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current user profile with roles",
)
async def get_profile(
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> ProfileResponse:

    user = await profile_service.get_profile(current_user.id)

    return _to_profile_response(user)


@router.put(
    "/",
    response_model=ProfileResponse,
    status_code=status.HTTP_200_OK,
    summary="Update current user profile",
)
async def update_profile(
    profile_in: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> ProfileResponse:

    user = await profile_service.update_profile(current_user.id, profile_in)

    return _to_profile_response(user)


@router.post(
    "/change-password",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Change current user password",
)
async def change_password(
    password_in: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> MessageResponse:

    await profile_service.change_password(current_user.id, password_in)

    return MessageResponse(
        message="Password changed successfully. Please log in again on all devices."
    )


@router.get(
    "/avatar",
    status_code=status.HTTP_200_OK,
    summary="Get current user avatar image",
    responses={200: {"content": {"image/*": {}}}},
)
async def get_avatar(
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> Response:

    image_bytes, content_type = await profile_service.get_avatar(current_user.id)

    return Response(content=image_bytes, media_type=content_type)


@router.post(
    "/avatar",
    response_model=ProfileResponse,
    status_code=status.HTTP_200_OK,
    summary="Upload avatar as base64",
)
async def upload_avatar(
    avatar_in: AvatarUploadRequest,
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> ProfileResponse:

    user = await profile_service.upload_avatar(current_user.id, avatar_in)

    return _to_profile_response(user)


@router.get(
    "/activity",
    response_model=ProfileActivityResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current user activity summary",
)
async def get_profile_activity(
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> ProfileActivityResponse:

    items, total = await profile_service.get_activity(current_user.id)

    return ProfileActivityResponse(items=items, total=total)


@router.get(
    "/settings",
    response_model=UserSettingsResponse,
    status_code=status.HTTP_200_OK,
    summary="Get user settings",
)
async def get_settings(
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> UserSettingsResponse:

    return await profile_service.get_settings(current_user.id)


@router.put(
    "/settings",
    response_model=UserSettingsResponse,
    status_code=status.HTTP_200_OK,
    summary="Update user settings",
)
async def update_settings(
    settings_in: UserSettingsUpdate,
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> UserSettingsResponse:

    return await profile_service.update_settings(current_user.id, settings_in)


@router.get(
    "/kyc/status",
    response_model=KycStatusResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current user KYC verification status",
)
async def get_kyc_status(
    current_user: User = Depends(get_current_user),
    kyc_service: KycService = Depends(get_kyc_service),
) -> KycStatusResponse:
    return await kyc_service.get_status(current_user.id)


@router.post(
    "/kyc/aadhaar/otp",
    response_model=AadhaarOtpResponse,
    status_code=status.HTTP_200_OK,
    summary="Send Aadhaar OTP via UIDAI (Sandbox)",
)
async def send_aadhaar_otp(
    body: AadhaarOtpRequest,
    current_user: User = Depends(get_current_user),
    kyc_service: KycService = Depends(get_kyc_service),
) -> AadhaarOtpResponse:
    reference_id = await kyc_service.send_aadhaar_otp(
        current_user.id, body.aadhaar_number
    )
    return AadhaarOtpResponse(
        reference_id=reference_id,
        registered_mobile_masked=mask_mobile(current_user.mobile_number),
    )


@router.post(
    "/kyc/aadhaar/verify",
    response_model=KycStatusResponse,
    status_code=status.HTTP_200_OK,
    summary="Verify Aadhaar OTP",
)
async def verify_aadhaar_otp(
    body: AadhaarVerifyRequest,
    current_user: User = Depends(get_current_user),
    kyc_service: KycService = Depends(get_kyc_service),
) -> KycStatusResponse:
    return await kyc_service.verify_aadhaar_otp(
        current_user.id,
        body.reference_id,
        body.otp,
        body.aadhaar_number,
    )


@router.post(
    "/kyc/pan/verify",
    response_model=KycStatusResponse,
    status_code=status.HTTP_200_OK,
    summary="Verify PAN is linked with verified Aadhaar (Sandbox)",
)
async def verify_pan_link(
    body: PanLinkVerifyRequest,
    current_user: User = Depends(get_current_user),
    kyc_service: KycService = Depends(get_kyc_service),
) -> KycStatusResponse:
    return await kyc_service.verify_pan_aadhaar_link(
        current_user.id, body.pan_number
    )


@router.get(
    "/statements",
    response_model=WalletTransactionListResponse,
    status_code=status.HTTP_200_OK,
    summary="List current user's buy, sell, and wallet activity",
)
async def list_my_statements(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    transaction_type: Optional[str] = Query(
        None, description="Filter: BUY, SELL, REFERRAL, or SAVINGS"
    ),
    current_user: User = Depends(get_current_user),
    wallet_service: AdminWalletService = Depends(get_admin_wallet_service),
) -> WalletTransactionListResponse:
    return await wallet_service.list_user_transactions(
        current_user.id,
        skip=skip,
        limit=limit,
        transaction_type=transaction_type,
    )
