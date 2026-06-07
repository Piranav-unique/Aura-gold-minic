import uuid
from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import AuthenticationException
from app.core.security import decode_token
from app.database.session import get_db_session
from app.models.user import User
from app.repositories.user import UserRepository
from app.repositories.token_blacklist import TokenBlacklistRepository
from app.services.auth import AuthService

from app.repositories.role import RoleRepository
from app.repositories.permission import PermissionRepository
from app.services.rbac import RbacService
from app.services.user import UserService

from app.repositories.audit_log import AuditLogRepository
from app.services.audit import AuditService

# Setup oauth2 scheme for bearer tokens
reusable_oauth2 = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/auth/login"
)


def get_user_repository(
    db: AsyncSession = Depends(get_db_session),
) -> UserRepository:
    """Dependency injecting the UserRepository."""
    return UserRepository(db)


def get_token_blacklist_repository(
    db: AsyncSession = Depends(get_db_session),
) -> TokenBlacklistRepository:
    """Dependency injecting the TokenBlacklistRepository."""
    return TokenBlacklistRepository(db)


def get_role_repository(
    db: AsyncSession = Depends(get_db_session),
) -> RoleRepository:
    """Dependency injecting the RoleRepository."""
    return RoleRepository(db)


def get_permission_repository(
    db: AsyncSession = Depends(get_db_session),
) -> PermissionRepository:
    """Dependency injecting the PermissionRepository."""
    return PermissionRepository(db)


def get_audit_repository(
    db: AsyncSession = Depends(get_db_session),
) -> AuditLogRepository:
    """Dependency injecting the AuditLogRepository."""
    return AuditLogRepository(db)


def get_audit_service(
    audit_repo: AuditLogRepository = Depends(get_audit_repository),
) -> AuditService:
    """Dependency injecting the AuditService."""
    return AuditService(audit_repo)


def get_auth_service(
    user_repo: UserRepository = Depends(get_user_repository),
    token_blacklist_repo: TokenBlacklistRepository = Depends(
        get_token_blacklist_repository
    ),
    audit_service: AuditService = Depends(get_audit_service),
) -> AuthService:
    """Dependency injecting the AuthService."""
    return AuthService(user_repo, token_blacklist_repo, audit_service)


def get_rbac_service(
    role_repo: RoleRepository = Depends(get_role_repository),
    permission_repo: PermissionRepository = Depends(get_permission_repository),
    user_repo: UserRepository = Depends(get_user_repository),
    audit_service: AuditService = Depends(get_audit_service),
) -> RbacService:
    """Dependency injecting the RbacService."""
    return RbacService(role_repo, permission_repo, user_repo, audit_service)


async def get_current_user(
    token: str = Depends(reusable_oauth2),
    user_repo: UserRepository = Depends(get_user_repository),
) -> User:
    """Retrieve the current authenticated user with roles and permissions eager-loaded."""
    # Decode and validate access token
    payload = decode_token(token)

    if payload.get("type") != "access":
        raise AuthenticationException("Invalid token type")

    sub = payload.get("sub")
    if not sub:
        raise AuthenticationException("Invalid token payload")

    try:
        user_id = uuid.UUID(sub)
    except ValueError:
        raise AuthenticationException("Invalid user identifier in token")

    # Fetch user with eager loading of roles and nested permissions
    user = await user_repo.get_with_roles_and_permissions(user_id)
    if not user or user.is_deleted or not user.is_active:
        raise AuthenticationException("User account is inactive or not found")
    return user


def get_user_service(
    user_repo: UserRepository = Depends(get_user_repository),
    role_repo: RoleRepository = Depends(get_role_repository),
    audit_service: AuditService = Depends(get_audit_service),
) -> UserService:
    """Dependency injecting the UserService."""
    return UserService(user_repo, role_repo, audit_service)
