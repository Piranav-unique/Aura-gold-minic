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
from app.services.kyc import KycService
from app.services.sandbox_kyc import SandboxKycClient
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
from app.repositories.app_metrics import AppMetricsRepository
from app.repositories.workflow import WorkflowRepository
from app.services.executive_dashboard import ExecutiveDashboardService
from app.services.personal_dashboard import PersonalDashboardService
from app.services.metal_prices import MetalPriceService
from app.services.gold_payment import GoldPaymentService
from app.services.gold_scheme import GoldSchemeService
from app.services.razorpay_client import RazorpayClient
from app.services.razorpayx_client import RazorpayXClient
from app.repositories.payment_order import PaymentOrderRepository
from app.repositories.referral_reward import ReferralRewardRepository
from app.services.referral import ReferralService
from app.services.transaction import TransactionService
from app.services.report import ReportService
from app.services.workflow import WorkflowService
from app.repositories.bank_account import (
    BankLinkChallengeRepository,
    UserBankAccountRepository,
)
from app.repositories.signup_otp import SignupOtpRepository
from app.services.bank_account import BankAccountService
from app.services.ifsc import IfscService
from app.services.signup_otp import SignupOtpService
from app.services.sms import SmsService
from app.repositories.gold_sell_inquiry import GoldSellInquiryRepository
from app.repositories.organization_profile import OrganizationProfileRepository
from app.repositories.bank_account import UserBankAccountRepository
from app.services.gold_sell_inquiry import GoldSellInquiryService
from app.services.organization_profile import OrganizationProfileService
from app.services.sell_payout import SellPayoutService
from app.services.sell_razorpayx_payout import SellRazorpayXPayoutService
from app.repositories.admin_wallet import AdminWalletRepository
from app.services.admin_wallet import AdminWalletService
from app.repositories.digital_metal_inventory import (
    DigitalMetalInventoryMovementRepository,
    DigitalMetalInventoryRepository,
)
from app.services.digital_metal_inventory import DigitalMetalInventoryService

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


def get_referral_reward_repository(
    db: AsyncSession = Depends(get_db_session),
) -> ReferralRewardRepository:
    return ReferralRewardRepository(db)


def get_referral_service(
    user_repo: UserRepository = Depends(get_user_repository),
    reward_repo: ReferralRewardRepository = Depends(get_referral_reward_repository),
) -> ReferralService:
    return ReferralService(user_repo, reward_repo)


def get_user_service(
    user_repo: UserRepository = Depends(get_user_repository),
    role_repo: RoleRepository = Depends(get_role_repository),
    audit_service: AuditService = Depends(get_audit_service),
    referral_service: ReferralService = Depends(get_referral_service),
) -> UserService:
    """Dependency injecting the UserService."""
    return UserService(user_repo, role_repo, audit_service, referral_service)


def get_signup_otp_repository(
    db: AsyncSession = Depends(get_db_session),
) -> SignupOtpRepository:
    return SignupOtpRepository(db)


def get_sms_service() -> SmsService:
    return SmsService()


def get_signup_otp_service(
    otp_repo: SignupOtpRepository = Depends(get_signup_otp_repository),
    user_repo: UserRepository = Depends(get_user_repository),
    sms_service: SmsService = Depends(get_sms_service),
) -> SignupOtpService:
    return SignupOtpService(otp_repo, user_repo, sms_service)


def get_user_bank_account_repository(
    db: AsyncSession = Depends(get_db_session),
) -> UserBankAccountRepository:
    return UserBankAccountRepository(db)


def get_bank_link_challenge_repository(
    db: AsyncSession = Depends(get_db_session),
) -> BankLinkChallengeRepository:
    return BankLinkChallengeRepository(db)


def get_ifsc_service() -> IfscService:
    return IfscService()


def get_bank_account_service(
    bank_repo: UserBankAccountRepository = Depends(get_user_bank_account_repository),
    challenge_repo: BankLinkChallengeRepository = Depends(
        get_bank_link_challenge_repository
    ),
    sms_service: SmsService = Depends(get_sms_service),
    ifsc_service: IfscService = Depends(get_ifsc_service),
) -> BankAccountService:
    return BankAccountService(bank_repo, challenge_repo, sms_service, ifsc_service)


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


def get_app_metrics_repository(
    db: AsyncSession = Depends(get_db_session),
) -> AppMetricsRepository:
    """Dependency injecting the AppMetricsRepository."""
    return AppMetricsRepository(db)


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


def get_personal_dashboard_service(
    audit_service: AuditService = Depends(get_audit_service),
    notification_service: NotificationService = Depends(get_notification_service),
    workflow_repo: WorkflowRepository = Depends(get_workflow_repository),
) -> PersonalDashboardService:
    """Dependency injecting the PersonalDashboardService."""
    return PersonalDashboardService(
        audit_service,
        notification_service,
        workflow_repo,
    )


def get_metal_price_service() -> MetalPriceService:
    """Dependency injecting the MetalPriceService."""
    return MetalPriceService()


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


def get_sandbox_kyc_client() -> SandboxKycClient:
    """Dependency injecting the Sandbox KYC API client."""
    return SandboxKycClient()


def get_kyc_service(
    user_repo: UserRepository = Depends(get_user_repository),
    sandbox_client: SandboxKycClient = Depends(get_sandbox_kyc_client),
    audit_service: AuditService = Depends(get_audit_service),
) -> KycService:
    """Dependency injecting the KycService."""
    return KycService(user_repo, sandbox_client, audit_service)


def get_payment_order_repository(
    db: AsyncSession = Depends(get_db_session),
) -> PaymentOrderRepository:
    return PaymentOrderRepository(db)


def get_razorpay_client() -> RazorpayClient:
    return RazorpayClient()


def get_razorpayx_client() -> RazorpayXClient:
    return RazorpayXClient()


def get_digital_metal_inventory_repository(
    db: AsyncSession = Depends(get_db_session),
) -> DigitalMetalInventoryRepository:
    return DigitalMetalInventoryRepository(db)


def get_executive_dashboard_service(
    audit_service: AuditService = Depends(get_audit_service),
    notification_service: NotificationService = Depends(get_notification_service),
    customer_repo: CustomerRepository = Depends(get_customer_repository),
    user_repo: UserRepository = Depends(get_user_repository),
    workflow_repo: WorkflowRepository = Depends(get_workflow_repository),
    report_repo: ReportRepository = Depends(get_report_repository),
    app_metrics_repo: AppMetricsRepository = Depends(get_app_metrics_repository),
    digital_inventory_repo: DigitalMetalInventoryRepository = Depends(
        get_digital_metal_inventory_repository
    ),
    metal_price_service: MetalPriceService = Depends(get_metal_price_service),
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
        app_metrics_repo,
        digital_inventory_repo,
        metal_price_service,
        inventory_service,
        transaction_service,
    )


def get_digital_metal_inventory_movement_repository(
    db: AsyncSession = Depends(get_db_session),
) -> DigitalMetalInventoryMovementRepository:
    return DigitalMetalInventoryMovementRepository(db)


def get_digital_metal_inventory_service(
    inventory_repo: DigitalMetalInventoryRepository = Depends(
        get_digital_metal_inventory_repository
    ),
    movement_repo: DigitalMetalInventoryMovementRepository = Depends(
        get_digital_metal_inventory_movement_repository
    ),
    audit_service: AuditService = Depends(get_audit_service),
    notification_service: NotificationService = Depends(get_notification_service),
) -> DigitalMetalInventoryService:
    return DigitalMetalInventoryService(
        inventory_repo, movement_repo, audit_service, notification_service
    )


def get_gold_payment_service(
    user_repo: UserRepository = Depends(get_user_repository),
    payment_repo: PaymentOrderRepository = Depends(get_payment_order_repository),
    metal_prices: MetalPriceService = Depends(get_metal_price_service),
    razorpay: RazorpayClient = Depends(get_razorpay_client),
    digital_inventory_service: DigitalMetalInventoryService = Depends(
        get_digital_metal_inventory_service
    ),
) -> GoldPaymentService:
    return GoldPaymentService(
        user_repo, payment_repo, metal_prices, razorpay, digital_inventory_service
    )


def get_gold_scheme_service(
    user_repo: UserRepository = Depends(get_user_repository),
    referral_service: ReferralService = Depends(get_referral_service),
) -> GoldSchemeService:
    return GoldSchemeService(user_repo, referral_service)


def get_gold_sell_inquiry_repository(
    db: AsyncSession = Depends(get_db_session),
) -> GoldSellInquiryRepository:
    return GoldSellInquiryRepository(db)


def get_sell_payout_service(
    metal_prices: MetalPriceService = Depends(get_metal_price_service),
) -> SellPayoutService:
    return SellPayoutService(metal_prices)


def get_sell_razorpayx_payout_service(
    razorpayx: RazorpayXClient = Depends(get_razorpayx_client),
    bank_repo: UserBankAccountRepository = Depends(get_user_bank_account_repository),
    user_repo: UserRepository = Depends(get_user_repository),
    inquiry_repo: GoldSellInquiryRepository = Depends(get_gold_sell_inquiry_repository),
) -> SellRazorpayXPayoutService:
    return SellRazorpayXPayoutService(razorpayx, bank_repo, user_repo, inquiry_repo)


def get_organization_profile_repository(
    db: AsyncSession = Depends(get_db_session),
) -> OrganizationProfileRepository:
    return OrganizationProfileRepository(db)


def get_organization_profile_service(
    repo: OrganizationProfileRepository = Depends(get_organization_profile_repository),
    audit_service: AuditService = Depends(get_audit_service),
) -> OrganizationProfileService:
    return OrganizationProfileService(repo, audit_service)


def get_gold_sell_inquiry_service(
    inquiry_repo: GoldSellInquiryRepository = Depends(get_gold_sell_inquiry_repository),
    user_repo: UserRepository = Depends(get_user_repository),
    bank_repo: UserBankAccountRepository = Depends(get_user_bank_account_repository),
    org_repo: OrganizationProfileRepository = Depends(get_organization_profile_repository),
    notification_service: NotificationService = Depends(get_notification_service),
    payout_service: SellPayoutService = Depends(get_sell_payout_service),
    razorpayx_payout_service: SellRazorpayXPayoutService = Depends(
        get_sell_razorpayx_payout_service
    ),
    audit_service: AuditService = Depends(get_audit_service),
) -> GoldSellInquiryService:
    return GoldSellInquiryService(
        inquiry_repo,
        user_repo,
        bank_repo,
        org_repo,
        notification_service,
        payout_service,
        razorpayx_payout_service,
        audit_service,
    )


def get_admin_wallet_repository(
    db: AsyncSession = Depends(get_db_session),
) -> AdminWalletRepository:
    return AdminWalletRepository(db)


def get_admin_wallet_service(
    wallet_repo: AdminWalletRepository = Depends(get_admin_wallet_repository),
    audit_service: AuditService = Depends(get_audit_service),
) -> AdminWalletService:
    return AdminWalletService(wallet_repo, audit_service)
