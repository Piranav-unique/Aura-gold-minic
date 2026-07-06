import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/features/customers/presentation/customers_screen.dart';
import 'package:ags_gold/features/customers/presentation/customer_form_screen.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
    registerFallbackValue(<String, dynamic>{});
  });

  testWidgets('E2E customer management: create -> list -> delete', (
    WidgetTester tester,
  ) async {
    final customers = <Map<String, dynamic>>[];

    when(
      () => mockApi.get(
        '/customers/',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn({
        'items': List<Map<String, dynamic>>.from(customers),
        'total': customers.length,
        'skip': 0,
        'limit': 25,
      });
      return response;
    });

    when(
      () => mockApi.post('/customers/', data: any(named: 'data')),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as Map<String, dynamic>;
      final created = {
        'id': 'c-new-1',
        'customer_type': data['customer_type'],
        'full_name': data['full_name'],
        'mobile_number': data['mobile_number'],
        'email': data['email'],
        'address': data['address'],
        'gst_number': data['gst_number'],
        'status': data['status'] ?? 'active',
        'total_purchases': 0,
        'total_revenue': 0,
        'created_at': '2026-06-08T10:00:00Z',
        'updated_at': '2026-06-08T10:00:00Z',
      };
      customers.add(created);
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn(created);
      return response;
    });

    when(
      () => mockApi.delete(
        '/customers/c-new-1',
        data: any(named: 'data'),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      customers.clear();
      final response = MockResponse<Map<String, dynamic>>();
      when(
        () => response.data,
      ).thenReturn({'message': 'Customer deleted successfully'});
      return response;
    });

    final router = GoRouter(
      initialLocation: '/customers',
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
          builder: (context, state) => Scaffold(
            body: Center(child: Text('Detail ${state.pathParameters['id']}')),
          ),
        ),
      ],
    );

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi)
          profileProvider.overrideWithValue(
            AsyncValue.data(
              UserProfile(
                id: '11111111-1111-1111-1111-111111111111',
                mobileNumber: '9876543210',
                firstName: 'Admin',
                lastName: 'User',
                isActive: true,
                isSuperuser: true,
                createdAt: DateTime.utc(2026, 6, 8),
                updatedAt: DateTime.utc(2026, 6, 8),
              ),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full Name'),
      'E2E Customer',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile Number'),
      '+919876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'e2e.customer@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '789 Test Lane',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Customer'));
    await tester.pumpAndSettle();

    verify(
      () => mockApi.post('/customers/', data: any(named: 'data')),
    ).called(1);
    expect(find.text('Detail c-new-1'), findsOneWidget);
  });
}
