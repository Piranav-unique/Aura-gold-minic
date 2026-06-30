import 'package:ags_gold/features/admin/domain/wallet_models.dart';

enum MetalStockStatus { available, lowStock, outOfStock }

MetalStockStatus metalStockStatusFromJson(String value) {
  switch (value) {
    case 'low_stock':
      return MetalStockStatus.lowStock;
    case 'out_of_stock':
      return MetalStockStatus.outOfStock;
    default:
      return MetalStockStatus.available;
  }
}

String metalStockStatusLabel(MetalStockStatus status) {
  switch (status) {
    case MetalStockStatus.lowStock:
      return 'Low Stock';
    case MetalStockStatus.outOfStock:
      return 'Out of Stock';
    case MetalStockStatus.available:
      return 'Available';
  }
}

class DigitalMetalInventory {
  final String id;
  final String metalType;
  final String metalLabel;
  final double totalWeightGrams;
  final double usedWeightGrams;
  final double availableWeightGrams;
  final double lowStockThresholdGrams;
  final MetalStockStatus stockStatus;
  final DateTime updatedAt;

  const DigitalMetalInventory({
    required this.id,
    required this.metalType,
    required this.metalLabel,
    required this.totalWeightGrams,
    required this.usedWeightGrams,
    required this.availableWeightGrams,
    required this.lowStockThresholdGrams,
    required this.stockStatus,
    required this.updatedAt,
  });

  factory DigitalMetalInventory.fromJson(Map<String, dynamic> json) {
    return DigitalMetalInventory(
      id: json['id'] as String,
      metalType: json['metal_type'] as String,
      metalLabel: json['metal_label'] as String? ?? '',
      totalWeightGrams: parseWalletDecimal(json['total_weight_grams']),
      usedWeightGrams: parseWalletDecimal(json['used_weight_grams']),
      availableWeightGrams: parseWalletDecimal(json['available_weight_grams']),
      lowStockThresholdGrams: parseWalletDecimal(json['low_stock_threshold_grams']),
      stockStatus: metalStockStatusFromJson(json['stock_status'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class DigitalMetalInventoryAlert {
  final String metalType;
  final String metalLabel;
  final MetalStockStatus stockStatus;
  final double availableWeightGrams;
  final double lowStockThresholdGrams;
  final String title;
  final String message;

  const DigitalMetalInventoryAlert({
    required this.metalType,
    required this.metalLabel,
    required this.stockStatus,
    required this.availableWeightGrams,
    required this.lowStockThresholdGrams,
    required this.title,
    required this.message,
  });

  factory DigitalMetalInventoryAlert.fromJson(Map<String, dynamic> json) {
    return DigitalMetalInventoryAlert(
      metalType: json['metal_type'] as String,
      metalLabel: json['metal_label'] as String? ?? '',
      stockStatus: metalStockStatusFromJson(json['stock_status'] as String),
      availableWeightGrams: parseWalletDecimal(json['available_weight_grams']),
      lowStockThresholdGrams: parseWalletDecimal(json['low_stock_threshold_grams']),
      title: json['title'] as String,
      message: json['message'] as String,
    );
  }
}

class DigitalMetalInventoryMovement {
  final String id;
  final String metalType;
  final String metalLabel;
  final String movementType;
  final double gramsDelta;
  final double availableWeightAfter;
  final String? notes;
  final DateTime createdAt;

  const DigitalMetalInventoryMovement({
    required this.id,
    required this.metalType,
    required this.metalLabel,
    required this.movementType,
    required this.gramsDelta,
    required this.availableWeightAfter,
    this.notes,
    required this.createdAt,
  });

  factory DigitalMetalInventoryMovement.fromJson(Map<String, dynamic> json) {
    return DigitalMetalInventoryMovement(
      id: json['id'] as String,
      metalType: json['metal_type'] as String,
      metalLabel: json['metal_label'] as String? ?? '',
      movementType: json['movement_type'] as String,
      gramsDelta: parseWalletDecimal(json['grams_delta']),
      availableWeightAfter: parseWalletDecimal(json['available_weight_after']),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PaginatedMetalMovements {
  final List<DigitalMetalInventoryMovement> items;
  final int total;

  const PaginatedMetalMovements({required this.items, required this.total});

  factory PaginatedMetalMovements.fromJson(Map<String, dynamic> json) {
    return PaginatedMetalMovements(
      items: (json['items'] as List<dynamic>)
          .map((e) => DigitalMetalInventoryMovement.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      total: json['total'] as int? ?? 0,
    );
  }
}
