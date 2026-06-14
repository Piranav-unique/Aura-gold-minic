import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/customers/domain/customer.dart';
import 'package:ags_gold/features/customers/presentation/customers_screen.dart';
import 'package:ags_gold/features/customers/presentation/providers/customers_provider.dart';
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
  final sampleCustomer = Customer.fromJson({
    'id': '11111111-1111-1111-1111-111111111111',
    'customer_type': 'individual',
    'full_name': 'John Doe',
    'mobile_number': '+919876543210',
    'email': 'john@example.com',
    'address': '123 Main Street',
    'status': 'active',
    'total_purchases': 5,
    'total_revenue': 50000,
    'created_at': '2026-06-08T10:00:00Z',
    'updated_at': '2026-06-08T10:00:00Z',
  });

  testWidgets('CustomersScreen shows customer list', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/customers',
      routes: [
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomersScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          customersListProvider.overrideWithValue(
            AsyncValue.data(
              PaginatedCustomers(
                items: [sampleCustomer],
                total: 1,
                skip: 0,
                limit: 25,
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
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('New Customer'), findsOneWidget);
  });

  testWidgets('CustomersScreen shows empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/customers',
      routes: [
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomersScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          customersListProvider.overrideWithValue(
            const AsyncValue.data(
              PaginatedCustomers(items: [], total: 0, skip: 0, limit: 25),
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
    expect(find.text('No customers found'), findsOneWidget);
  });
}
