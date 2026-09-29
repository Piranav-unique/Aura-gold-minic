"""Admin TOTP 2-factor authentication service.

Provides TOTP setup, verification, and enforcement for admin users.
Uses pyotp (RFC 6238) with 30-second windows. Secrets are stored
encrypted using the same Fernet key as KYC data.

Usage:
    # 1. Generate setup URI  →  show QR in admin settings
    uri = admin_totp_service.generate_setup_uri(user)

    # 2. User scans QR with Authenticator app, submits one code to confirm
    admin_totp_service.enable_totp(user, code="123456")

    # 3. On each sensitive admin action, call the dependency:
    #    current_user: User = Depends(require_admin_2fa)
"""

import base64
import hashlib
from typing import Optional

import pyotp
from cryptography.fernet import Fernet, InvalidToken

from app.core.config import settings
from app.core.exceptions import AuthenticationException, ValidationException
from app.core.logging import logger
from app.models.user import User
from app.repositories.user import UserRepository


# ------------------------------------------------------------------ #
# Encryption helpers (same key derivation as kyc_crypto.py)          #
# ------------------------------------------------------------------ #

def _fernet() -> Fernet:
    digest = hashlib.sha256(settings.SECRET_KEY.encode()).digest()
    key = base64.urlsafe_b64encode(digest)
    return Fernet(key)


def _encrypt_secret(plain: str) -> str:
    return _fernet().encrypt(plain.encode()).decode()


def _decrypt_secret(token: str) -> str:
    try:
        return _fernet().decrypt(token.encode()).decode()
    except (InvalidToken, Exception) as exc:
        logger.error("totp_secret_decrypt_failed", error=str(exc))
        raise AuthenticationException("2FA secret decryption failed — contact support.")


# ------------------------------------------------------------------ #
# TOTP Service                                                        #
# ------------------------------------------------------------------ #

class AdminTotpService:
    """Handles TOTP 2FA lifecycle for admin users."""

    _ISSUER = "Aurum Gold & Silvers"

    def __init__(self, user_repo: UserRepository) -> None:
        self.user_repo = user_repo

    # ---- Setup ---------------------------------------------------- #

    def generate_setup_uri(self, user: User) -> tuple[str, str]:
        """Generate a new TOTP secret and provisioning URI.

        The secret is NOT saved yet — the user must confirm with a valid code
        via ``confirm_and_enable_totp`` before it is persisted.

        Returns:
            (raw_secret_b32, otpauth_uri)  — store raw_secret in session,
            NOT in DB, until confirmed.
        """
        raw_secret = pyotp.random_base32()
        totp = pyotp.TOTP(raw_secret)
        account_name = user.email or user.mobile_number or str(user.id)
        uri = totp.provisioning_uri(name=account_name, issuer_name=self._ISSUER)
        return raw_secret, uri

    async def confirm_and_enable_totp(
        self,
        user: User,
        *,
        raw_secret: str,
        code: str,
    ) -> None:
        """Verify the first TOTP code then encrypt and save the secret.

        Raises ValidationException if the code is wrong.
        """
        totp = pyotp.TOTP(raw_secret)
        if not totp.verify(code, valid_window=1):
            raise ValidationException("Invalid authenticator code. Please try again.")

        user.totp_secret_encrypted = _encrypt_secret(raw_secret)
        user.totp_enabled = True
        await self.user_repo.db.commit()

    async def disable_totp(
        self,
        user: User,
        *,
        code: str,
    ) -> None:
        """Disable TOTP after confirming a valid code.

        Requires the current TOTP code to prevent accidental or
        malicious 2FA removal.
        """
        self._assert_totp_enabled(user)
        self._verify_code_or_raise(user, code)

        user.totp_secret_encrypted = None
        user.totp_enabled = False
        await self.user_repo.db.commit()

    # ---- Verification --------------------------------------------- #

    def verify_code(self, user: User, code: str) -> bool:
        """Return True if the TOTP code is valid for this user.

        Accepts current window ±1 (±30 s) to tolerate clock skew.
        """
        if not user.totp_enabled or not user.totp_secret_encrypted:
            return False
        try:
            raw_secret = _decrypt_secret(user.totp_secret_encrypted)
            totp = pyotp.TOTP(raw_secret)
            return totp.verify(code, valid_window=1)
        except Exception:
            return False

    def assert_2fa_verified(self, user: User, code: str) -> None:
        """Raise AuthenticationException if 2FA is enabled and the code is wrong.

        If 2FA is NOT enabled, this is a no-op (non-blocking).
        Admin routes that must REQUIRE 2FA should call
        ``assert_2fa_required_and_verified`` instead.
        """
        if user.totp_enabled and not self.verify_code(user, code):
            raise AuthenticationException(
                "Invalid authenticator code. Access denied."
            )

    def assert_2fa_required_and_verified(self, user: User, code: Optional[str]) -> None:
        """Raise if user is admin/superuser but has no 2FA, or if code is wrong.

        This enforces that all superusers/admins MUST have 2FA active
        to perform high-privilege operations.
        """
        is_admin = user.is_superuser or bool(user.roles)
        if not is_admin:
            return  # Non-admin users are not subject to this check

        if not user.totp_enabled:
            # Admin has not set up 2FA yet — block the action
            raise AuthenticationException(
                "Admin 2FA is not configured. Please set up two-factor authentication "
                "in your security settings before performing this action."
            )

        if not code:
            raise AuthenticationException(
                "A valid authenticator code is required for this action."
            )

        if not self.verify_code(user, code):
            raise AuthenticationException(
                "Invalid authenticator code. Access denied."
            )

    # ---- Internal helpers ----------------------------------------- #

    @staticmethod
    def _assert_totp_enabled(user: User) -> None:
        if not user.totp_enabled or not user.totp_secret_encrypted:
            raise ValidationException("2FA is not enabled on this account.")

    def _verify_code_or_raise(self, user: User, code: str) -> None:
        if not self.verify_code(user, code):
            raise AuthenticationException("Invalid authenticator code.")
