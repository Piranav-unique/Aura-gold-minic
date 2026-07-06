from datetime import datetime
from decimal import Decimal
from typing import List, Literal, Optional
import uuid

from pydantic import BaseModel, Field

from app.schemas.audit_log import AuditLogResponse
from app.schemas.inventory import InventoryItemResponse
from app.schemas.notification import NotificationResponse
from app.schemas.profile import KycGovernmentProfile
from app.schemas.gold_scheme import GoldSchemeResponse

ExecutiveRole = Literal["admin", "manager", "employee"]


class LoginStatistics(BaseModel):
    today: int
    week: int
    month: int


class ActivityTrendPoint(BaseModel):
    label: str
    count: int


class InventoryDashboardMetrics(BaseModel):
    total_stock: int
    inventory_value: Decimal
    low_stock_count: int
    low_stock_items: List[InventoryItemResponse] = []


class TopCustomerDashboardMetric(BaseModel):
    customer_id: uuid.UUID
    full_name: str
    revenue: Decimal
    transaction_count: int


class TransactionDashboardMetrics(BaseModel):
    daily_revenue: Decimal
    monthly_revenue: Decimal
    top_customers: List[TopCustomerDashboardMetric] = []


class DashboardStatsResponse(BaseModel):
    recent_activity: List[AuditLogResponse]
    unread_notifications: int
    security_alerts: List[AuditLogResponse]
    recent_notifications: List[NotificationResponse]
    login_statistics: LoginStatistics
    activity_trend: List[ActivityTrendPoint] = []
    inventory_metrics: Optional[InventoryDashboardMetrics] = None
    transaction_metrics: Optional[TransactionDashboardMetrics] = None


class RevenueTrendPoint(BaseModel):
    label: str
    revenue: Decimal
    transaction_count: int = 0


class CustomerDashboardMetrics(BaseModel):
    total_customers: int
    active_customers: int
    new_this_month: int


class AppDashboardMetrics(BaseModel):
    """Gold app KPIs: Razorpay buys, wallet activity, members, digital metal stock."""

    total_revenue: Decimal
    monthly_revenue: Decimal
    daily_revenue: Decimal
    total_transactions: int
    monthly_transactions: int
    member_count: int
    members_new_this_month: int
    metal_inventory_value: Decimal
    gold_available_grams: Decimal
    silver_available_grams: Decimal
    low_stock_metal_count: int = 0
    pending_sell_requests: int = 0
    sell_requests_this_month: int = 0


class TeamDashboardMetrics(BaseModel):
    active_users: int
    pending_approvals: int
    logins_today: int
    team_activity_today: int


class WorkflowApprovalSummary(BaseModel):
    id: uuid.UUID
    request_number: str
    title: str
    state: str
    requester_name: Optional[str] = None
    assignee_name: Optional[str] = None
    pending_since: Optional[datetime] = None
    escalation_level: int = 0


class AssignedTaskSummary(BaseModel):
    id: uuid.UUID
    request_number: str
    title: str
    state: str
    request_type: str
    submitted_at: Optional[datetime] = None


class DailyActivityItem(BaseModel):
    id: uuid.UUID
    action: str
    entity_type: Optional[str] = None
    entity_id: Optional[str] = None
    timestamp: datetime
    description: str


class PersonalDashboardResponse(BaseModel):
    """User-focused home dashboard for any authenticated user."""

    display_name: str
    email: str
    mobile_number: Optional[str] = None
    roles: List[str]
    unread_notifications: int
    refreshed_at: datetime
    login_statistics: LoginStatistics
    activity_trend: List[ActivityTrendPoint] = []
    recent_notifications: List[NotificationResponse] = []
    assigned_tasks: List[AssignedTaskSummary] = []
    daily_activities: List[DailyActivityItem] = []
    pending_task_count: int = 0
    draft_task_count: int = 0
    kyc_status: str = "not_started"
    kyc_profile: Optional[KycGovernmentProfile] = None
    gold_savings_grams: Decimal = Decimal("0")
    silver_savings_grams: Decimal = Decimal("0")
    gold_invested_inr: Decimal = Decimal("0")
    silver_invested_inr: Decimal = Decimal("0")
    wallet_balance_inr: Decimal = Decimal("0")
    gold_scheme: GoldSchemeResponse = Field(default_factory=GoldSchemeResponse)


class MetalPricePoint(BaseModel):
    label: str
    price: Decimal
    date: str | None = None


class MetalRetailBreakdown(BaseModel):
    region: str = "Tamil Nadu"
    purity: str
    international_spot: Decimal
    import_duty_percent: Decimal
    import_duty_amount: Decimal
    gst_percent: Decimal
    gst_amount: Decimal
    local_premium_percent: Decimal
    local_premium_amount: Decimal
    retail_price: Decimal


class MetalQuote(BaseModel):
    metal: Literal["gold", "silver"]
    unit: str = "INR/gm · Tamil Nadu"
    retail_price: Decimal
    change_percent: Decimal
    trend: List[MetalPricePoint] = []
    spot_price: Decimal = Field(default=Decimal("0"), exclude=True)
    retail: Optional[MetalRetailBreakdown] = Field(default=None, exclude=True)


class MetalPricesResponse(BaseModel):
    refreshed_at: datetime
    gold: MetalQuote
    silver: MetalQuote


class MetalHistoryResponse(BaseModel):
    metal: Literal["gold", "silver"]
    range_key: Literal["1M", "3M", "6M", "1Y", "3Y"]
    unit: str = "INR/gm · Tamil Nadu"
    price_basis: str = "tamil_nadu_retail"
    performance_percent: Decimal
    points: List[MetalPricePoint] = []
    refreshed_at: datetime


class ExecutiveDashboardResponse(BaseModel):
    role: ExecutiveRole
    display_name: str
    unread_notifications: int
    refreshed_at: datetime
    revenue_trend: List[RevenueTrendPoint] = []
    revenue_growth_percent: Optional[Decimal] = None
    customer_metrics: Optional[CustomerDashboardMetrics] = None
    app_metrics: Optional[AppDashboardMetrics] = None
    inventory_metrics: Optional[InventoryDashboardMetrics] = None
    transaction_metrics: Optional[TransactionDashboardMetrics] = None
    team_metrics: Optional[TeamDashboardMetrics] = None
    pending_approvals: List[WorkflowApprovalSummary] = []
    inventory_alerts: List[InventoryItemResponse] = []
    assigned_tasks: List[AssignedTaskSummary] = []
    daily_activities: List[DailyActivityItem] = []
    activity_trend: List[ActivityTrendPoint] = []
