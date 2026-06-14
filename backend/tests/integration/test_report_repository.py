import uuid
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_log import AuditLog
from app.models.customer import Customer
from app.models.inventory_item import InventoryItem
from app.models.stock_movement import StockMovement
from app.models.transaction import Transaction, TransactionLine
from app.repositories.report import ReportRepository


@pytest.mark.asyncio
async def test_report_repository_aggregations(test_db: AsyncSession):
    customer = Customer(
        customer_type="business",
        full_name="Report Customer",
        mobile_number="+919900112233",
        email=f"report_{uuid.uuid4().hex[:6]}@test.com",
        address="Test",
        status="active",
        total_purchases=2,
        total_revenue=Decimal("75000"),
    )
    item = InventoryItem(
        item_name="Report Gold Bar",
        item_category="gold_bar",
        weight=Decimal("10.0000"),
        purity=Decimal("99.900"),
        purchase_price=Decimal("50000.00"),
        current_value=Decimal("55000.00"),
        stock_quantity=3,
        reorder_level=5,
        status="active",
    )
    test_db.add_all([customer, item])
    await test_db.flush()

    txn = Transaction(
        transaction_number=f"TXN-RPT-{uuid.uuid4().hex[:6]}",
        transaction_type="sale",
        customer_id=customer.id,
        status="active",
        payment_status="paid",
        subtotal=Decimal("55000.00"),
        tax_amount=Decimal("0"),
        total_amount=Decimal("55000.00"),
        stock_applied=False,
    )
    txn.lines = [
        TransactionLine(
            inventory_item_id=item.id,
            item_name=item.item_name,
            quantity=1,
            unit_price=Decimal("55000.00"),
            line_total=Decimal("55000.00"),
            stock_direction="out",
        )
    ]
    movement = StockMovement(
        inventory_item_id=item.id,
        movement_type="stock_out",
        quantity_change=-1,
        quantity_before=4,
        quantity_after=3,
    )
    audit = AuditLog(
        action="login_success",
        entity_type="User",
        entity_id=str(uuid.uuid4()),
        timestamp=datetime.now(timezone.utc),
    )
    test_db.add_all([txn, movement, audit])
    await test_db.commit()

    repo = ReportRepository(test_db)
    now = datetime.now(timezone.utc)
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)

    trend = await repo.revenue_trend(days=7)
    assert isinstance(trend, list)

    summary = await repo.revenue_period_summary(day_start, day_end)
    assert summary["transaction_count"] >= 1

    growth = await repo.revenue_growth_percent()
    assert growth is None or isinstance(growth, Decimal)

    inventory = await repo.inventory_summary()
    assert inventory["total_stock"] >= 3

    by_category = await repo.inventory_by_category()
    assert any(row["category"] == "gold_bar" for row in by_category)

    movement_trend = await repo.inventory_movement_trend(days=7)
    assert isinstance(movement_trend, list)

    customer_summary = await repo.customer_summary()
    assert customer_summary["total_customers"] >= 1

    top_customers = await repo.top_customers_report(limit=5)
    assert isinstance(top_customers, list)

    by_type = await repo.customer_type_breakdown()
    assert any(row["customer_type"] == "business" for row in by_type)

    txn_breakdown = await repo.transaction_breakdown(day_start, day_end)
    assert txn_breakdown

    listed = await repo.list_transactions_for_report(day_start, day_end, limit=10)
    assert listed

    audit_breakdown = await repo.audit_action_breakdown(day_start, day_end)
    assert any(row["action"] == "login_success" for row in audit_breakdown)

    audit_count = await repo.count_audit_logs(day_start, day_end)
    assert audit_count >= 1


@pytest.mark.asyncio
async def test_revenue_growth_percent_with_new_revenue(test_db: AsyncSession):
    item = InventoryItem(
        item_name="Growth Gold Bar",
        item_category="gold_bar",
        weight=Decimal("10.0000"),
        purity=Decimal("99.900"),
        purchase_price=Decimal("50000.00"),
        current_value=Decimal("55000.00"),
        stock_quantity=5,
        reorder_level=2,
        status="active",
    )
    test_db.add(item)
    await test_db.flush()

    txn = Transaction(
        transaction_number=f"TXN-GROW-{uuid.uuid4().hex[:6]}",
        transaction_type="sale",
        status="active",
        payment_status="paid",
        subtotal=Decimal("1000.00"),
        tax_amount=Decimal("0"),
        total_amount=Decimal("1000.00"),
        stock_applied=False,
    )
    test_db.add(txn)
    await test_db.commit()

    repo = ReportRepository(test_db)
    growth = await repo.revenue_growth_percent()
    assert growth == Decimal("100")
