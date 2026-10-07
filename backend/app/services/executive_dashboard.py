import asyncio
import time
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

from app.core.config import settings
from app.core.logging import logger
from app.core.permissions import user_has_permission
from app.models.user import User
from app.repositories.app_metrics import AppMetricsRepository
from app.repositories.customer import CustomerRepository
from app.repositories.digital_metal_inventory import DigitalMetalInventoryRepository
from app.repositories.payment_order import PaymentOrderRepository
from app.repositories.report import ReportRepository
from app.repositories.user import UserRepository
from app.repositories.workflow import WorkflowRepository
from app.schemas.payment import (
    AdminPaymentItem,
    AdminPaymentSummary,
    CustomerPaymentSummary,
)
from app.schemas.dashboard import (
    AppDashboardMetrics,
    AssignedTaskSummary,
    CustomerDashboardMetrics,
    DailyActivityItem,
    ExecutiveDashboardResponse,
    ExecutiveRole,
    InventoryDashboardMetrics,
    RevenueTrendPoint,
    TeamDashboardMetrics,
    TransactionDashboardMetrics,
    WorkflowApprovalSummary,
)
from app.schemas.digital_metal_inventory import compute_stock_status
from app.schemas.inventory import InventoryItemResponse
from app.services.audit import AuditService
from app.services.inventory import InventoryService
from app.services.metal_prices import MetalPriceService
from app.services.notification import NotificationService
from app.services.transaction import TransactionService

_executive_cache: dict[str, tuple[float, ExecutiveDashboardResponse]] = {}


def clear_executive_dashboard_cache() -> None:
    """Clear in-memory cache for executive dashboards."""
    _executive_cache.clear()


def resolve_executive_role(user: User) -> ExecutiveRole:
    """Map authenticated user to executive dashboard persona."""
    if user.is_superuser:
        return "admin"

    role_names = {role.name for role in user.roles}
    if role_names & {"super_admin", "admin"}:
        return "admin"
    if "manager" in role_names:
        return "manager"
    if "employee" in role_names:
        return "employee"

    if user_has_permission(user, "audit.view") and user_has_permission(
        user, "transaction.view"
    ):
        return "admin"
    if user_has_permission(user, "workflow.approve"):
        return "manager"
    return "employee"


def _clean_phone(phone: Optional[str]) -> str:
    if not phone:
        return ""
    digits = "".join(filter(str.isdigit, str(phone)))
    return digits[-10:] if len(digits) >= 10 else digits


def _is_human_name(name: Optional[str]) -> bool:
    if not name:
        return False
    s = name.strip()
    if not s or s.lower() in {"customer", "admin", "unknown", "none", "null"}:
        return False
    if s.startswith("+91") or s.startswith("Customer") or s.startswith("+"):
        return False
    digits = "".join(filter(str.isdigit, s))
    if digits and len(digits) >= 7 and len(digits) >= len(s.replace(" ", "").replace("-", "")) * 0.7:
        return False
    return True


def _extract_human_name(user: Optional[User]) -> Optional[str]:
    if not user:
        return None
    parts = [p for p in (user.first_name, user.last_name) if p and p.strip()]
    if parts:
        joined = " ".join(parts).strip()
        if _is_human_name(joined):
            return joined
    if getattr(user, "kyc_profile", None):
        try:
            import json
            kd = json.loads(user.kyc_profile)
            if isinstance(kd, dict) and (kd.get("full_name") or kd.get("name")):
                val = str(kd.get("full_name") or kd.get("name")).strip()
                if _is_human_name(val):
                    return val
        except Exception:
            pass
    if getattr(user, "email", None) and "@" in str(user.email):
        em = str(user.email).strip().lower()
        if not em.endswith(".aura") and not em.endswith(".local") and "mobile" not in em:
            import re
            handle = em.split("@")[0]
            cleaned = re.sub(r"[\d_.]+", " ", handle).strip()
            if len(cleaned) >= 3 and not cleaned.isdigit() and _is_human_name(cleaned):
                return cleaned.title()
    return None


def _display_name(user: Optional[User]) -> str:
    hname = _extract_human_name(user)
    if hname:
        return hname
    if user and getattr(user, "mobile_number", None):
        return str(user.mobile_number)
    return "Customer"


class ExecutiveDashboardService:
    """Role-aware executive dashboard aggregation."""

    def __init__(
        self,
        audit_service: AuditService,
        notification_service: NotificationService,
        customer_repo: CustomerRepository,
        user_repo: UserRepository,
        workflow_repo: WorkflowRepository,
        report_repo: ReportRepository,
        app_metrics_repo: AppMetricsRepository,
        digital_inventory_repo: DigitalMetalInventoryRepository,
        metal_price_service: MetalPriceService,
        inventory_service: Optional[InventoryService] = None,
        transaction_service: Optional[TransactionService] = None,
        payment_order_repo: Optional[PaymentOrderRepository] = None,
    ):
        self.audit_service = audit_service
        self.notification_service = notification_service
        self.customer_repo = customer_repo
        self.user_repo = user_repo
        self.workflow_repo = workflow_repo
        self.report_repo = report_repo
        self.app_metrics_repo = app_metrics_repo
        self.digital_inventory_repo = digital_inventory_repo
        self.metal_price_service = metal_price_service
        self.inventory_service = inventory_service
        self.transaction_service = transaction_service
        self.payment_order_repo = payment_order_repo

    async def get_dashboard(self, user: User) -> ExecutiveDashboardResponse:
        role = resolve_executive_role(user)
        cache_key = f"{user.id}:{role}"
        now_mono = time.monotonic()
        cached = _executive_cache.get(cache_key)
        if cached and (now_mono - cached[0]) < settings.DASHBOARD_CACHE_TTL_SECONDS:
            return cached[1]

        unread = await self.notification_service.get_unread_count(user.id)
        refreshed_at = datetime.now(timezone.utc)

        if role == "admin":
            payload = await self._build_admin_dashboard(user, unread, refreshed_at)
        elif role == "manager":
            payload = await self._build_manager_dashboard(user, unread, refreshed_at)
        else:
            payload = await self._build_employee_dashboard(user, unread, refreshed_at)

        _executive_cache[cache_key] = (now_mono, payload)
        return payload

    async def _build_admin_dashboard(
        self, user: User, unread: int, refreshed_at: datetime
    ) -> ExecutiveDashboardResponse:
        activity_trend: list = []
        if user_has_permission(user, "audit.view"):
            activity_trend = await self.audit_service.get_activity_trend(
                days=7, user_id=None
            )

        revenue_trend: list[RevenueTrendPoint] = []
        revenue_growth = None
        transaction_metrics = None
        customer_metrics = None
        inventory_metrics = None
        app_metrics = None

        can_view_wallet = user_has_permission(user, "wallet.view")
        can_view_transactions = user_has_permission(user, "transaction.view")

        if can_view_wallet or can_view_transactions:
            try:
                now = datetime.now(timezone.utc)
                day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
                day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)
                month_start = day_start.replace(day=1)

                total_revenue = await self.app_metrics_repo.paid_revenue_sum()
                monthly_revenue = await self.app_metrics_repo.paid_revenue_sum(start=month_start, end=day_end)
                daily_revenue = await self.app_metrics_repo.paid_revenue_sum(start=day_start, end=day_end)
                total_transactions = await self.app_metrics_repo.count_wallet_transactions()
                monthly_transactions = await self.app_metrics_repo.count_wallet_transactions(
                    start=month_start, end=day_end
                )
                member_count = await self.app_metrics_repo.count_app_members()
                members_new = await self.app_metrics_repo.count_new_members_this_month()
                pending_sell_requests = await self.app_metrics_repo.count_pending_sell_inquiries()
                sell_requests_this_month = await self.app_metrics_repo.count_sell_inquiries(
                    start=month_start, end=day_end
                )
                trend_rows = await self.app_metrics_repo.payment_revenue_trend(days=30)
                growth = await self.app_metrics_repo.payment_revenue_growth_percent()

                metal_inventory_value = Decimal("0")
                gold_available = Decimal("0")
                silver_available = Decimal("0")
                low_stock_metal_count = 0

                if user_has_permission(user, "inventory.view"):
                    try:
                        metals = await self.digital_inventory_repo.list_all()
                        prices = await self.metal_price_service.get_prices()
                        price_by_metal = {
                            "gold": prices.gold.retail_price,
                            "silver": prices.silver.retail_price,
                        }
                        for row in metals:
                            available = row.available_weight_grams
                            rate = price_by_metal.get(row.metal_type, Decimal("0"))
                            metal_inventory_value += available * rate
                            if row.metal_type == "gold":
                                gold_available = available
                            elif row.metal_type == "silver":
                                silver_available = available
                            status = compute_stock_status(
                                available, row.low_stock_threshold_grams
                            )
                            if status in {"low_stock", "out_of_stock"}:
                                low_stock_metal_count += 1
                    except Exception as e:
                        logger.warning("digital_inventory_fetch_error", error=str(e))

                app_metrics = AppDashboardMetrics(
                    total_revenue=total_revenue,
                    monthly_revenue=monthly_revenue,
                    daily_revenue=daily_revenue,
                    total_transactions=total_transactions,
                    monthly_transactions=monthly_transactions,
                    member_count=member_count,
                    members_new_this_month=members_new,
                    metal_inventory_value=metal_inventory_value,
                    gold_available_grams=gold_available,
                    silver_available_grams=silver_available,
                    low_stock_metal_count=low_stock_metal_count,
                    pending_sell_requests=pending_sell_requests,
                    sell_requests_this_month=sell_requests_this_month,
                )
                revenue_trend = [
                    RevenueTrendPoint(
                        label=row["label"],
                        revenue=row["revenue"],
                        transaction_count=row.get("transaction_count", 0),
                    )
                    for row in trend_rows
                ]
                revenue_growth = growth
            except Exception as exc:
                logger.exception("app_metrics_calculation_error", error=str(exc))
                app_metrics = AppDashboardMetrics(
                    total_revenue=Decimal("0"),
                    monthly_revenue=Decimal("0"),
                    daily_revenue=Decimal("0"),
                    total_transactions=0,
                    monthly_transactions=0,
                    member_count=0,
                    members_new_this_month=0,
                    metal_inventory_value=Decimal("0"),
                    gold_available_grams=Decimal("0"),
                    silver_available_grams=Decimal("0"),
                    low_stock_metal_count=0,
                    pending_sell_requests=0,
                    sell_requests_this_month=0,
                )

        if user_has_permission(user, "customer.view"):
            try:
                customer_metrics = CustomerDashboardMetrics(
                    **(await self.customer_repo.dashboard_metrics())
                )
            except Exception as e:
                logger.warning("customer_metrics_error", error=str(e))

        if self.inventory_service and user_has_permission(user, "inventory.view"):
            try:
                inv = await self.inventory_service.get_metrics(low_stock_limit=5)
                inventory_metrics = InventoryDashboardMetrics(
                    total_stock=inv.total_stock,
                    inventory_value=inv.inventory_value,
                    low_stock_count=inv.low_stock_count,
                    low_stock_items=inv.low_stock_items,
                )
            except Exception as e:
                logger.warning("inventory_metrics_error", error=str(e))

        recent_payments: list[AdminPaymentItem] = []
        payment_summary: Optional[AdminPaymentSummary] = None
        customer_summaries: list[CustomerPaymentSummary] = []

        if self.payment_order_repo and (can_view_wallet or can_view_transactions):
            try:
                orders = await self.payment_order_repo.list_orders(limit=100)

                # Pre-fetch registered customer names from Customer, User, BankAccount & SellInquiries tables
                customer_names_by_phone: dict[str, str] = {}
                customer_names_by_email: dict[str, str] = {}
                customer_names_by_user_id: dict[str, str] = {}

                # 1. From Customer CRM table
                try:
                    all_custs = await self.customer_repo.list_customers(limit=200)
                    for c in all_custs:
                        if c.full_name and _is_human_name(c.full_name):
                            if c.mobile_number:
                                k = _clean_phone(c.mobile_number)
                                if k:
                                    customer_names_by_phone[k] = c.full_name.strip()
                            if c.email:
                                customer_names_by_email[c.email.strip().lower()] = c.full_name.strip()
                except Exception as exc:
                    logger.warning("customer_lookup_preload_error", error=str(exc))

                # 2. From User table (registered users with names)
                try:
                    all_users = await self.user_repo.list_users(limit=200)
                    for u in all_users:
                        hname = _extract_human_name(u)
                        if hname:
                            customer_names_by_user_id[str(u.id)] = hname
                            if u.mobile_number:
                                k = _clean_phone(u.mobile_number)
                                if k and k not in customer_names_by_phone:
                                    customer_names_by_phone[k] = hname
                            if u.email:
                                em = u.email.strip().lower()
                                if em and em not in customer_names_by_email:
                                    customer_names_by_email[em] = hname
                except Exception as exc:
                    logger.warning("user_lookup_preload_error", error=str(exc))

                def _resolve_order_customer_name(o) -> Optional[str]:
                    # 1. Check User model human name
                    if o.user:
                        hname = _extract_human_name(o.user)
                        if hname:
                            return hname
                        if str(o.user.id) in customer_names_by_user_id:
                            return customer_names_by_user_id[str(o.user.id)]
                    # 2. Check Customer/User phone lookup
                    contact = o.customer_contact or (o.user.mobile_number if o.user else None)
                    p_key = _clean_phone(contact)
                    if p_key and p_key in customer_names_by_phone:
                        return customer_names_by_phone[p_key]
                    # 3. Check Customer/User email lookup
                    email = (o.user.email if o.user else None)
                    if email and email.strip().lower() in customer_names_by_email:
                        return customer_names_by_email[email.strip().lower()]
                    return None

                recent_payments = [
                    AdminPaymentItem(
                        id=order.id,
                        razorpay_order_id=order.razorpay_order_id,
                        razorpay_payment_id=order.razorpay_payment_id,
                        bank_rrn=order.bank_rrn,
                        payment_method=order.payment_method,
                        customer_name=_resolve_order_customer_name(order),
                        customer_mobile=order.customer_contact
                        or (order.user.mobile_number if order.user else None),
                        customer_email=order.user.email if order.user else None,
                        metal=order.metal,
                        grams=Decimal(str(order.grams)),
                        amount_inr=Decimal(str(order.amount_paise)) / Decimal("100"),
                        status="captured" if order.status == "paid" else order.status,
                        failure_reason=order.failure_reason,
                        created_at=order.created_at,
                        paid_at=order.paid_at,
                        gst_percent=order.gst_percent,
                        metal_value_inr=order.metal_value_inr,
                        gst_amount_inr=order.gst_amount_inr,
                        razorpay_fee_inr=order.razorpay_fee_inr,
                        merchant_settlement_inr=order.merchant_settlement_inr,
                    )
                    for order in orders
                ]
                sum_dict = await self.payment_order_repo.get_orders_summary()
                sum_dict["last_synced_at"] = refreshed_at
                payment_summary = AdminPaymentSummary(**sum_dict)

                cust_map: dict[str, dict] = {}
                for p in recent_payments:
                    contact = p.customer_mobile or p.customer_email or "Unknown"
                    if contact not in cust_map:
                        cust_map[contact] = {
                            "mobile": contact,
                            "name": p.customer_name if (p.customer_name and _is_human_name(p.customer_name)) else None,
                            "email": p.customer_email,
                            "total_paid_inr": Decimal("0"),
                            "success_count": 0,
                            "total_grams": Decimal("0"),
                            "gold_grams": Decimal("0"),
                            "silver_grams": Decimal("0"),
                            "payment_methods": [],
                        }
                    # Update name if previously null and p.customer_name is valid
                    if p.customer_name and _is_human_name(p.customer_name) and not cust_map[contact]["name"]:
                        cust_map[contact]["name"] = p.customer_name
                    if p.customer_email and not cust_map[contact]["email"]:
                        cust_map[contact]["email"] = p.customer_email
                    if p.status in ("captured", "paid"):
                        cust_map[contact]["total_paid_inr"] += p.amount_inr
                        cust_map[contact]["success_count"] += 1
                        cust_map[contact]["total_grams"] += p.grams
                        if (p.metal or "").lower() == "silver":
                            cust_map[contact]["silver_grams"] += p.grams
                        else:
                            cust_map[contact]["gold_grams"] += p.grams
                        if p.payment_method and p.payment_method not in cust_map[contact]["payment_methods"]:
                            cust_map[contact]["payment_methods"].append(p.payment_method)

                # Final fallback pass for any customer without a valid human name in cust_map
                for contact, item in cust_map.items():
                    if not item["name"] or not _is_human_name(item["name"]):
                        p_key = _clean_phone(contact)
                        if p_key and p_key in customer_names_by_phone:
                            item["name"] = customer_names_by_phone[p_key]
                        elif item["email"] and item["email"].strip().lower() in customer_names_by_email:
                            item["name"] = customer_names_by_email[item["email"].strip().lower()]
                        else:
                            item["name"] = None

                customer_summaries = [
                    CustomerPaymentSummary(**c) for c in cust_map.values()
                ]
                customer_summaries.sort(key=lambda x: x.total_paid_inr, reverse=True)
            except Exception as exc:
                logger.error("executive_dashboard_payment_processing_error", error=str(exc), exc_info=True)

        return ExecutiveDashboardResponse(
            role="admin",
            display_name=_display_name(user),
            unread_notifications=unread,
            refreshed_at=refreshed_at,
            revenue_trend=revenue_trend,
            revenue_growth_percent=revenue_growth,
            customer_metrics=customer_metrics,
            app_metrics=app_metrics,
            inventory_metrics=inventory_metrics,
            transaction_metrics=transaction_metrics,
            activity_trend=activity_trend,
            recent_payments=recent_payments,
            payment_summary=payment_summary,
            customer_summaries=customer_summaries,
        )

    async def _build_manager_dashboard(
        self, user: User, unread: int, refreshed_at: datetime
    ) -> ExecutiveDashboardResponse:
        today_start = datetime.now(timezone.utc).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        can_view_audit = user_has_permission(user, "audit.view")
        can_view_users = user_has_permission(user, "user.view")
        can_approve = user_has_permission(user, "workflow.approve")

        login_stats = {"today": 0, "week": 0, "month": 0}
        activity_total = 0
        active_users = 0
        pending_count = 0
        pending_items: list = []

        if can_view_audit:
            login_stats = await self.audit_service.get_login_statistics(
                user_id=user.id, system_wide=True
            )
            _, activity_total = await self.audit_service.list_audit_logs(
                skip=0,
                limit=1,
                user_id=None,
                start_date=today_start,
            )

        if can_view_users:
            active_users = await self.user_repo.count_active_users()

        if can_approve:
            pending_count = await self.workflow_repo.count_pending()
            pending_items = await self.workflow_repo.list_filtered(
                skip=0,
                limit=8,
                state="pending",
                sort_by="pending_since",
                sort_order="asc",
            )

        inventory_alerts: list[InventoryItemResponse] = []
        if self.inventory_service and user_has_permission(user, "inventory.view"):
            inv = await self.inventory_service.get_metrics(low_stock_limit=10)
            inventory_alerts = inv.low_stock_items

        pending_approvals = [
            WorkflowApprovalSummary(
                id=item.id,
                request_number=item.request_number,
                title=item.title,
                state=item.state,
                requester_name=(
                    f"{item.requester.first_name or ''} {item.requester.last_name or ''}".strip()
                    if item.requester
                    else None
                )
                or (item.requester.email if item.requester else None),
                assignee_name=(
                    f"{item.assignee.first_name or ''} {item.assignee.last_name or ''}".strip()
                    if item.assignee
                    else None
                )
                or (item.assignee.email if item.assignee else None),
                pending_since=item.pending_since,
                escalation_level=item.escalation_level,
            )
            for item in pending_items
        ]

        team_metrics = TeamDashboardMetrics(
            active_users=active_users,
            pending_approvals=pending_count,
            logins_today=login_stats["today"],
            team_activity_today=activity_total,
        )

        return ExecutiveDashboardResponse(
            role="manager",
            display_name=_display_name(user),
            unread_notifications=unread,
            refreshed_at=refreshed_at,
            team_metrics=team_metrics,
            pending_approvals=pending_approvals,
            inventory_alerts=inventory_alerts,
        )

    async def _build_employee_dashboard(
        self, user: User, unread: int, refreshed_at: datetime
    ) -> ExecutiveDashboardResponse:
        assigned_items = await self.workflow_repo.list_filtered(
            skip=0,
            limit=10,
            assignee_id=user.id,
            state="pending",
            sort_by="pending_since",
            sort_order="asc",
        )
        my_requests = await self.workflow_repo.list_filtered(
            skip=0,
            limit=5,
            requester_id=user.id,
            sort_by="created_at",
            sort_order="desc",
        )
        activity_result = await self.audit_service.list_audit_logs(
            skip=0, limit=12, user_id=user.id
        )
        activity_trend = await self.audit_service.get_activity_trend(days=7, user_id=user.id)
        activity_logs, _ = activity_result

        assigned_tasks = [
            AssignedTaskSummary(
                id=item.id,
                request_number=item.request_number,
                title=item.title,
                state=item.state,
                request_type=item.request_type,
                submitted_at=item.submitted_at,
            )
            for item in assigned_items
        ]

        for draft in my_requests:
            if draft.state == "draft" and len(assigned_tasks) < 10:
                assigned_tasks.append(
                    AssignedTaskSummary(
                        id=draft.id,
                        request_number=draft.request_number,
                        title=draft.title,
                        state=draft.state,
                        request_type=draft.request_type,
                        submitted_at=draft.submitted_at,
                    )
                )

        daily_activities = [
            DailyActivityItem(
                id=log.id,
                action=log.action,
                entity_type=log.entity_type,
                entity_id=log.entity_id,
                timestamp=log.timestamp,
                description=self._activity_description(log.action, log.entity_type),
            )
            for log in activity_logs
        ]

        return ExecutiveDashboardResponse(
            role="employee",
            display_name=_display_name(user),
            unread_notifications=unread,
            refreshed_at=refreshed_at,
            assigned_tasks=assigned_tasks,
            daily_activities=daily_activities,
            activity_trend=activity_trend,
        )

    @staticmethod
    def _activity_description(action: str, entity_type: Optional[str]) -> str:
        readable = action.replace("_", " ").title()
        if entity_type:
            return f"{readable} on {entity_type}"
        return readable
