import uuid
from typing import Any, List, Optional

from app.core.exceptions import NotFoundException, ValidationException
from app.models.role import Role
from app.models.permission import Permission
from app.models.user import User
from app.repositories.role import RoleRepository
from app.repositories.permission import PermissionRepository
from app.repositories.user import UserRepository
from app.schemas.rbac import RoleCreate, RoleUpdate, PermissionCreate
from app.services.audit import AuditService


class RbacService:
    """Service class encapsulating RBAC business logic."""

    def __init__(
        self,
        role_repo: RoleRepository,
        permission_repo: PermissionRepository,
        user_repo: UserRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.role_repo = role_repo
        self.permission_repo = permission_repo
        self.user_repo = user_repo
        self.audit_service = audit_service

    async def create_role(self, role_in: RoleCreate) -> Role:
        """Create a new role, enforcing name uniqueness."""
        existing = await self.role_repo.get_by_name(role_in.name)
        if existing:
            raise ValidationException(f"Role '{role_in.name}' already exists")
        return await self.role_repo.create(role_in.model_dump())

    async def list_roles(self, skip: int = 0, limit: int = 100) -> List[Role]:
        """Fetch a list of active roles."""
        return await self.role_repo.list(skip=skip, limit=limit)

    async def get_role_by_id(self, role_id: uuid.UUID) -> Role:
        """Fetch a role by ID with permissions loaded, raising NotFound if missing."""
        role = await self.role_repo.get_with_permissions(role_id)
        if not role:
            raise NotFoundException("Role not found")
        return role

    async def update_role(self, role_id: uuid.UUID, role_in: RoleUpdate) -> Role:
        """Update role attributes, enforcing name uniqueness if changed."""
        role = await self.role_repo.get_with_permissions(role_id)
        if not role:
            raise NotFoundException("Role not found")

        update_data = role_in.model_dump(exclude_unset=True)
        if "name" in update_data and update_data["name"] != role.name:
            existing = await self.role_repo.get_by_name(update_data["name"])
            if existing:
                raise ValidationException(
                    f"Role '{update_data['name']}' already exists"
                )

        return await self.role_repo.update(role, update_data)

    async def delete_role(self, role_id: uuid.UUID) -> bool:
        """Soft-delete a role by ID."""
        role = await self.role_repo.get(role_id)
        if not role:
            raise NotFoundException("Role not found")
        await self.role_repo.db.delete(role)
        await self.role_repo.db.commit()
        return True

    async def create_permission(self, perm_in: PermissionCreate) -> Permission:
        """Create a new permission, enforcing name uniqueness."""
        existing = await self.permission_repo.get_by_name(perm_in.name)
        if existing:
            raise ValidationException(
                f"Permission '{perm_in.name}' already exists"
            )
        return await self.permission_repo.create(perm_in.model_dump())

    async def list_permissions(
        self, skip: int = 0, limit: int = 100
    ) -> List[Permission]:
        """Fetch a list of permissions."""
        return await self.permission_repo.list(skip=skip, limit=limit)

    async def assign_role_to_user(
        self,
        user_id: uuid.UUID,
        role_id: uuid.UUID,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> User:
        """Associate a role with a user, and log audit event."""
        user = await self.user_repo.get_with_roles_and_permissions(user_id)
        if not user:
            raise NotFoundException("User not found")

        role = await self.role_repo.get(role_id)
        if not role:
            raise NotFoundException("Role not found")

        if role not in user.roles:
            user.roles.append(role)
            await self.user_repo.db.commit()
            await self.user_repo.db.refresh(user)

            # Log audit action
            if self.audit_service:
                await self.audit_service.log_action(
                    user_id=performing_user_id,
                    action="role_assign",
                    entity_type="User",
                    entity_id=str(user_id),
                    metadata={"role_id": str(role_id), "role_name": role.name},
                )

        return user

    async def remove_role_from_user(
        self,
        user_id: uuid.UUID,
        role_id: uuid.UUID,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> User:
        """Dissociate a role from a user, and log audit event."""
        user = await self.user_repo.get_with_roles_and_permissions(user_id)
        if not user:
            raise NotFoundException("User not found")

        role = await self.role_repo.get(role_id)
        if not role:
            raise NotFoundException("Role not found")

        if role in user.roles:
            user.roles.remove(role)
            await self.user_repo.db.commit()
            await self.user_repo.db.refresh(user)

            # Log audit action
            if self.audit_service:
                await self.audit_service.log_action(
                    user_id=performing_user_id,
                    action="role_remove",
                    entity_type="User",
                    entity_id=str(user_id),
                    metadata={"role_id": str(role_id), "role_name": role.name},
                )

        return user

    async def assign_permission_to_role(
        self,
        role_id: uuid.UUID,
        permission_id: uuid.UUID,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> Role:
        """Map a permission to a role, and log audit event."""
        role = await self.role_repo.get_with_permissions(role_id)
        if not role:
            raise NotFoundException("Role not found")

        permission = await self.permission_repo.get(permission_id)
        if not permission:
            raise NotFoundException("Permission not found")

        if permission not in role.permissions:
            role.permissions.append(permission)
            await self.role_repo.db.commit()
            await self.role_repo.db.refresh(role)

            # Log audit action
            if self.audit_service:
                await self.audit_service.log_action(
                    user_id=performing_user_id,
                    action="permission_assign",
                    entity_type="Role",
                    entity_id=str(role_id),
                    metadata={
                        "permission_id": str(permission_id),
                        "permission_name": permission.name,
                    },
                )

        return role

    async def remove_permission_from_role(
        self,
        role_id: uuid.UUID,
        permission_id: uuid.UUID,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> Role:
        """Unmap a permission from a role, and log audit event."""
        role = await self.role_repo.get_with_permissions(role_id)
        if not role:
            raise NotFoundException("Role not found")

        permission = await self.permission_repo.get(permission_id)
        if not permission:
            raise NotFoundException("Permission not found")

        if permission in role.permissions:
            role.permissions.remove(permission)
            await self.role_repo.db.commit()
            await self.role_repo.db.refresh(role)

            # Log audit action
            if self.audit_service:
                await self.audit_service.log_action(
                    user_id=performing_user_id,
                    action="permission_remove",
                    entity_type="Role",
                    entity_id=str(role_id),
                    metadata={
                        "permission_id": str(permission_id),
                        "permission_name": permission.name,
                    },
                )

        return role
