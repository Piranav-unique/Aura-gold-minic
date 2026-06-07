import uuid
from datetime import datetime, timezone
from typing import List, Optional

from app.core.exceptions import (
    ForbiddenException,
    NotFoundException,
    ValidationException,
)
from app.core.security import get_password_hash
from app.models.user import User
from app.repositories.user import UserRepository
from app.repositories.role import RoleRepository
from app.schemas.user import UserCreate, UserUpdate
from app.services.audit import AuditService


class UserService:
    """Service class encapsulating User management business logic."""

    def __init__(
        self,
        user_repo: UserRepository,
        role_repo: RoleRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.user_repo = user_repo
        self.role_repo = role_repo
        self.audit_service = audit_service

    async def create_user(
        self, user_in: UserCreate, performing_user_id: Optional[uuid.UUID] = None
    ) -> User:
        """Create a new user with password hashing, optional roles, and audit logging."""
        existing = await self.user_repo.get_by_email(user_in.email)
        if existing:
            raise ValidationException(f"Email '{user_in.email}' already registered")

        hashed_password = get_password_hash(user_in.password)

        user_data = user_in.model_dump(exclude={"roles", "password"})
        user_data["hashed_password"] = hashed_password

        # Create user record (commit=False to associate roles first)
        user = await self.user_repo.create(user_data, commit=False)

        # Resolve roles
        if user_in.roles:
            roles = await self.role_repo.get_by_ids(user_in.roles)
            if len(roles) != len(user_in.roles):
                fetched_ids = {r.id for r in roles}
                for role_id in user_in.roles:
                    if role_id not in fetched_ids:
                        raise NotFoundException(f"Role '{role_id}' not found")
            user.roles = roles

        await self.user_repo.db.commit()
        user = await self.user_repo.get_with_roles_and_permissions(user.id)

        # Log audit action
        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action="user_create",
                entity_type="User",
                entity_id=str(user.id),
                metadata={"email": user.email},
            )

        return user

    async def get_user_by_id(self, user_id: uuid.UUID) -> User:
        """Fetch active user by ID, raising NotFound if missing."""
        user = await self.user_repo.get_with_roles_and_permissions(user_id)
        if not user:
            raise NotFoundException("User not found")
        return user

    async def list_users(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        is_active: Optional[bool] = None,
        is_superuser: Optional[bool] = None,
        role_id: Optional[uuid.UUID] = None,
    ) -> List[User]:
        """Fetch users matching filters and search keywords."""
        return await self.user_repo.list_users(
            skip=skip,
            limit=limit,
            search=search,
            is_active=is_active,
            is_superuser=is_superuser,
            role_id=role_id,
        )

    async def update_user(
        self,
        user_id: uuid.UUID,
        user_in: UserUpdate,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> User:
        """Update an existing user's attributes and roles, and log update event."""
        user = await self.user_repo.get_with_roles_and_permissions(user_id)
        if not user:
            raise NotFoundException("User not found")

        update_data = user_in.model_dump(
            exclude_unset=True, exclude={"roles", "password"}
        )

        performing_user = None
        if performing_user_id:
            performing_user = await self.user_repo.get_with_roles_and_permissions(
                performing_user_id
            )

        if performing_user and not performing_user.is_superuser:
            if "is_superuser" in update_data:
                raise ForbiddenException("Only superusers may modify superuser status")
            if user_in.roles is not None:
                raise ForbiddenException("Only superusers may modify user roles")

        if "email" in update_data and update_data["email"] != user.email:
            existing = await self.user_repo.get_by_email(update_data["email"])
            if existing:
                raise ValidationException(
                    f"Email '{update_data['email']}' already registered"
                )

        if user_in.password is not None:
            user.hashed_password = get_password_hash(user_in.password)

        # Update basic fields
        for field, value in update_data.items():
            setattr(user, field, value)

        # Update roles if provided
        if user_in.roles is not None:
            roles = []
            if user_in.roles:
                roles = await self.role_repo.get_by_ids(user_in.roles)
                if len(roles) != len(user_in.roles):
                    fetched_ids = {r.id for r in roles}
                    for role_id in user_in.roles:
                        if role_id not in fetched_ids:
                            raise NotFoundException(f"Role '{role_id}' not found")
            user.roles = roles

        await self.user_repo.db.commit()
        user = await self.user_repo.get_with_roles_and_permissions(user.id)

        # Log audit action
        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action="user_update",
                entity_type="User",
                entity_id=str(user.id),
                metadata={"updated_fields": list(update_data.keys())},
            )

        return user

    async def delete_user(
        self, user_id: uuid.UUID, performing_user_id: Optional[uuid.UUID] = None
    ) -> bool:
        """Soft-delete a user by flagging 'is_deleted' and logging event."""
        user = await self.user_repo.get(user_id)
        if not user:
            raise NotFoundException("User not found")

        user.is_deleted = True
        user.deleted_at = datetime.now(timezone.utc)
        await self.user_repo.db.commit()

        # Log audit action
        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action="user_delete",
                entity_type="User",
                entity_id=str(user_id),
            )

        return True
