import uuid
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.e2e.conftest import bearer_headers, login

pytestmark = pytest.mark.e2e


async def _create_customer(client, headers) -> str:
    resp = await client.post(
        "/api/v1/customers/",
        headers=headers,
        json={
            "customer_type": "individual",
            "full_name": f"Txn Customer {uuid.uuid4().hex[:6]}",
            "mobile_number": f"+9199{uuid.uuid4().int % 10_000_000_000:010d}"[-13:],
            "email": f"txn_{uuid.uuid4().hex[:8]}@e2e.test",
            "address": "E2E Street",
        },
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


async def _create_inventory_item(client, headers, stock: int = 20) -> str:
    resp = await client.post(
        "/api/v1/inventory/",
        headers=headers,
        json={
            "item_name": f"E2E Item {uuid.uuid4().hex[:6]}",
            "item_category": "gold_bar",
            "weight": "10.0000",
            "purity": "99.900",
            "purchase_price": "50000.00",
            "current_value": "55000.00",
            "stock_quantity": stock,
            "reorder_level": 5,
            "status": "active",
        },
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


@pytest.mark.asyncio
async def test_transaction_sale_cancel_and_documents_flow(
    db_client: AsyncClient,
    test_db: AsyncSession,
    admin_actor: tuple,
):
    admin_user, password = admin_actor
    tokens = await login(db_client, admin_user.email, password)
    headers = bearer_headers(tokens["access_token"])

    customer_id = await _create_customer(db_client, headers)
    item_id = await _create_inventory_item(db_client, headers, stock=10)

    create_resp = await db_client.post(
        "/api/v1/transactions/",
        headers=headers,
        json={
            "transaction_type": "sale",
            "customer_id": customer_id,
            "tax_amount": "100.00",
            "lines": [
                {
                    "inventory_item_id": item_id,
                    "quantity": 2,
                    "unit_price": "55000.00",
                }
            ],
        },
    )
    assert create_resp.status_code == 201, create_resp.text
    txn = create_resp.json()
    txn_id = txn["id"]
    assert txn["stock_applied"] is False
    assert txn["payment_status"] == "pending"

    pay_resp = await db_client.put(
        f"/api/v1/transactions/{txn_id}",
        headers=headers,
        json={"payment_status": "paid"},
    )
    assert pay_resp.status_code == 200, pay_resp.text
    txn = pay_resp.json()
    assert txn["stock_applied"] is True
    assert Decimal(txn["total_amount"]) == Decimal("110100.00")

    item_resp = await db_client.get(f"/api/v1/inventory/{item_id}", headers=headers)
    assert item_resp.status_code == 200
    assert item_resp.json()["stock_quantity"] == 8

    customer_resp = await db_client.get(
        f"/api/v1/customers/{customer_id}",
        headers=headers,
    )
    assert customer_resp.status_code == 200
    assert Decimal(customer_resp.json()["total_revenue"]) == Decimal("110100.00")

    blocked_update = await db_client.put(
        f"/api/v1/transactions/{txn_id}",
        headers=headers,
        json={"tax_amount": "200.00"},
    )
    assert blocked_update.status_code == 422

    invoice_resp = await db_client.get(
        f"/api/v1/transactions/{txn_id}/invoice",
        headers=headers,
    )
    assert invoice_resp.status_code == 200
    assert invoice_resp.json()["document_type"] == "invoice"
    assert invoice_resp.json()["document_number"].startswith("INV-")

    receipt_resp = await db_client.get(
        f"/api/v1/transactions/{txn_id}/receipt",
        headers=headers,
    )
    assert receipt_resp.status_code == 200
    assert receipt_resp.json()["document_type"] == "receipt"

    metrics_resp = await db_client.get("/api/v1/transactions/metrics", headers=headers)
    assert metrics_resp.status_code == 200
    assert Decimal(metrics_resp.json()["daily_revenue"]) >= Decimal("110100.00")

    dashboard_resp = await db_client.get("/api/v1/dashboard/stats", headers=headers)
    assert dashboard_resp.status_code == 200
    assert dashboard_resp.json()["transaction_metrics"] is not None

    cancel_resp = await db_client.post(
        f"/api/v1/transactions/{txn_id}/cancel",
        headers=headers,
        json={"reason": "Customer changed mind"},
    )
    assert cancel_resp.status_code == 200
    assert cancel_resp.json()["status"] == "cancelled"

    item_after_cancel = await db_client.get(
        f"/api/v1/inventory/{item_id}",
        headers=headers,
    )
    assert item_after_cancel.json()["stock_quantity"] == 10

    customer_after_cancel = await db_client.get(
        f"/api/v1/customers/{customer_id}",
        headers=headers,
    )
    assert Decimal(customer_after_cancel.json()["total_revenue"]) == Decimal("0")

    list_resp = await db_client.get("/api/v1/transactions/", headers=headers)
    assert list_resp.status_code == 200
    assert list_resp.json()["total"] >= 1
