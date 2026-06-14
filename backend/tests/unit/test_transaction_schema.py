import uuid
from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.schemas.transaction import (
    TransactionCancelRequest,
    TransactionCreate,
    TransactionLineCreate,
    TransactionUpdate,
)


def test_transaction_create_requires_customer_for_sale():
    with pytest.raises(ValidationError):
        TransactionCreate(
            transaction_type="sale",
            lines=[
                TransactionLineCreate(
                    inventory_item_id=uuid.uuid4(),
                    quantity=1,
                    unit_price=Decimal("100.00"),
                )
            ],
        )


def test_transaction_create_exchange_requires_stock_direction():
    with pytest.raises(ValidationError):
        TransactionCreate(
            transaction_type="exchange",
            customer_id=uuid.uuid4(),
            lines=[
                TransactionLineCreate(
                    inventory_item_id=uuid.uuid4(),
                    quantity=1,
                    unit_price=Decimal("100.00"),
                )
            ],
        )


def test_transaction_create_rejects_paid_on_create():
    with pytest.raises(ValidationError, match="pending"):
        TransactionCreate(
            transaction_type="sale",
            customer_id=uuid.uuid4(),
            payment_status="paid",
            lines=[
                TransactionLineCreate(
                    inventory_item_id=uuid.uuid4(),
                    quantity=1,
                    unit_price=Decimal("100.00"),
                )
            ],
        )


def test_transaction_create_valid_sale():
    customer_id = uuid.uuid4()
    item_id = uuid.uuid4()
    txn = TransactionCreate(
        transaction_type="sale",
        customer_id=customer_id,
        tax_amount=Decimal("18.00"),
        lines=[
            TransactionLineCreate(
                inventory_item_id=item_id,
                quantity=2,
                unit_price=Decimal("500.00"),
            )
        ],
    )
    assert txn.customer_id == customer_id
    assert txn.payment_status == "pending"
    assert len(txn.lines) == 1


def test_transaction_update_optional_fields():
    update = TransactionUpdate(payment_status="paid", notes="Updated")
    assert update.payment_status == "paid"
    assert update.notes == "Updated"


def test_transaction_cancel_request():
    cancel = TransactionCancelRequest(reason="Customer request")
    assert cancel.reason == "Customer request"
