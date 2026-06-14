import uuid
from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import AuthenticationException
from app.core.security import decode_token, validate_token_version
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
from app.repositories.notification import NotificationRepository
from app.repositories.user_settings import UserSettingsRepository
from app.services.audit import AuditService
from app.services.notification import NotificationService
from app.services.profile import ProfileService
from app.services.dashboard import DashboardService
from app.repositories.customer import CustomerRepository
from app.repositories.supplier import SupplierRepository
from app.repositories.inventory_item import InventoryItemRepository
from app.repositories.stock_movement import StockMovementRepository
from app.services.customer import CustomerService
from app.services.supplier import SupplierService
from app.services.inventory import InventoryService
from app.repositories.transaction import TransactionRepository
from app.repositories.report import ReportRepository
from app.repositories.workflow import WorkflowRepository
from app.services.executive_dashboard import ExecutiveDashboardService
from app.services.transaction import TransactionService
from app.services.report import ReportService
from app.services.workflow import WorkflowService

# Setup oauth2 scheme for bearer tokens
reusable_oauth2 = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login")


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


def get_notification_repository(
    db: AsyncSession = Depends(get_db_session),
) -> NotificationRepository:
    """Dependency injecting the NotificationRepository."""
    return NotificationRepository(db)


def get_user_settings_repository(
    db: AsyncSession = Depends(get_db_session),
) -> UserSettingsRepository:
    """Dependency injecting the UserSettingsRepository."""
    return UserSettingsRepository(db)


def get_notification_service(
    notification_repo: NotificationRepository = Depends(get_notification_repository),
    user_repo: UserRepository = Depends(get_user_repository),
    settings_repo: UserSettingsRepository = Depends(get_user_settings_repository),
) -> NotificationService:
    """Dependency injecting the NotificationService."""
    return NotificationService(notification_repo, user_repo, settings_repo)


def get_audit_service(
    audit_repo: AuditLogRepository = Depends(get_audit_repository),
    notification_service: NotificationService = Depends(get_notification_service),
) -> AuditService:
    """Dependency injecting the AuditService."""
    return AuditService(audit_repo, notification_service)


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

    user = await user_repo.get_with_roles_and_permissions(user_id)
    if not user or user.is_deleted or not user.is_active:
        raise AuthenticationException("User account is inactive or not found")

    validate_token_version(payload, user.token_version or 0)
    return user


def get_user_service(
    user_repo: UserRepository = Depends(get_user_repository),
    role_repo: RoleRepository = Depends(get_role_repository),
    audit_service: AuditService = Depends(get_audit_service),
) -> UserService:
    """Dependency injecting the UserService."""
    return UserService(user_repo, role_repo, audit_service)


def get_profile_service(
    user_repo: UserRepository = Depends(get_user_repository),
    settings_repo: UserSettingsRepository = Depends(get_user_settings_repository),
    audit_service: AuditService = Depends(get_audit_service),
) -> ProfileService:
    """Dependency injecting the ProfileService."""
    return ProfileService(user_repo, settings_repo, audit_service)


def get_customer_repository(
    db: AsyncSession = Depends(get_db_session),
) -> CustomerRepository:
    """Dependency injecting the CustomerRepository."""
    return CustomerRepository(db)


def get_customer_service(
    customer_repo: CustomerRepository = Depends(get_customer_repository),
    audit_service: AuditService = Depends(get_audit_service),
) -> CustomerService:
    """Dependency injecting the CustomerService."""
    return CustomerService(customer_repo, audit_service)


def get_supplier_repository(
    db: AsyncSession = Depends(get_db_session),
) -> SupplierRepository:
    """Dependency injecting the SupplierRepository."""
    return SupplierRepository(db)


def get_inventory_item_repository(
    db: AsyncSession = Depends(get_db_session),
) -> InventoryItemRepository:
    """Dependency injecting the InventoryItemRepository."""
    return InventoryItemRepository(db)


def get_stock_movement_repository(
    db: AsyncSession = Depends(get_db_session),
) -> StockMovementRepository:
    """Dependency injecting the StockMovementRepository."""
    return StockMovementRepository(db)


def get_supplier_service(
    supplier_repo: SupplierRepository = Depends(get_supplier_repository),
    audit_service: AuditService = Depends(get_audit_service),
) -> SupplierService:
    """Dependency injecting the SupplierService."""
    return SupplierService(supplier_repo, audit_service)


def get_inventory_service(
    inventory_repo: InventoryItemRepository = Depends(get_inventory_item_repository),
    movement_repo: StockMovementRepository = Depends(get_stock_movement_repository),
    supplier_repo: SupplierRepository = Depends(get_supplier_repository),
    audit_service: AuditService = Depends(get_audit_service),
) -> InventoryService:
    """Dependency injecting the InventoryService."""
    return InventoryService(inventory_repo, movement_repo, supplier_repo, audit_service)


def get_transaction_repository(
    db: AsyncSession = Depends(get_db_session),
) -> TransactionRepository:
    """Dependency injecting the TransactionRepository."""
    return TransactionRepository(db)


def get_report_repository(
    db: AsyncSession = Depends(get_db_session),
) -> ReportRepository:
    """Dependency injecting the ReportRepository."""
    return ReportRepository(db)


def get_report_service(
    report_repo: ReportRepository = Depends(get_report_repository),
    audit_service: AuditService = Depends(get_audit_service),
) -> ReportService:
    """Dependency injecting the ReportService."""
    return ReportService(report_repo, audit_service)


def get_transaction_service(
    transaction_repo: TransactionRepository = Depends(get_transaction_repository),
    customer_repo: CustomerRepository = Depends(get_customer_repository),
    inventory_repo: InventoryItemRepository = Depends(get_inventory_item_repository),
    customer_service: CustomerService = Depends(get_customer_service),
    inventory_service: InventoryService = Depends(get_inventory_service),
    audit_service: AuditService = Depends(get_audit_service),
) -> TransactionService:
    """Dependency injecting the TransactionService."""
    return TransactionService(
        transaction_repo,
        customer_repo,
        inventory_repo,
        customer_service,
        inventory_service,
        audit_service,
    )


def get_workflow_repository(
    db: AsyncSession = Depends(get_db_session),
) -> WorkflowRepository:
    """Dependency injecting the WorkflowRepository."""
    return WorkflowRepository(db)


def get_workflow_service(
    workflow_repo: WorkflowRepository = Depends(get_workflow_repository),
    user_repo: UserRepository = Depends(get_user_repository),
    audit_service: AuditService = Depends(get_audit_service),
    notification_service: NotificationService = Depends(get_notification_service),
) -> WorkflowService:
    """Dependency injecting the WorkflowService."""
    return WorkflowService(
        workflow_repo,
        user_repo,
        audit_service,
        notification_service,
    )


def get_executive_dashboard_service(
    audit_service: AuditService = Depends(get_audit_service),
    notification_service: NotificationService = Depends(get_notification_service),
    customer_repo: CustomerRepository = Depends(get_customer_repository),
    user_repo: UserRepository = Depends(get_user_repository),
    workflow_repo: WorkflowRepository = Depends(get_workflow_repository),
    report_repo: ReportRepository = Depends(get_report_repository),
    inventory_service: InventoryService = Depends(get_inventory_service),
    transaction_service: TransactionService = Depends(get_transaction_service),
) -> ExecutiveDashboardService:
    """Dependency injecting the ExecutiveDashboardService."""
    return ExecutiveDashboardService(
        audit_service,
        notification_service,
        customer_repo,
        user_repo,
        workflow_repo,
        report_repo,
        inventory_service,
        transaction_service,
    )


def get_dashboard_service(
    audit_service: AuditService = Depends(get_audit_service),
    notification_service: NotificationService = Depends(get_notification_service),
    inventory_service: InventoryService = Depends(get_inventory_service),
    transaction_service: TransactionService = Depends(get_transaction_service),
) -> DashboardService:
    """Dependency injecting the DashboardService."""
    return DashboardService(
        audit_service, notification_service, inventory_service, transaction_service
    )
