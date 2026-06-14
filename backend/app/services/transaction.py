import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional, Tuple

from sqlalchemy.exc import IntegrityError

from app.core import audit_actions
from app.core.exceptions import NotFoundException, ValidationException
from app.models.transaction import Transaction, TransactionLine
from app.repositories.transaction import TransactionRepository
from app.repositories.customer import CustomerRepository
from app.repositories.inventory_item import InventoryItemRepository
from app.schemas.transaction import (
    TopCustomerMetric,
    TransactionCancelRequest,
    TransactionCreate,
    TransactionDetailResponse,
    TransactionDocumentLine,
    TransactionDocumentResponse,
    TransactionLineCreate,
    TransactionMetricsResponse,
    TransactionUpdate,
)
from app.services.audit import AuditService
from app.services.customer import CustomerService
from app.services.inventory import InventoryService

DEFAULT_STOCK_DIRECTION = {
    "purchase": "in",
    "sale": "out",
    "return": "in",
}

CUSTOMER_METRIC_TYPES = {"sale", "return", "exchange"}


class TransactionService:
    """Business logic for gold transactions with inventory and customer integration."""

    def __init__(
        self,
        transaction_repo: TransactionRepository,
        customer_repo: CustomerRepository,
        inventory_repo: InventoryItemRepository,
        customer_service: CustomerService,
        inventory_service: InventoryService,
        audit_service: Optional[AuditService] = None,
    ):
        self.transaction_repo = transaction_repo
        self.customer_repo = customer_repo
        self.inventory_repo = inventory_repo
        self.customer_service = customer_service
        self.inventory_service = inventory_service
        self.audit_service = audit_service

    def _resolve_stock_direction(
        self, transaction_type: str, line: TransactionLineCreate
    ) -> str:
        if transaction_type == "exchange":
            if not line.stock_direction:
                raise ValidationException(
                    "stock_direction is required for exchange transaction lines"
                )
            return line.stock_direction
        return DEFAULT_STOCK_DIRECTION[transaction_type]

    async def _validate_customer(self, customer_id: Optional[uuid.UUID]) -> None:
        if customer_id is None:
            return
        customer = await self.customer_repo.get_active(customer_id)
        if not customer:
            raise NotFoundException("Customer not found")
        if customer.status != "active":
            raise ValidationException("Customer must be active for this transaction")

    async def _build_line_models(
        self,
        transaction_type: str,
        lines_in: list[TransactionLineCreate],
    ) -> tuple[list[dict], Decimal]:
        subtotal = Decimal("0")
        line_payloads: list[dict] = []
        item_ids = [line_in.inventory_item_id for line_in in lines_in]
        items_by_id = await self.inventory_repo.get_active_by_ids(item_ids)

        for line_in in lines_in:
            item = items_by_id.get(line_in.inventory_item_id)
            if not item:
                raise NotFoundException(
                    f"Inventory item not found: {line_in.inventory_item_id}"
                )
            if item.status != "active":
                raise ValidationException(
                    f"Inventory item '{item.item_name}' is not active"
                )

            line_total = (line_in.unit_price * line_in.quantity).quantize(
                Decimal("0.01")
            )
            subtotal += line_total
            stock_direction = self._resolve_stock_direction(transaction_type, line_in)
            line_payloads.append(
                {
                    "inventory_item_id": item.id,
                    "item_name": item.item_name,
                    "quantity": line_in.quantity,
                    "unit_price": line_in.unit_price,
                    "line_total": line_total,
                    "stock_direction": stock_direction,
                }
            )

        return line_payloads, subtotal.quantize(Decimal("0.01"))

    def _customer_metric_deltas(
        self, transaction_type: str, total_amount: Decimal
    ) -> tuple[int, Decimal]:
        if transaction_type == "sale":
            return 1, total_amount
        if transaction_type == "return":
            return -1, -total_amount
        if transaction_type == "exchange":
            return 1, total_amount
        return 0, Decimal("0")

    async def _apply_stock_for_transaction(
        self,
        txn: Transaction,
        performing_user_id: Optional[uuid.UUID],
        *,
        reverse: bool = False,
    ) -> None:
        reference = txn.transaction_number
        for line in txn.lines:
            await self.inventory_service.apply_transaction_stock_line(
                line.inventory_item_id,
                line.quantity,
                line.stock_direction,
                reference=reference,
                performing_user_id=performing_user_id,
                commit=False,
                reverse=reverse,
            )

    async def _apply_customer_metrics(
        self,
        txn: Transaction,
        *,
        reverse: bool = False,
    ) -> None:
        if txn.customer_id is None or txn.transaction_type not in CUSTOMER_METRIC_TYPES:
            return
        purchase_delta, revenue_delta = self._customer_metric_deltas(
            txn.transaction_type, txn.total_amount
        )
        if reverse:
            purchase_delta = -purchase_delta
            revenue_delta = -revenue_delta
        await self.customer_service.record_transaction_metrics(
            txn.customer_id,
            purchase_delta=purchase_delta,
            revenue_delta=revenue_delta,
            transaction_at=txn.created_at,
            commit=False,
        )

    async def _maybe_apply_side_effects(
        self,
        txn: Transaction,
        performing_user_id: Optional[uuid.UUID],
    ) -> None:
        if txn.status != "active" or txn.payment_status != "paid" or txn.stock_applied:
            return
        await self._apply_stock_for_transaction(txn, performing_user_id)
        await self._apply_customer_metrics(txn)
        txn.stock_applied = True

    async def _reverse_side_effects(
        self,
        txn: Transaction,
        performing_user_id: Optional[uuid.UUID],
    ) -> None:
        if not txn.stock_applied:
            return
        await self._apply_stock_for_transaction(txn, performing_user_id, reverse=True)
        if txn.customer_id and txn.transaction_type in CUSTOMER_METRIC_TYPES:
            await self._apply_customer_metrics(txn, reverse=True)
        txn.stock_applied = False

    async def _log_audit(
        self,
        *,
        performing_user_id: Optional[uuid.UUID],
        action: str,
        entity_id: str,
        metadata: dict,
    ) -> None:
        if not self.audit_service:
            return
        await self.audit_service.log_action(
            user_id=performing_user_id,
            action=action,
            entity_type="Transaction",
            entity_id=entity_id,
            metadata=metadata,
            commit=False,
        )

    async def get_transaction_by_id(
        self, transaction_id: uuid.UUID
    ) -> TransactionDetailResponse:
        txn = await self.transaction_repo.get_with_details(transaction_id)
        if not txn:
            raise NotFoundException("Transaction not found")
        return TransactionDetailResponse.from_model(txn)

    async def list_transactions(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        transaction_type: Optional[str] = None,
        payment_status: Optional[str] = None,
        status: Optional[str] = None,
        customer_id: Optional[uuid.UUID] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> Tuple[list[TransactionDetailResponse], int]:
        items, total = await self.transaction_repo.list_transactions_with_total(
            skip=skip,
            limit=limit,
            search=search,
            transaction_type=transaction_type,
            payment_status=payment_status,
            status=status,
            customer_id=customer_id,
            sort_by=sort_by,
            sort_order=sort_order,
        )
        return [TransactionDetailResponse.from_model(item) for item in items], total

    async def create_transaction(
        self,
        txn_in: TransactionCreate,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> TransactionDetailResponse:
        await self._validate_customer(txn_in.customer_id)
        line_payloads, subtotal = await self._build_line_models(
            txn_in.transaction_type, txn_in.lines
        )
        tax_amount = txn_in.tax_amount.quantize(Decimal("0.01"))
        total_amount = (subtotal + tax_amount).quantize(Decimal("0.01"))

        transaction_number = await self.transaction_repo.next_document_number("TXN")
        txn = Transaction(
            transaction_number=transaction_number,
            transaction_type=txn_in.transaction_type,
            customer_id=txn_in.customer_id,
            status="active",
            payment_status=txn_in.payment_status,
            subtotal=subtotal,
            tax_amount=tax_amount,
            total_amount=total_amount,
            notes=txn_in.notes,
            performed_by=performing_user_id,
            stock_applied=False,
        )
        txn.lines = [TransactionLine(**payload) for payload in line_payloads]

        db = self.transaction_repo.db
        db.add(txn)
        try:
            await db.flush()
            await self._maybe_apply_side_effects(txn, performing_user_id)
            await self._log_audit(
                performing_user_id=performing_user_id,
                action=audit_actions.TRANSACTION_CREATE,
                entity_id=str(txn.id),
                metadata={
                    "transaction_number": txn.transaction_number,
                    "transaction_type": txn.transaction_type,
                    "total_amount": str(txn.total_amount),
                    "payment_status": txn.payment_status,
                },
            )
            await db.commit()
        except IntegrityError as exc:
            await db.rollback()
            raise ValidationException("Failed to create transaction") from exc

        refreshed = await self.transaction_repo.get_with_details(txn.id)
        return TransactionDetailResponse.from_model(refreshed)

    async def update_transaction(
        self,
        transaction_id: uuid.UUID,
        txn_in: TransactionUpdate,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> TransactionDetailResponse:
        txn = await self.transaction_repo.get_with_details(transaction_id)
        if not txn:
            raise NotFoundException("Transaction not found")
        if txn.status == "cancelled":
            raise ValidationException("Cancelled transactions cannot be updated")

        update_data = txn_in.model_dump(exclude_unset=True)
        lines_in = update_data.pop("lines", None)
        previous_payment = txn.payment_status
        was_stock_applied = txn.stock_applied

        if was_stock_applied:
            blocked = {"customer_id", "tax_amount", "lines"} & update_data.keys()
            if blocked:
                raise ValidationException(
                    "Cannot change customer, tax, or line items after payment "
                    "side effects have been applied "
                    f"(blocked: {', '.join(sorted(blocked))})"
                )

        if "customer_id" in update_data:
            await self._validate_customer(update_data["customer_id"])

        if lines_in is not None:
            if was_stock_applied:
                raise ValidationException(
                    "Line items cannot be changed after stock has been applied"
                )
            line_models = [TransactionLineCreate(**line) for line in lines_in]
            line_payloads, subtotal = await self._build_line_models(
                txn.transaction_type, line_models
            )
            tax_amount = (update_data.get("tax_amount", txn.tax_amount)).quantize(
                Decimal("0.01")
            )
            txn.subtotal = subtotal
            txn.tax_amount = tax_amount
            txn.total_amount = (subtotal + tax_amount).quantize(Decimal("0.01"))
            txn.lines.clear()
            txn.lines.extend(TransactionLine(**payload) for payload in line_payloads)

        if "tax_amount" in update_data and lines_in is None:
            txn.tax_amount = update_data["tax_amount"].quantize(Decimal("0.01"))
            txn.total_amount = (txn.subtotal + txn.tax_amount).quantize(Decimal("0.01"))

        for field in ("customer_id", "payment_status", "notes"):
            if field in update_data:
                setattr(txn, field, update_data[field])

        db = self.transaction_repo.db
        try:
            if (
                was_stock_applied
                and txn.payment_status != "paid"
                and previous_payment == "paid"
            ):
                await self._reverse_side_effects(txn, performing_user_id)

            if not was_stock_applied and txn.payment_status == "paid":
                await self._maybe_apply_side_effects(txn, performing_user_id)

            await self._log_audit(
                performing_user_id=performing_user_id,
                action=audit_actions.TRANSACTION_UPDATE,
                entity_id=str(txn.id),
                metadata={
                    "updated_fields": list(update_data.keys()),
                    "payment_status": txn.payment_status,
                },
            )
            await db.commit()
        except IntegrityError as exc:
            await db.rollback()
            raise ValidationException("Failed to update transaction") from exc

        refreshed = await self.transaction_repo.get_with_details(transaction_id)
        return TransactionDetailResponse.from_model(refreshed)

    async def cancel_transaction(
        self,
        transaction_id: uuid.UUID,
        cancel_in: TransactionCancelRequest,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> TransactionDetailResponse:
        txn = await self.transaction_repo.get_with_details(transaction_id)
        if not txn:
            raise NotFoundException("Transaction not found")
        if txn.status == "cancelled":
            raise ValidationException("Transaction is already cancelled")

        txn.status = "cancelled"
        txn.cancelled_at = datetime.now(timezone.utc)
        txn.cancellation_reason = cancel_in.reason

        db = self.transaction_repo.db
        if txn.stock_applied:
            await self._reverse_side_effects(txn, performing_user_id)

        await self._log_audit(
            performing_user_id=performing_user_id,
            action=audit_actions.TRANSACTION_CANCEL,
            entity_id=str(txn.id),
            metadata={
                "transaction_number": txn.transaction_number,
                "reason": cancel_in.reason,
            },
        )
        await db.commit()

        refreshed = await self.transaction_repo.get_with_details(transaction_id)
        return TransactionDetailResponse.from_model(refreshed)

    async def _assign_document_number(
        self,
        transaction_id: uuid.UUID,
        *,
        field: str,
        prefix: str,
    ) -> Transaction:
        db = self.transaction_repo.db
        for attempt in range(2):
            txn = await self.transaction_repo.get_for_update(transaction_id)
            if not txn:
                raise NotFoundException("Transaction not found")

            existing = getattr(txn, field)
            if existing:
                return txn

            setattr(
                txn,
                field,
                await self.transaction_repo.next_document_number(prefix),
            )
            try:
                await db.commit()
                refreshed = await self.transaction_repo.get_with_details(transaction_id)
                if not refreshed:
                    raise NotFoundException("Transaction not found")
                return refreshed
            except IntegrityError:
                await db.rollback()
                if attempt == 1:
                    raise ValidationException(
                        f"Failed to assign {field.replace('_', ' ')}"
                    ) from None
        raise ValidationException(f"Failed to assign {field.replace('_', ' ')}")

    async def generate_invoice(
        self, transaction_id: uuid.UUID
    ) -> TransactionDocumentResponse:
        txn = await self.transaction_repo.get_with_details(transaction_id)
        if not txn:
            raise NotFoundException("Transaction not found")
        if txn.status == "cancelled":
            raise ValidationException(
                "Cannot generate invoice for cancelled transaction"
            )

        if not txn.invoice_number:
            txn = await self._assign_document_number(
                transaction_id, field="invoice_number", prefix="INV"
            )

        return self._build_document(txn, "invoice", txn.invoice_number)

    async def generate_receipt(
        self, transaction_id: uuid.UUID
    ) -> TransactionDocumentResponse:
        txn = await self.transaction_repo.get_with_details(transaction_id)
        if not txn:
            raise NotFoundException("Transaction not found")
        if txn.status == "cancelled":
            raise ValidationException(
                "Cannot generate receipt for cancelled transaction"
            )
        if txn.payment_status != "paid":
            raise ValidationException("Receipt is only available for paid transactions")

        if not txn.receipt_number:
            txn = await self._assign_document_number(
                transaction_id, field="receipt_number", prefix="RCP"
            )

        return self._build_document(txn, "receipt", txn.receipt_number)

    def _build_document(
        self,
        txn: Transaction,
        document_type: str,
        document_number: str,
    ) -> TransactionDocumentResponse:
        customer_name = txn.customer.full_name if txn.customer else None
        customer_mobile = txn.customer.mobile_number if txn.customer else None
        return TransactionDocumentResponse(
            document_type=document_type,
            document_number=document_number,
            transaction_id=txn.id,
            transaction_number=txn.transaction_number,
            transaction_type=txn.transaction_type,
            customer_name=customer_name,
            customer_mobile=customer_mobile,
            payment_status=txn.payment_status,
            subtotal=txn.subtotal,
            tax_amount=txn.tax_amount,
            total_amount=txn.total_amount,
            issued_at=datetime.now(timezone.utc),
            lines=[
                TransactionDocumentLine(
                    item_name=line.item_name,
                    quantity=line.quantity,
                    unit_price=line.unit_price,
                    line_total=line.line_total,
                    stock_direction=line.stock_direction,
                )
                for line in txn.lines
            ],
        )

    async def get_metrics(self) -> TransactionMetricsResponse:
        now = datetime.now(timezone.utc)
        day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)
        month_start = day_start.replace(day=1)

        daily_revenue = await self.transaction_repo.revenue_sum(
            start=day_start, end=day_end
        )
        monthly_revenue = await self.transaction_repo.revenue_sum(
            start=month_start, end=day_end
        )
        top_rows = await self.transaction_repo.top_customers(limit=5)

        return TransactionMetricsResponse(
            daily_revenue=daily_revenue,
            monthly_revenue=monthly_revenue,
            top_customers=[
                TopCustomerMetric(
                    customer_id=row["customer_id"],
                    full_name=row["full_name"],
                    revenue=row["revenue"],
                    transaction_count=row["transaction_count"],
                )
                for row in top_rows
            ],
        )
