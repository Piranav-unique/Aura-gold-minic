import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/customers/domain/customer.dart';

void main() {
  test('Customer.fromJson parses all fields', () {
    final customer = Customer.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'customer_type': 'business',
      'full_name': 'Gold Traders Pvt Ltd',
      'mobile_number': '+919876543210',
      'email': 'traders@example.com',
      'address': '42 Bullion Street',
      'gst_number': '27AAAAA0000A1Z5',
      'status': 'active',
      'total_purchases': 12,
      'total_revenue': '125000.50',
      'last_transaction_date': '2026-06-01T10:00:00Z',
      'created_at': '2026-06-08T10:00:00Z',
      'updated_at': '2026-06-08T10:00:00Z',
    });

    expect(customer.fullName, 'Gold Traders Pvt Ltd');
    expect(customer.customerType, 'business');
    expect(customer.displayType, 'Business');
    expect(customer.totalPurchases, 12);
    expect(customer.totalRevenue, 125000.50);
    expect(customer.gstNumber, '27AAAAA0000A1Z5');
  });

  test('Customer displayStatus maps status values', () {
    final active = Customer.fromJson(_minimalJson(status: 'active'));
    final inactive = Customer.fromJson(_minimalJson(status: 'inactive'));
    final blacklisted = Customer.fromJson(_minimalJson(status: 'blacklisted'));

    expect(active.displayStatus, 'Active');
    expect(inactive.displayStatus, 'Inactive');
    expect(blacklisted.displayStatus, 'Blacklisted');
  });

  test('Customer.toCreateJson omits empty gst', () {
    final customer = Customer.fromJson(_minimalJson());
    final json = customer.toCreateJson();
    expect(json.containsKey('gst_number'), isFalse);
    expect(json['customer_type'], 'individual');
  });

  test('Customer.toUpdateJson omits empty gst', () {
    final customer = Customer.fromJson(_minimalJson());
    final json = customer.toUpdateJson();
    expect(json.containsKey('gst_number'), isFalse);
  });

  test('Customer.toUpdateJson includes gst when set', () {
    final customer = Customer.fromJson(
      _minimalJson(),
    ).copyWith(gstNumber: '27AAAAA0000A1Z5');
    expect(customer.toUpdateJson()['gst_number'], '27AAAAA0000A1Z5');
  });

  test('Customer.copyWith updates selected fields', () {
    final customer = Customer.fromJson(_minimalJson());
    final updated = customer.copyWith(
      fullName: 'Updated Name',
      status: 'inactive',
    );
    expect(updated.fullName, 'Updated Name');
    expect(updated.status, 'inactive');
    expect(updated.email, customer.email);
  });

  test('PaginatedCustomers.fromJson parses envelope', () {
    final page = PaginatedCustomers.fromJson({
      'items': [_minimalJson()],
      'total': 1,
      'skip': 0,
      'limit': 25,
    });

    expect(page.total, 1);
    expect(page.items.length, 1);
    expect(page.items.first.fullName, 'John Doe');
  });
}

Map<String, dynamic> _minimalJson({String status = 'active'}) {
  return {
    'id': '11111111-1111-1111-1111-111111111111',
    'customer_type': 'individual',
    'full_name': 'John Doe',
    'mobile_number': '+919876543210',
    'email': 'john@example.com',
    'address': '123 Main Street',
    'status': status,
    'total_purchases': 0,
    'total_revenue': 0,
    'created_at': '2026-06-08T10:00:00Z',
    'updated_at': '2026-06-08T10:00:00Z',
  };
}
