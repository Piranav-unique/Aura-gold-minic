import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/features/customers/domain/customer.dart';
import 'package:ags_gold/features/customers/presentation/customers_screen.dart';
import 'package:ags_gold/features/customers/presentation/customer_form_screen.dart';
import 'package:ags_gold/features/customers/presentation/providers/customers_provider.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
    registerFallbackValue(<String, dynamic>{});
  });

  testWidgets('customer create flow navigates through list and form', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    when(
      () => mockApi.post('/customers/', data: any(named: 'data')),
    ).thenAnswer((_) async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn({
        'id': '22222222-2222-2222-2222-222222222222',
        'customer_type': 'individual',
        'full_name': 'New Customer',
        'mobile_number': '+919876543210',
        'email': 'new@example.com',
        'address': '789 Lane',
        'status': 'active',
        'total_purchases': 0,
        'total_revenue': 0,
        'created_at': '2026-06-08T10:00:00Z',
        'updated_at': '2026-06-08T10:00:00Z',
      });
      return response;
    });

    final router = GoRouter(
      initialLocation: '/customers/new',
      routes: [
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomersScreen(),
        ),
        GoRoute(
          path: '/customers/new',
          builder: (context, state) => const CustomerFormScreen(),
        ),
        GoRoute(
          path: '/customers/:id',
          builder: (context, state) =>
              Scaffold(body: Text('Detail ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          customersListProvider.overrideWithValue(
            const AsyncValue.data(
              PaginatedCustomers(items: [], total: 0, skip: 0, limit: 25),
            ),
          ),
          unreadNotificationsCountProvider.overrideWithValue(
            const AsyncValue.data(0),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full Name'),
      'New Customer',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile Number'),
      '+919876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'new@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '789 Lane',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Create Customer'));
    await tester.pumpAndSettle();

    verify(
      () => mockApi.post('/customers/', data: any(named: 'data')),
    ).called(1);
    expect(
      find.text('Detail 22222222-2222-2222-2222-222222222222'),
      findsOneWidget,
    );
  });
}
