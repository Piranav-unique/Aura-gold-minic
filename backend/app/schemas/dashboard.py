from datetime import datetime
from decimal import Decimal
from typing import List, Literal, Optional
import uuid

from pydantic import BaseModel

from app.schemas.audit_log import AuditLogResponse
from app.schemas.inventory import InventoryItemResponse
from app.schemas.notification import NotificationResponse

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


class ExecutiveDashboardResponse(BaseModel):
    role: ExecutiveRole
    display_name: str
    unread_notifications: int
    refreshed_at: datetime
    revenue_trend: List[RevenueTrendPoint] = []
    revenue_growth_percent: Optional[Decimal] = None
    customer_metrics: Optional[CustomerDashboardMetrics] = None
    inventory_metrics: Optional[InventoryDashboardMetrics] = None
    transaction_metrics: Optional[TransactionDashboardMetrics] = None
    team_metrics: Optional[TeamDashboardMetrics] = None
    pending_approvals: List[WorkflowApprovalSummary] = []
    inventory_alerts: List[InventoryItemResponse] = []
    assigned_tasks: List[AssignedTaskSummary] = []
    daily_activities: List[DailyActivityItem] = []
    activity_trend: List[ActivityTrendPoint] = []
