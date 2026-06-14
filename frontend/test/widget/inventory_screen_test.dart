import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/inventory/domain/inventory_item.dart';
import 'package:ags_gold/features/inventory/presentation/inventory_screen.dart';
import 'package:ags_gold/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

final _adminProfile = UserProfile(
  id: '11111111-1111-1111-1111-111111111111',
  email: 'admin@agsgold.com',
  firstName: 'Admin',
  lastName: 'User',
  isActive: true,
  isSuperuser: true,
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

void main() {
  final sampleItem = InventoryItem.fromJson({
    'id': '11111111-1111-1111-1111-111111111111',
    'item_name': 'Gold Bar 10g',
    'item_category': 'gold_bar',
    'weight': '10',
    'purity': '99.9',
    'purchase_price': '50000',
    'current_value': '55000',
    'stock_quantity': 10,
    'reorder_level': 5,
    'status': 'active',
    'is_low_stock': false,
    'created_at': '2026-06-08T10:00:00Z',
    'updated_at': '2026-06-08T10:00:00Z',
  });

  testWidgets('InventoryScreen shows inventory list', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/inventory',
      routes: [
        GoRoute(
          path: '/inventory',
          builder: (context, state) => const InventoryScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          inventoryListProvider.overrideWithValue(
            AsyncValue.data(
              PaginatedInventoryItems(
                items: [sampleItem],
                total: 1,
                skip: 0,
                limit: 25,
              ),
            ),
          ),
          inventoryMetricsProvider.overrideWithValue(
            AsyncValue.data(
              const InventoryMetrics(
                totalStock: 10,
                inventoryValue: 550000,
                lowStockCount: 0,
              ),
            ),
          ),
          unreadNotificationsCountProvider.overrideWithValue(
            const AsyncValue.data(0),
          ),
          profileProvider.overrideWithValue(AsyncValue.data(_adminProfile)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Gold Bar 10g'), findsOneWidget);
    expect(find.text('New Item'), findsOneWidget);
    expect(find.text('Total Stock'), findsOneWidget);
  });
}
