"""Admin TOTP 2FA API endpoints.

Provides endpoints for admin users to:
  - GET  /admin/2fa/setup    — generate a new TOTP secret + QR provisioning URI
  - POST /admin/2fa/enable   — confirm first code and activate 2FA
  - POST /admin/2fa/disable  — deactivate 2FA (requires valid code)
  - POST /admin/2fa/verify   — verify a code (used by other endpoints to gate actions)
  - GET  /admin/2fa/status   — check whether 2FA is enabled on the account
"""

from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_audit_service, get_current_user, get_user_repository
from app.core import audit_actions
from app.core.authorization import PermissionChecker
from app.models.user import User
from app.repositories.user import UserRepository
from app.services.admin_totp import AdminTotpService
from app.services.audit import AuditService
from pydantic import BaseModel, Field

router = APIRouter()


# ------------------------------------------------------------------ #
# Schemas                                                             #
# ------------------------------------------------------------------ #

class TotpSetupResponse(BaseModel):
    """Returned once — display QR to admin, then discard raw_secret."""
    raw_secret: str = Field(..., description="Base32 secret — store in session only, never persist client-side")
    provisioning_uri: str = Field(..., description="otpauth:// URI for QR code generation")
    instructions: str = Field(
        default=(
            "Scan the QR code in Google Authenticator, Authy, or any TOTP app. "
            "Then call POST /admin/2fa/enable with the 6-digit code to activate."
        )
    )


class TotpConfirmRequest(BaseModel):
    raw_secret: str = Field(..., min_length=16, description="Secret returned by /setup")
    code: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")


class TotpVerifyRequest(BaseModel):
    code: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")


class TotpStatusResponse(BaseModel):
    totp_enabled: bool
    message: str


# ------------------------------------------------------------------ #
# Dependency                                                          #
# ------------------------------------------------------------------ #

def get_admin_totp_service(
    user_repo: UserRepository = Depends(get_user_repository),
) -> AdminTotpService:
    return AdminTotpService(user_repo)


# ------------------------------------------------------------------ #
# Endpoints                                                           #
# ------------------------------------------------------------------ #

@router.get(
    "/status",
    response_model=TotpStatusResponse,
    summary="Check whether admin 2FA is enabled on your account",
)
async def get_2fa_status(
    current_user: User = Depends(get_current_user),
) -> TotpStatusResponse:
    if current_user.totp_enabled:
        return TotpStatusResponse(
            totp_enabled=True,
            message="2FA is active on your account.",
        )
    return TotpStatusResponse(
        totp_enabled=False,
        message="2FA is not configured. Set it up to protect high-privilege actions.",
    )


@router.get(
    "/setup",
    response_model=TotpSetupResponse,
    summary="Generate TOTP secret and provisioning URI (admin only)",
)
async def setup_2fa(
    current_user: User = Depends(PermissionChecker("users.view")),
    totp_service: AdminTotpService = Depends(get_admin_totp_service),
) -> TotpSetupResponse:
    """Generate a new TOTP secret. The secret is NOT saved until /enable is called with a valid code."""
    raw_secret, uri = totp_service.generate_setup_uri(current_user)
    return TotpSetupResponse(raw_secret=raw_secret, provisioning_uri=uri)


@router.post(
    "/enable",
    response_model=TotpStatusResponse,
    status_code=status.HTTP_200_OK,
    summary="Enable TOTP 2FA by confirming the first authenticator code",
)
async def enable_2fa(
    body: TotpConfirmRequest,
    current_user: User = Depends(PermissionChecker("users.view")),
    totp_service: AdminTotpService = Depends(get_admin_totp_service),
    audit_service: AuditService = Depends(get_audit_service),
) -> TotpStatusResponse:
    await totp_service.confirm_and_enable_totp(
        current_user,
        raw_secret=body.raw_secret,
        code=body.code,
    )
    await audit_service.log_action(
        user_id=current_user.id,
        action=audit_actions.ADMIN_2FA_ENABLED,
        entity_type="User",
        entity_id=str(current_user.id),
    )
    return TotpStatusResponse(
        totp_enabled=True,
        message="Two-factor authentication has been enabled on your account.",
    )


@router.post(
    "/disable",
    response_model=TotpStatusResponse,
    status_code=status.HTTP_200_OK,
    summary="Disable TOTP 2FA — requires a valid current code",
)
async def disable_2fa(
    body: TotpVerifyRequest,
    current_user: User = Depends(PermissionChecker("users.view")),
    totp_service: AdminTotpService = Depends(get_admin_totp_service),
    audit_service: AuditService = Depends(get_audit_service),
) -> TotpStatusResponse:
    await totp_service.disable_totp(current_user, code=body.code)
    await audit_service.log_action(
        user_id=current_user.id,
        action=audit_actions.ADMIN_2FA_DISABLED,
        entity_type="User",
        entity_id=str(current_user.id),
    )
    return TotpStatusResponse(
        totp_enabled=False,
        message="Two-factor authentication has been disabled.",
    )


@router.post(
    "/verify",
    response_model=TotpStatusResponse,
    status_code=status.HTTP_200_OK,
    summary="Verify a TOTP code (used to gate high-privilege admin actions)",
)
async def verify_2fa_code(
    body: TotpVerifyRequest,
    current_user: User = Depends(get_current_user),
    totp_service: AdminTotpService = Depends(get_admin_totp_service),
    audit_service: AuditService = Depends(get_audit_service),
) -> TotpStatusResponse:
    """Returns 200 on success, 401 on invalid code."""
    is_valid = totp_service.verify_code(current_user, body.code)
    action = audit_actions.ADMIN_2FA_VERIFIED if is_valid else audit_actions.ADMIN_2FA_FAILED
    await audit_service.log_action(
        user_id=current_user.id,
        action=action,
        entity_type="User",
        entity_id=str(current_user.id),
    )
    if not is_valid:
        from app.core.exceptions import AuthenticationException
        raise AuthenticationException("Invalid authenticator code.")

    return TotpStatusResponse(
        totp_enabled=current_user.totp_enabled,
        message="Authenticator code verified successfully.",
    )
