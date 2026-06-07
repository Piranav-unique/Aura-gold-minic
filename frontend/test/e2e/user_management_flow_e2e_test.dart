import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/features/admin/presentation/users_screen.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockApiClient mockApi;
  late MockSecureStorage mockStorage;

  setUp(() {
    mockApi = MockApiClient();
    mockStorage = MockSecureStorage();
    registerFallbackValue(<String, dynamic>{});
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => true);
  });

  testWidgets('E2E user management: create -> update -> delete', (tester) async {
    final users = <Map<String, dynamic>>[];

    when(
      () => mockApi.get(
        '/users/',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      final response = MockResponse<List<dynamic>>();
      when(() => response.data).thenReturn(List<Map<String, dynamic>>.from(users));
      return response;
    });

    when(() => mockApi.post('/users/', data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as Map<String, dynamic>;
      final created = {
        'id': 'u-new-1',
        'email': data['email'],
        'first_name': data['first_name'] ?? '',
        'last_name': data['last_name'] ?? '',
        'is_active': true,
        'is_superuser': false,
        'roles': <Map<String, dynamic>>[],
      };
      users.add(created);
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn(created);
      return response;
    });

    when(() => mockApi.put('/users/u-new-1', data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as Map<String, dynamic>;
      users[0] = {...users[0], ...data};
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn(users[0]);
      return response;
    });

    when(
      () => mockApi.delete(
        '/users/u-new-1',
        data: any(named: 'data'),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      users.clear();
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn({'message': 'User deleted'});
      return response;
    });

    final router = GoRouter(
      initialLocation: '/admin/users',
      routes: [
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UsersScreen(),
        ),
      ],
    );

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          secureStorageProvider.overrideWithValue(mockStorage),
          rolesListProvider.overrideWithValue(const AsyncValue.data([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'New User'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Address'),
      'e2e.operator@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First Name'),
      'E2E',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('e2e.operator@example.com'), findsOneWidget);
    verify(() => mockApi.post('/users/', data: any(named: 'data'))).called(1);

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First Name'),
      'Updated',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    verify(() => mockApi.put('/users/u-new-1', data: any(named: 'data'))).called(1);

    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => mockApi.delete('/users/u-new-1')).called(1);
    expect(find.text('e2e.operator@example.com'), findsNothing);
  });
}
