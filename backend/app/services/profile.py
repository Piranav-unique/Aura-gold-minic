import base64
import uuid
from typing import List, Optional

from app.core.avatar import validate_and_encode_avatar
from app.core.exceptions import AuthenticationException, ValidationException
from app.core.security import verify_password, get_password_hash
from app.core import audit_actions
from app.models.user import User
from app.repositories.user import UserRepository
from app.repositories.user_settings import UserSettingsRepository
from app.schemas.profile import (
    ProfileUpdate,
    ChangePasswordRequest,
    AvatarUploadRequest,
    UserSettingsUpdate,
)
from app.services.audit import AuditService


class ProfileService:
    """Service class encapsulating self-service profile management."""

    def __init__(
        self,
        user_repo: UserRepository,
        settings_repo: UserSettingsRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.user_repo = user_repo
        self.settings_repo = settings_repo
        self.audit_service = audit_service

    async def get_profile(self, user_id: uuid.UUID) -> User:
        user = await self.user_repo.get_with_roles_and_permissions(user_id)
        if not user:
            raise ValidationException("User not found")
        return user

    async def get_avatar(self, user_id: uuid.UUID) -> tuple[bytes, str]:
        user = await self.user_repo.get(user_id)
        if not user or not user.avatar_base64:
            raise ValidationException("Avatar not found")
        content_type = user.avatar_content_type or "image/png"
        return base64.b64decode(user.avatar_base64), content_type

    async def update_profile(
        self, user_id: uuid.UUID, profile_in: ProfileUpdate
    ) -> User:
        user = await self.user_repo.get_with_roles_and_permissions(user_id)
        if not user:
            raise ValidationException("User not found")

        update_data = profile_in.model_dump(exclude_unset=True)
        current_password = update_data.pop("current_password", None)

        if "email" in update_data and update_data["email"] != user.email:
            if not current_password:
                raise ValidationException(
                    "Current password is required to change email address"
                )
            if not verify_password(current_password, user.hashed_password):
                raise AuthenticationException("Current password is incorrect")

            existing = await self.user_repo.get_by_email(update_data["email"])
            if existing:
                raise ValidationException(
                    f"Email '{update_data['email']}' already registered"
                )

        for field, value in update_data.items():
            setattr(user, field, value)

        await self.user_repo.db.commit()
        user = await self.user_repo.get_with_roles_and_permissions(user.id)

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=user_id,
                action=audit_actions.PROFILE_UPDATE,
                entity_type="User",
                entity_id=str(user_id),
                metadata={"updated_fields": list(update_data.keys())},
            )

        return user

    async def change_password(
        self, user_id: uuid.UUID, password_in: ChangePasswordRequest
    ) -> bool:
        user = await self.user_repo.get(user_id)
        if not user:
            raise ValidationException("User not found")

        if not verify_password(password_in.current_password, user.hashed_password):
            raise AuthenticationException("Current password is incorrect")

        user.hashed_password = get_password_hash(password_in.new_password)
        user.token_version = (user.token_version or 0) + 1
        await self.user_repo.db.commit()

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=user_id,
                action=audit_actions.PASSWORD_CHANGE,
                entity_type="User",
                entity_id=str(user_id),
            )

        return True

    async def upload_avatar(
        self, user_id: uuid.UUID, avatar_in: AvatarUploadRequest
    ) -> User:
        user = await self.user_repo.get_with_roles_and_permissions(user_id)
        if not user:
            raise ValidationException("User not found")

        normalized_b64, content_type = validate_and_encode_avatar(
            avatar_in.avatar_base64, avatar_in.content_type
        )

        user.avatar_base64 = normalized_b64
        user.avatar_content_type = content_type
        await self.user_repo.db.commit()

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=user_id,
                action=audit_actions.AVATAR_UPDATE,
                entity_type="User",
                entity_id=str(user_id),
                metadata={"content_type": content_type},
            )

        return await self.user_repo.get_with_roles_and_permissions(user.id)

    async def get_activity(
        self, user_id: uuid.UUID, limit: int = 20
    ) -> tuple[List, int]:
        if not self.audit_service:
            return [], 0
        items, total = await self.audit_service.list_audit_logs(
            skip=0, limit=limit, user_id=user_id
        )
        return items, total

    async def get_settings(self, user_id: uuid.UUID):
        return await self.settings_repo.get_or_create(user_id)

    async def update_settings(
        self, user_id: uuid.UUID, settings_in: UserSettingsUpdate
    ):
        settings = await self.settings_repo.get_or_create(user_id)
        update_data = settings_in.model_dump(exclude_unset=True)
        updated = await self.settings_repo.update(settings, update_data)

        if self.audit_service and update_data:
            await self.audit_service.log_action(
                user_id=user_id,
                action=audit_actions.SETTINGS_UPDATE,
                entity_type="UserSettings",
                entity_id=str(settings.id),
                metadata={"updated_fields": list(update_data.keys())},
            )

        return updated
