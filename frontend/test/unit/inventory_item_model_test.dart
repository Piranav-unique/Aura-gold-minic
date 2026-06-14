import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/inventory/domain/inventory_item.dart';
import 'package:ags_gold/features/inventory/domain/stock_movement.dart';
import 'package:ags_gold/features/inventory/domain/supplier.dart';

void main() {
  test('InventoryItem.fromJson parses fields', () {
    final item = InventoryItem.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'item_name': 'Gold Bar 10g',
      'item_category': 'gold_bar',
      'weight': '10.0000',
      'purity': '99.900',
      'purchase_price': '50000.00',
      'current_value': '55000.00',
      'stock_quantity': 10,
      'reorder_level': 5,
      'supplier_name': 'ABC Gold',
      'status': 'active',
      'is_low_stock': false,
      'created_at': '2026-06-08T10:00:00Z',
      'updated_at': '2026-06-08T10:00:00Z',
    });

    expect(item.itemName, 'Gold Bar 10g');
    expect(item.displayCategory, 'Gold Bar');
    expect(item.stockQuantity, 10);
  });

  test('StockMovement.fromJson parses movement', () {
    final movement = StockMovement.fromJson({
      'id': '22222222-2222-2222-2222-222222222222',
      'inventory_item_id': '11111111-1111-1111-1111-111111111111',
      'movement_type': 'stock_in',
      'quantity_change': 5,
      'quantity_before': 10,
      'quantity_after': 15,
      'created_at': '2026-06-08T10:00:00Z',
    });

    expect(movement.displayType, 'Stock In');
    expect(movement.quantityAfter, 15);
  });

  test('Supplier.fromJson parses supplier', () {
    final supplier = Supplier.fromJson({
      'id': '33333333-3333-3333-3333-333333333333',
      'name': 'Gold Suppliers Ltd',
      'is_active': true,
      'created_at': '2026-06-08T10:00:00Z',
      'updated_at': '2026-06-08T10:00:00Z',
    });

    expect(supplier.name, 'Gold Suppliers Ltd');
    expect(supplier.isActive, isTrue);
  });

  test('InventoryMetrics.fromJson parses metrics', () {
    final metrics = InventoryMetrics.fromJson({
      'total_stock': 100,
      'inventory_value': '550000.00',
      'low_stock_count': 2,
      'low_stock_items': [],
    });

    expect(metrics.totalStock, 100);
    expect(metrics.lowStockCount, 2);
  });

  test('InventoryItem serializers and display helpers', () {
    final now = DateTime.utc(2026, 6, 8);
    final item = InventoryItem(
      id: '1',
      itemName: 'Coin',
      itemCategory: 'gold_coin',
      weight: 5,
      purity: 99.9,
      purchasePrice: 1000,
      currentValue: 1100,
      stockQuantity: 3,
      reorderLevel: 2,
      supplierId: 'sup-1',
      status: 'inactive',
      notes: 'Vault',
      createdAt: now,
      updatedAt: now,
    );

    expect(item.displayCategory, 'Gold Coin');
    expect(item.displayStatus, 'Inactive');
    expect(item.toCreateJson()['supplier_id'], 'sup-1');
    expect(item.toUpdateJson()['notes'], 'Vault');
    expect(item.copyWith(status: 'active').status, 'active');
  });

  test('PaginatedInventoryItems and inventory constants', () {
    final page = PaginatedInventoryItems.fromJson({
      'items': [
        {
          'id': '1',
          'item_name': 'Bar',
          'created_at': '2026-06-08T10:00:00Z',
          'updated_at': '2026-06-08T10:00:00Z',
        },
      ],
      'total': 1,
    });
    expect(page.items.single.itemName, 'Bar');
    expect(inventoryCategoryOptions, contains('raw_gold'));
  });

  test('StockMovement display types and pagination', () {
    expect(
      StockMovement.fromJson({
        'id': '1',
        'inventory_item_id': '2',
        'movement_type': 'adjustment',
        'quantity_change': 0,
        'quantity_before': 5,
        'quantity_after': 5,
        'created_at': '2026-06-08T10:00:00Z',
      }).displayType,
      'Adjustment',
    );

    final page = PaginatedStockMovements.fromJson({'items': []});
    expect(page.total, 0);
  });

  test('Supplier serializers and pagination', () {
    final now = DateTime.utc(2026, 6, 8);
    final supplier = Supplier(
      id: '1',
      name: 'Gold Co',
      contactPerson: 'Alice',
      mobileNumber: '9999999999',
      email: 'alice@gold.com',
      address: 'Main St',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    final json = supplier.toCreateJson();
    expect(json['contact_person'], 'Alice');
    expect(json['email'], 'alice@gold.com');
    expect(supplier.copyWith(name: 'New Co').name, 'New Co');

    final page = PaginatedSuppliers.fromJson({
      'items': [
        {
          'id': '1',
          'name': 'Gold Co',
          'created_at': '2026-06-08T10:00:00Z',
          'updated_at': '2026-06-08T10:00:00Z',
        },
      ],
    });
    expect(page.items.single.name, 'Gold Co');
  });
}
