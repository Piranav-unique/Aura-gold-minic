import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/customers/domain/customer.dart';
import 'package:ags_gold/features/customers/presentation/customer_detail_screen.dart';
import 'package:ags_gold/features/customers/presentation/providers/customers_provider.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

final _adminProfile = UserProfile(
  id: '11111111-1111-1111-1111-111111111111',
  mobileNumber: '9876543210',
  isActive: true,
  isSuperuser: true,
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

void main() {
  const customerId = '11111111-1111-1111-1111-111111111111';

  final sampleCustomer = Customer.fromJson({
    'id': customerId,
    'customer_type': 'business',
    'full_name': 'Gold Traders Pvt Ltd',
    'mobile_number': '+919876543210',
    'email': 'traders@example.com',
    'address': '42 Bullion Street, Mumbai',
    'gst_number': '27AAAAA0000A1Z5',
    'status': 'active',
    'total_purchases': 12,
    'total_revenue': 125000.50,
    'last_transaction_date': '2026-06-01T10:00:00Z',
    'created_at': '2026-06-08T10:00:00Z',
    'updated_at': '2026-06-08T10:00:00Z',
  });

  testWidgets('CustomerDetailScreen shows customer information', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/customers/$customerId',
      routes: [
        GoRoute(
          path: '/customers/:id',
          builder: (context, state) =>
              CustomerDetailScreen(customerId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          customerDetailProvider(
            customerId,
          ).overrideWithValue(AsyncValue.data(sampleCustomer))
          profileProvider.overrideWithValue(AsyncValue.data(_adminProfile)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Gold Traders Pvt Ltd'), findsOneWidget);
    expect(find.text('traders@example.com'), findsOneWidget);
    expect(find.text('27AAAAA0000A1Z5'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
