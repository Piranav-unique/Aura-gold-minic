# Import all database models so Alembic can discover them
from app.models.base import Base  # noqa: F401
from app.models.associations import user_roles, role_permissions  # noqa: F401
from app.models.user import User  # noqa: F401
from app.models.role import Role  # noqa: F401
from app.models.permission import Permission  # noqa: F401
from app.models.audit_log import AuditLog  # noqa: F401
from app.models.token_blacklist import TokenBlacklist  # noqa: F401
from app.models.notification import Notification  # noqa: F401
from app.models.user_settings import UserSettings  # noqa: F401
from app.models.customer import Customer  # noqa: F401
from app.models.supplier import Supplier  # noqa: F401
from app.models.inventory_item import InventoryItem  # noqa: F401
from app.models.stock_movement import StockMovement  # noqa: F401
from app.models.transaction import Transaction, TransactionLine  # noqa: F401
from app.models.workflow import (  # noqa: F401
    WorkflowApprovalHistory,
    WorkflowComment,
    WorkflowEscalationRule,
    WorkflowRequest,
)
from app.models.payment_order import PaymentOrder  # noqa: F401
from app.models.signup_otp import SignupOtpChallenge  # noqa: F401
from app.models.bank_account import BankLinkChallenge, UserBankAccount  # noqa: F401
from app.models.referral_reward import ReferralReward  # noqa: F401
from app.models.gold_sell_inquiry import GoldSellInquiry  # noqa: F401
from app.models.digital_metal_inventory import (  # noqa: F401
    DigitalMetalInventory,
    DigitalMetalInventoryMovement,
)
from app.models.organization_profile import OrganizationProfile  # noqa: F401
