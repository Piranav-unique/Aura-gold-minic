from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional

from pydantic import BaseModel

ReportType = Literal["revenue", "inventory", "customer", "transaction", "audit"]
ExportFormat = Literal["csv", "xlsx", "pdf"]


class TrendPoint(BaseModel):
    label: str
    value: Decimal | int = 0
    count: int = 0


class RevenueTrendPoint(BaseModel):
    label: str
    revenue: Decimal
    transaction_count: int = 0


class InventoryTrendPoint(BaseModel):
    label: str
    net_change: int
    movement_count: int = 0


class KpiCard(BaseModel):
    key: str
    label: str
    value: str
    trend_label: Optional[str] = None
    trend_positive: Optional[bool] = None


class ActivityTrendPoint(BaseModel):
    label: str
    count: int


class AnalyticsOverviewResponse(BaseModel):
    kpis: list[KpiCard] = []
    revenue_trend: list[RevenueTrendPoint] = []
    inventory_trend: list[InventoryTrendPoint] = []
    revenue_growth_percent: Optional[Decimal] = None
    activity_trend: list[ActivityTrendPoint] = []


class RevenueReportResponse(BaseModel):
    period_start: datetime
    period_end: datetime
    total_revenue: Decimal
    transaction_count: int
    revenue_growth_percent: Optional[Decimal] = None
    daily_trend: list[RevenueTrendPoint] = []
    top_customers: list[dict] = []


class InventoryCategoryRow(BaseModel):
    category: str
    item_count: int
    total_stock: int
    category_value: Decimal


class InventoryReportResponse(BaseModel):
    total_stock: int
    inventory_value: Decimal
    low_stock_count: int
    item_count: int
    by_category: list[InventoryCategoryRow] = []
    movement_trend: list[InventoryTrendPoint] = []


class CustomerTypeRow(BaseModel):
    customer_type: str
    count: int
    revenue: Decimal


class CustomerReportResponse(BaseModel):
    total_customers: int
    active_customers: int
    total_revenue: Decimal
    total_purchases: int
    top_customers: list[dict] = []
    by_type: list[CustomerTypeRow] = []


class TransactionBreakdownRow(BaseModel):
    transaction_type: str
    payment_status: str
    count: int
    total_amount: Decimal


class TransactionReportResponse(BaseModel):
    period_start: Optional[datetime] = None
    period_end: Optional[datetime] = None
    total_count: int
    breakdown: list[TransactionBreakdownRow] = []


class AuditBreakdownRow(BaseModel):
    action: str
    count: int


class AuditReportResponse(BaseModel):
    period_start: Optional[datetime] = None
    period_end: Optional[datetime] = None
    total_events: int
    breakdown: list[AuditBreakdownRow] = []


class ReportExportMeta(BaseModel):
    report_type: ReportType
    format: ExportFormat
    row_count: int
    truncated: bool = False
    filename: str
