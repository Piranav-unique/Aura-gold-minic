class InventoryItem {
  final String id;
  final String itemName;
  final String itemCategory;
  final double weight;
  final double purity;
  final double purchasePrice;
  final double currentValue;
  final int stockQuantity;
  final int reorderLevel;
  final String? supplierId;
  final String? supplierName;
  final String status;
  final String? notes;
  final bool isLowStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventoryItem({
    required this.id,
    required this.itemName,
    required this.itemCategory,
    required this.weight,
    required this.purity,
    required this.purchasePrice,
    required this.currentValue,
    required this.stockQuantity,
    required this.reorderLevel,
    this.supplierId,
    this.supplierName,
    required this.status,
    this.notes,
    this.isLowStock = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      itemName: json['item_name'] as String? ?? '',
      itemCategory: json['item_category'] as String? ?? 'gold_bar',
      weight: _parseDecimal(json['weight']),
      purity: _parseDecimal(json['purity']),
      purchasePrice: _parseDecimal(json['purchase_price']),
      currentValue: _parseDecimal(json['current_value']),
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      reorderLevel: json['reorder_level'] as int? ?? 5,
      supplierId: json['supplier_id'] as String?,
      supplierName: json['supplier_name'] as String?,
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      isLowStock: json['is_low_stock'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'item_name': itemName,
    'item_category': itemCategory,
    'weight': weight,
    'purity': purity,
    'purchase_price': purchasePrice,
    'current_value': currentValue,
    'stock_quantity': stockQuantity,
    'reorder_level': reorderLevel,
    if (supplierId != null && supplierId!.isNotEmpty) 'supplier_id': supplierId,
    'status': status,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  Map<String, dynamic> toUpdateJson() {
    final json = <String, dynamic>{
      'item_name': itemName,
      'item_category': itemCategory,
      'weight': weight,
      'purity': purity,
      'purchase_price': purchasePrice,
      'current_value': currentValue,
      'reorder_level': reorderLevel,
      'status': status,
    };
    if (supplierId != null && supplierId!.isNotEmpty) {
      json['supplier_id'] = supplierId;
    }
    if (notes != null) json['notes'] = notes;
    return json;
  }

  InventoryItem copyWith({
    String? itemName,
    String? itemCategory,
    double? weight,
    double? purity,
    double? purchasePrice,
    double? currentValue,
    int? reorderLevel,
    String? supplierId,
    String? status,
    String? notes,
  }) {
    return InventoryItem(
      id: id,
      itemName: itemName ?? this.itemName,
      itemCategory: itemCategory ?? this.itemCategory,
      weight: weight ?? this.weight,
      purity: purity ?? this.purity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentValue: currentValue ?? this.currentValue,
      stockQuantity: stockQuantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      isLowStock: isLowStock,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String get displayCategory {
    switch (itemCategory) {
      case 'gold_coin':
        return 'Gold Coin';
      case 'gold_ornament':
        return 'Gold Ornament';
      case 'raw_gold':
        return 'Raw Gold';
      default:
        return 'Gold Bar';
    }
  }

  String get displayStatus {
    switch (status) {
      case 'inactive':
        return 'Inactive';
      case 'discontinued':
        return 'Discontinued';
      default:
        return 'Active';
    }
  }

  static double _parseDecimal(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class PaginatedInventoryItems {
  final List<InventoryItem> items;
  final int total;
  final int skip;
  final int limit;

  const PaginatedInventoryItems({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory PaginatedInventoryItems.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedInventoryItems(
      items: items,
      total: json['total'] as int? ?? items.length,
      skip: json['skip'] as int? ?? 0,
      limit: json['limit'] as int? ?? items.length,
    );
  }
}

class InventoryMetrics {
  final int totalStock;
  final double inventoryValue;
  final int lowStockCount;
  final List<InventoryItem> lowStockItems;

  const InventoryMetrics({
    required this.totalStock,
    required this.inventoryValue,
    required this.lowStockCount,
    this.lowStockItems = const [],
  });

  factory InventoryMetrics.fromJson(Map<String, dynamic> json) {
    return InventoryMetrics(
      totalStock: json['total_stock'] as int? ?? 0,
      inventoryValue: InventoryItem._parseDecimal(json['inventory_value']),
      lowStockCount: json['low_stock_count'] as int? ?? 0,
      lowStockItems: (json['low_stock_items'] as List<dynamic>? ?? [])
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

const inventoryCategoryOptions = [
  'gold_bar',
  'gold_coin',
  'gold_ornament',
  'raw_gold',
];

const inventoryStatusOptions = ['active', 'inactive', 'discontinued'];

const inventorySortFields = [
  'item_name',
  'item_category',
  'stock_quantity',
  'current_value',
  'purchase_price',
  'status',
  'created_at',
];

const inventoryTableSortFields = <int, String>{
  0: 'item_name',
  1: 'item_category',
  2: 'stock_quantity',
  3: 'current_value',
  4: 'status',
};
