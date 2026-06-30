import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/admin/domain/metal_inventory_models.dart';
import 'package:ags_gold/services/service_providers.dart';

final digitalMetalInventoryProvider =
    FutureProvider.autoDispose<List<DigitalMetalInventory>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/admin/inventory/metals');
  final data = response.data as Map<String, dynamic>;
  return (data['items'] as List<dynamic>)
      .map((e) => DigitalMetalInventory.fromJson(e as Map<String, dynamic>))
      .toList();
});

final digitalMetalInventoryAlertsProvider =
    FutureProvider.autoDispose<List<DigitalMetalInventoryAlert>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/admin/inventory/alerts');
  final data = response.data as Map<String, dynamic>;
  return (data['items'] as List<dynamic>)
      .map((e) => DigitalMetalInventoryAlert.fromJson(e as Map<String, dynamic>))
      .toList();
});

final metalMovementsMetalProvider =
    NotifierProvider<MetalMovementsMetalNotifier, String>(
  MetalMovementsMetalNotifier.new,
);

class MetalMovementsMetalNotifier extends Notifier<String> {
  @override
  String build() => 'gold';

  void update(String metal) => state = metal;
}

final metalMovementsPageProvider =
    NotifierProvider<MetalMovementsPageNotifier, int>(
  MetalMovementsPageNotifier.new,
);

class MetalMovementsPageNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void update(int page) => state = page;
}

final digitalMetalMovementsProvider =
    FutureProvider.autoDispose<PaginatedMetalMovements>((ref) async {
  final api = ref.read(apiClientProvider);
  final metal = ref.watch(metalMovementsMetalProvider);
  final page = ref.watch(metalMovementsPageProvider);
  final response = await api.get(
    '/admin/inventory/metals/$metal/movements',
    queryParameters: {'page': page, 'limit': 20},
  );
  return PaginatedMetalMovements.fromJson(
    response.data as Map<String, dynamic>,
  );
});

final updateDigitalMetalInventoryProvider = Provider((ref) {
  final api = ref.read(apiClientProvider);

  return ({
    required String metalType,
    required double totalWeightGrams,
    required double lowStockThresholdGrams,
  }) async {
    final response = await api.put(
      '/admin/inventory/metals/$metalType',
      data: {
        'total_weight_grams': totalWeightGrams,
        'low_stock_threshold_grams': lowStockThresholdGrams,
      },
    );
    ref.invalidate(digitalMetalInventoryProvider);
    ref.invalidate(digitalMetalInventoryAlertsProvider);
    ref.invalidate(digitalMetalMovementsProvider);
    return DigitalMetalInventory.fromJson(
      response.data as Map<String, dynamic>,
    );
  };
});
