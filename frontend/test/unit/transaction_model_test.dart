import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/transactions/domain/transaction.dart';

void main() {
  group('Transaction model', () {
    test('fromJson parses transaction with lines', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111111',
        'transaction_number': 'TXN-20260608-0001',
        'transaction_type': 'sale',
        'customer_id': '22222222-2222-2222-2222-222222222222',
        'status': 'active',
        'payment_status': 'paid',
        'subtotal': '1000.00',
        'tax_amount': '18.00',
        'total_amount': '1018.00',
        'stock_applied': true,
        'created_at': '2026-06-08T10:00:00Z',
        'updated_at': '2026-06-08T10:00:00Z',
        'lines': [
          {
            'id': '33333333-3333-3333-3333-333333333333',
            'inventory_item_id': '44444444-4444-4444-4444-444444444444',
            'item_name': 'Gold Bar',
            'quantity': 1,
            'unit_price': '1000.00',
            'line_total': '1000.00',
            'stock_direction': 'out',
          },
        ],
      };

      final txn = Transaction.fromJson(json);
      expect(txn.transactionNumber, 'TXN-20260608-0001');
      expect(txn.isPaid, isTrue);
      expect(txn.lines, hasLength(1));
      expect(txn.lines.first.itemName, 'Gold Bar');
    });

    test('TransactionMetrics parses dashboard payload', () {
      final metrics = TransactionMetrics.fromJson({
        'daily_revenue': '5000.00',
        'monthly_revenue': '25000.00',
        'top_customers': [
          {
            'customer_id': '22222222-2222-2222-2222-222222222222',
            'full_name': 'Jane Doe',
            'revenue': '12000.00',
            'transaction_count': 3,
          },
        ],
      });

      expect(metrics.dailyRevenue, 5000);
      expect(metrics.topCustomers.first.fullName, 'Jane Doe');
    });

    test('TransactionLine.toCreateJson omits null stock direction', () {
      const line = TransactionLine(
        id: '1',
        inventoryItemId: '2',
        itemName: 'Coin',
        quantity: 1,
        unitPrice: 100,
        lineTotal: 100,
        stockDirection: 'out',
      );
      expect(line.toCreateJson(), isNot(contains('stock_direction')));
      expect(
        line.toCreateJson(stockDirection: 'in'),
        {
          'inventory_item_id': '2',
          'quantity': 1,
          'unit_price': '100.00',
          'stock_direction': 'in',
        },
      );
    });

    test('Transaction serializers and related models', () {
      final now = DateTime.utc(2026, 6, 8);
      const line = TransactionLine(
        id: '1',
        inventoryItemId: '2',
        itemName: 'Coin',
        quantity: 1,
        unitPrice: 100,
        lineTotal: 100,
        stockDirection: 'in',
      );
      final sale = Transaction(
        id: 'txn-1',
        transactionNumber: 'TXN-1',
        transactionType: 'sale',
        customerId: 'cust-1',
        status: 'active',
        paymentStatus: 'pending',
        subtotal: 100,
        taxAmount: 18,
        totalAmount: 118,
        stockApplied: false,
        notes: 'Walk-in',
        lines: [line],
        createdAt: now,
        updatedAt: now,
      );

      expect(sale.toCreateJson()['customer_id'], 'cust-1');
      expect(sale.toUpdateJson()['notes'], 'Walk-in');
      expect(sale.isPaid, isFalse);
      expect(sale.isCancelled, isFalse);

      final exchange = Transaction(
        id: sale.id,
        transactionNumber: sale.transactionNumber,
        transactionType: 'exchange',
        customerId: sale.customerId,
        status: sale.status,
        paymentStatus: sale.paymentStatus,
        subtotal: sale.subtotal,
        taxAmount: sale.taxAmount,
        totalAmount: sale.totalAmount,
        stockApplied: sale.stockApplied,
        lines: sale.lines,
        createdAt: sale.createdAt,
        updatedAt: sale.updatedAt,
      );
      expect(
        exchange.toCreateJson()['lines'].first,
        containsPair('stock_direction', 'in'),
      );

      final page = PaginatedTransactions.fromJson({
        'items': [
          {
            'id': 'txn-1',
            'transaction_number': 'TXN-1',
            'transaction_type': 'sale',
            'status': 'active',
            'payment_status': 'paid',
            'subtotal': '100',
            'tax_amount': '18',
            'total_amount': '118',
            'stock_applied': false,
            'created_at': '2026-06-08T10:00:00Z',
            'updated_at': '2026-06-08T10:00:00Z',
          },
        ],
        'total': 1,
      });
      expect(page.items.single.isPaid, isTrue);

      final doc = TransactionDocument.fromJson({
        'transaction_id': 'txn-1',
        'issued_at': '2026-06-08T10:00:00Z',
        'payment_status': 'paid',
        'subtotal': '100',
        'tax_amount': '18',
        'total_amount': '118',
      });
      expect(doc.documentType, 'invoice');

      expect(transactionTypeLabel('purchase'), 'Purchase');
      expect(paymentStatusLabel('refunded'), 'Refunded');
    });
  });
}
