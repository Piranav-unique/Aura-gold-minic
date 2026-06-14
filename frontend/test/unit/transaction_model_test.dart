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
  });
}
