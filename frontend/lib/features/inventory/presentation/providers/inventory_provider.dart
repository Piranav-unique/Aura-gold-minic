import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/inventory/domain/inventory_item.dart';
import 'package:ags_gold/features/inventory/domain/stock_movement.dart';
import 'package:ags_gold/features/inventory/domain/supplier.dart';
import 'package:ags_gold/services/service_providers.dart';

class InventorySearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final inventorySearchProvider =
    NotifierProvider<InventorySearchNotifier, String>(
      InventorySearchNotifier.new,
    );

class InventoryCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final inventoryCategoryFilterProvider =
    NotifierProvider<InventoryCategoryFilterNotifier, String?>(
      InventoryCategoryFilterNotifier.new,
    );

class InventoryStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final inventoryStatusFilterProvider =
    NotifierProvider<InventoryStatusFilterNotifier, String?>(
      InventoryStatusFilterNotifier.new,
    );

class InventoryLowStockFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void update(bool value) => state = value;
}

final inventoryLowStockFilterProvider =
    NotifierProvider<InventoryLowStockFilterNotifier, bool>(
      InventoryLowStockFilterNotifier.new,
    );

class InventorySortFieldNotifier extends Notifier<String> {
  @override
  String build() => 'created_at';
  void update(String value) => state = value;
}

final inventorySortFieldProvider =
    NotifierProvider<InventorySortFieldNotifier, String>(
      InventorySortFieldNotifier.new,
    );

class InventorySortAscNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final inventorySortAscProvider =
    NotifierProvider<InventorySortAscNotifier, bool>(
      InventorySortAscNotifier.new,
    );

class InventorySkipNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void update(int value) => state = value;
}

final inventorySkipProvider = NotifierProvider<InventorySkipNotifier, int>(
  InventorySkipNotifier.new,
);

class InventoryLimitNotifier extends Notifier<int> {
  @override
  int build() => 25;
  void update(int value) => state = value;
}

final inventoryLimitProvider = NotifierProvider<InventoryLimitNotifier, int>(
  InventoryLimitNotifier.new,
);

final inventoryListProvider =
    FutureProvider.autoDispose<PaginatedInventoryItems>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      final search = ref.watch(inventorySearchProvider);
      final category = ref.watch(inventoryCategoryFilterProvider);
      final status = ref.watch(inventoryStatusFilterProvider);
      final lowStockOnly = ref.watch(inventoryLowStockFilterProvider);
      final sortBy = ref.watch(inventorySortFieldProvider);
      final sortOrder = ref.watch(inventorySortAscProvider) ? 'asc' : 'desc';
      final skip = ref.watch(inventorySkipProvider);
      final limit = ref.watch(inventoryLimitProvider);

      final params = <String, dynamic>{
        'skip': skip,
        'limit': limit,
        'sort_by': sortBy,
        'sort_order': sortOrder,
        'low_stock_only': lowStockOnly,
      };
      if (search.isNotEmpty) params['search'] = search;
      if (category != null) params['item_category'] = category;
      if (status != null) params['status'] = status;

      final response = await apiClient.get(
        '/inventory/',
        queryParameters: params,
      );
      return PaginatedInventoryItems.fromJson(
        response.data as Map<String, dynamic>,
      );
    });

final inventoryMetricsProvider = FutureProvider.autoDispose<InventoryMetrics>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/inventory/metrics');
  return InventoryMetrics.fromJson(response.data as Map<String, dynamic>);
});

final inventoryDetailProvider = FutureProvider.autoDispose
    .family<InventoryItem, String>((ref, id) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get('/inventory/$id');
      return InventoryItem.fromJson(response.data as Map<String, dynamic>);
    });

final inventoryMovementsProvider = FutureProvider.autoDispose
    .family<PaginatedStockMovements, String>((ref, itemId) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get('/inventory/$itemId/movements');
      return PaginatedStockMovements.fromJson(
        response.data as Map<String, dynamic>,
      );
    });

final createInventoryProvider =
    Provider<Future<InventoryItem> Function(InventoryItem)>((ref) {
      return (InventoryItem item) async {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.post(
          '/inventory/',
          data: item.toCreateJson(),
        );
        ref.invalidate(inventoryListProvider);
        ref.invalidate(inventoryMetricsProvider);
        return InventoryItem.fromJson(response.data as Map<String, dynamic>);
      };
    });

final updateInventoryProvider =
    Provider<Future<InventoryItem> Function(InventoryItem)>((ref) {
      return (InventoryItem item) async {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.put(
          '/inventory/${item.id}',
          data: item.toUpdateJson(),
        );
        ref.invalidate(inventoryListProvider);
        ref.invalidate(inventoryDetailProvider(item.id));
        ref.invalidate(inventoryMetricsProvider);
        return InventoryItem.fromJson(response.data as Map<String, dynamic>);
      };
    });

final deleteInventoryProvider = Provider<Future<void> Function(String)>((ref) {
  return (String id) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.delete('/inventory/$id');
    ref.invalidate(inventoryListProvider);
    ref.invalidate(inventoryMetricsProvider);
  };
});

final stockInProvider =
    Provider<
      Future<InventoryItem> Function(
        String itemId,
        int quantity, {
        String? reference,
        String? notes,
        String? supplierId,
      })
    >((ref) {
      return (itemId, quantity, {reference, notes, supplierId}) async {
        final apiClient = ref.read(apiClientProvider);
        final data = <String, dynamic>{'quantity': quantity};
        if (reference != null) data['reference'] = reference;
        if (notes != null) data['notes'] = notes;
        if (supplierId != null) data['supplier_id'] = supplierId;
        final response = await apiClient.post(
          '/inventory/$itemId/stock-in',
          data: data,
        );
        ref.invalidate(inventoryDetailProvider(itemId));
        ref.invalidate(inventoryMovementsProvider(itemId));
        ref.invalidate(inventoryListProvider);
        ref.invalidate(inventoryMetricsProvider);
        return InventoryItem.fromJson(response.data as Map<String, dynamic>);
      };
    });

final stockOutProvider =
    Provider<
      Future<InventoryItem> Function(
        String itemId,
        int quantity, {
        String? reference,
        String? notes,
      })
    >((ref) {
      return (itemId, quantity, {reference, notes}) async {
        final apiClient = ref.read(apiClientProvider);
        final data = <String, dynamic>{'quantity': quantity};
        if (reference != null) data['reference'] = reference;
        if (notes != null) data['notes'] = notes;
        final response = await apiClient.post(
          '/inventory/$itemId/stock-out',
          data: data,
        );
        ref.invalidate(inventoryDetailProvider(itemId));
        ref.invalidate(inventoryMovementsProvider(itemId));
        ref.invalidate(inventoryListProvider);
        ref.invalidate(inventoryMetricsProvider);
        return InventoryItem.fromJson(response.data as Map<String, dynamic>);
      };
    });

final stockAdjustProvider =
    Provider<
      Future<InventoryItem> Function(
        String itemId,
        int newQuantity, {
        String? reason,
        String? notes,
      })
    >((ref) {
      return (itemId, newQuantity, {reason, notes}) async {
        final apiClient = ref.read(apiClientProvider);
        final data = <String, dynamic>{'new_quantity': newQuantity};
        if (reason != null) data['reason'] = reason;
        if (notes != null) data['notes'] = notes;
        final response = await apiClient.post(
          '/inventory/$itemId/stock-adjust',
          data: data,
        );
        ref.invalidate(inventoryDetailProvider(itemId));
        ref.invalidate(inventoryMovementsProvider(itemId));
        ref.invalidate(inventoryListProvider);
        ref.invalidate(inventoryMetricsProvider);
        return InventoryItem.fromJson(response.data as Map<String, dynamic>);
      };
    });

final suppliersListProvider = FutureProvider.autoDispose<PaginatedSuppliers>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final search = ref.watch(suppliersSearchProvider);
  final skip = ref.watch(suppliersSkipProvider);
  final params = <String, dynamic>{
    'limit': 25,
    'skip': skip,
    'sort_by': 'name',
    'sort_order': 'asc',
  };
  if (search.isNotEmpty) params['search'] = search;
  final response = await apiClient.get('/suppliers/', queryParameters: params);
  return PaginatedSuppliers.fromJson(response.data as Map<String, dynamic>);
});

final supplierDetailProvider = FutureProvider.autoDispose
    .family<Supplier, String>((ref, id) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get('/suppliers/$id');
      return Supplier.fromJson(response.data as Map<String, dynamic>);
    });

final createSupplierProvider = Provider<Future<Supplier> Function(Supplier)>((
  ref,
) {
  return (Supplier supplier) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post(
      '/suppliers/',
      data: supplier.toCreateJson(),
    );
    ref.invalidate(suppliersListProvider);
    return Supplier.fromJson(response.data as Map<String, dynamic>);
  };
});

final updateSupplierProvider = Provider<Future<Supplier> Function(Supplier)>((
  ref,
) {
  return (Supplier supplier) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.put(
      '/suppliers/${supplier.id}',
      data: supplier.toUpdateJson(),
    );
    ref.invalidate(suppliersListProvider);
    ref.invalidate(supplierDetailProvider(supplier.id));
    return Supplier.fromJson(response.data as Map<String, dynamic>);
  };
});

final deleteSupplierProvider = Provider<Future<void> Function(String)>((ref) {
  return (String id) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.delete('/suppliers/$id');
    ref.invalidate(suppliersListProvider);
  };
});

final globalMovementsProvider =
    FutureProvider.autoDispose<PaginatedStockMovements>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get(
        '/inventory/movements',
        queryParameters: {'limit': 50},
      );
      return PaginatedStockMovements.fromJson(
        response.data as Map<String, dynamic>,
      );
    });

final suppliersSearchProvider =
    NotifierProvider<SuppliersSearchNotifier, String>(
      SuppliersSearchNotifier.new,
    );

class SuppliersSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final suppliersSkipProvider = NotifierProvider<SuppliersSkipNotifier, int>(
  SuppliersSkipNotifier.new,
);

class SuppliersSkipNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void update(int value) => state = value;
}
