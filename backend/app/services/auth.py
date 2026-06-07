import uuid
from datetime import datetime, timezone
from typing import Optional

from app.core.exceptions import AuthenticationException
from app.core.logging import logger
from app.core.security import (
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.models.user import User
from app.repositories.user import UserRepository
from app.repositories.token_blacklist import TokenBlacklistRepository
from app.schemas.auth import Token
from app.services.audit import AuditService


class AuthService:
    """Service class encapsulating authentication business logic."""

    def __init__(
        self,
        user_repo: UserRepository,
        token_blacklist_repo: TokenBlacklistRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.user_repo = user_repo
        self.token_blacklist_repo = token_blacklist_repo
        self.audit_service = audit_service

    async def authenticate_user(self, email: str, password: str) -> User:
        """Authenticate user credentials and return the active User object."""
        try:
            user = await self.user_repo.get_by_email(email)
            if not user:
                raise AuthenticationException("Incorrect email or password")

            if not verify_password(password, user.hashed_password):
                raise AuthenticationException("Incorrect email or password")

            if not user.is_active:
                raise AuthenticationException("Incorrect email or password")

            if self.audit_service:
                await self.audit_service.log_action(
                    user_id=user.id,
                    action="login_success",
                    entity_type="User",
                    entity_id=str(user.id),
                    metadata={"email": email},
                )
            return user
        except AuthenticationException as e:
            if self.audit_service:
                await self.audit_service.log_action(
                    user_id=None,
                    action="login_failure",
                    entity_type="User",
                    metadata={"email": email, "reason": e.message},
                )
            raise e

    async def refresh_tokens(self, refresh_token_str: str) -> Token:
        """Perform refresh token rotation (RTR) and return a new token pair."""
        # Decode and validate refresh token
        payload = decode_token(refresh_token_str)

        if payload.get("type") != "refresh":
            raise AuthenticationException("Invalid token type")

        jti = payload.get("jti")
        sub = payload.get("sub")
        exp = payload.get("exp")

        if not jti or not sub or not exp:
            raise AuthenticationException("Invalid token payload")

        # Check blacklist
        if await self.token_blacklist_repo.is_blacklisted(jti):
            logger.warning(
                "security_compromise_attempt",
                message="Re-use of revoked refresh token detected. Potential token theft!",
                jti=jti,
                user_id=sub,
            )
            raise AuthenticationException("Invalid or revoked refresh token")

        # Fetch and verify user
        try:
            user_id = uuid.UUID(sub)
        except ValueError:
            raise AuthenticationException("Invalid user identifier in token")

        user = await self.user_repo.get(user_id)
        if not user or user.is_deleted or not user.is_active:
            raise AuthenticationException("User account is inactive or not found")

        # Blacklist the old refresh token
        expires_at = datetime.fromtimestamp(exp, tz=timezone.utc)
        await self.token_blacklist_repo.blacklist_token(jti, expires_at)

        # Generate new pair
        new_jti = str(uuid.uuid4())
        new_access_token = create_access_token(subject=user.id)
        new_refresh_token = create_refresh_token(subject=user.id, jti=new_jti)

        return Token(
            access_token=new_access_token,
            refresh_token=new_refresh_token,
        )

    async def logout_user(self, refresh_token_str: str) -> None:
        """Revoke a refresh token by blacklisting its JTI."""
        try:
            payload = decode_token(refresh_token_str)
        except AuthenticationException as e:
            # If token is already invalid/expired, logout is effectively successful
            # but we'll raise an error or just return. Let's raise if they pass an invalid token.
            raise e

        if payload.get("type") != "refresh":
            raise AuthenticationException("Invalid token type")

        jti = payload.get("jti")
        exp = payload.get("exp")
        sub = payload.get("sub")

        if not jti or not exp:
            raise AuthenticationException("Invalid token payload")

        # Check if already blacklisted to avoid duplicate records
        if not await self.token_blacklist_repo.is_blacklisted(jti):
            expires_at = datetime.fromtimestamp(exp, tz=timezone.utc)
            await self.token_blacklist_repo.blacklist_token(jti, expires_at)

            # Log logout action
            if self.audit_service and sub:
                try:
                    user_id = uuid.UUID(sub)
                    await self.audit_service.log_action(
                        user_id=user_id,
                        action="logout",
                        entity_type="User",
                        entity_id=str(user_id),
                    )
                except ValueError:
                    pass

    async def get_user_by_id(self, user_id: uuid.UUID) -> User:
        """Fetch and return an active user by ID, raising if invalid."""
        user = await self.user_repo.get(user_id)
        if not user or user.is_deleted or not user.is_active:
            raise AuthenticationException("User account is inactive or not found")
        return user
