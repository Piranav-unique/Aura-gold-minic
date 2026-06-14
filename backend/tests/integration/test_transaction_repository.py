import uuid
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.models.inventory_item import InventoryItem
from app.models.transaction import Transaction, TransactionLine
from app.repositories.transaction import TransactionRepository


@pytest.mark.asyncio
async def test_revenue_sum_and_top_customers(test_db: AsyncSession):
    customer = Customer(
        customer_type="individual",
        full_name="Revenue Customer",
        mobile_number="+919988776655",
        email=f"rev_{uuid.uuid4().hex[:6]}@test.com",
        address="Test",
        status="active",
        total_purchases=0,
        total_revenue=Decimal("0"),
    )
    item = InventoryItem(
        item_name="Repo Gold Bar",
        item_category="gold_bar",
        weight=Decimal("10.0000"),
        purity=Decimal("99.900"),
        purchase_price=Decimal("50000.00"),
        current_value=Decimal("55000.00"),
        stock_quantity=10,
        reorder_level=2,
        status="active",
    )
    test_db.add_all([customer, item])
    await test_db.flush()

    txn = Transaction(
        transaction_number=f"TXN-TEST-{uuid.uuid4().hex[:6]}",
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
    test_db.add(txn)
    await test_db.commit()

    repo = TransactionRepository(test_db)
    now = datetime.now(timezone.utc)
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)

    revenue = await repo.revenue_sum(start=day_start, end=day_end)
    assert revenue >= Decimal("55000.00")

    top = await repo.top_customers(limit=5)
    assert any(row["customer_id"] == customer.id for row in top)

    loaded = await repo.get_with_details(txn.id)
    assert loaded is not None
    assert len(loaded.lines) == 1
    assert loaded.customer.full_name == "Revenue Customer"


@pytest.mark.asyncio
async def test_revenue_and_top_customers_net_returns(test_db: AsyncSession):
    customer = Customer(
        customer_type="individual",
        full_name="Net Revenue Customer",
        mobile_number="+919977665544",
        email=f"net_{uuid.uuid4().hex[:6]}@test.com",
        address="Test",
        status="active",
        total_purchases=0,
        total_revenue=Decimal("0"),
    )
    item = InventoryItem(
        item_name="Net Gold Bar",
        item_category="gold_bar",
        weight=Decimal("10.0000"),
        purity=Decimal("99.900"),
        purchase_price=Decimal("50000.00"),
        current_value=Decimal("55000.00"),
        stock_quantity=10,
        reorder_level=2,
        status="active",
    )
    test_db.add_all([customer, item])
    await test_db.flush()

    sale = Transaction(
        transaction_number=f"TXN-SALE-{uuid.uuid4().hex[:6]}",
        transaction_type="sale",
        customer_id=customer.id,
        status="active",
        payment_status="paid",
        subtotal=Decimal("10000.00"),
        tax_amount=Decimal("0"),
        total_amount=Decimal("10000.00"),
        stock_applied=False,
    )
    ret = Transaction(
        transaction_number=f"TXN-RET-{uuid.uuid4().hex[:6]}",
        transaction_type="return",
        customer_id=customer.id,
        status="active",
        payment_status="paid",
        subtotal=Decimal("2000.00"),
        tax_amount=Decimal("0"),
        total_amount=Decimal("2000.00"),
        stock_applied=False,
    )
    test_db.add_all([sale, ret])
    await test_db.commit()

    repo = TransactionRepository(test_db)
    now = datetime.now(timezone.utc)
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)

    revenue = await repo.revenue_sum(start=day_start, end=day_end)
    assert revenue == Decimal("8000.00")

    top = await repo.top_customers(limit=5)
    row = next(r for r in top if r["customer_id"] == customer.id)
    assert row["revenue"] == Decimal("8000.00")
    assert row["transaction_count"] == 2
