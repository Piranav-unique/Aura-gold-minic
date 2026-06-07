// test/widget/admin_and_profile_screens_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/features/admin/presentation/permissions_screen.dart';
import 'package:ags_gold/features/admin/presentation/roles_screen.dart';
import 'package:ags_gold/features/admin/presentation/users_screen.dart';
import 'package:ags_gold/features/profile/presentation/profile_screen.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/services/api_client.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockApiClient mockApi;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockApi = MockApiClient();
  });

  testWidgets('PermissionsScreen renders correctly with data', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/permissions',
      routes: [
        GoRoute(
          path: '/permissions',
          builder: (context, state) => const PermissionsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          permissionsListProvider.overrideWithValue(
            const AsyncValue.data([
              {'id': '1', 'name': 'test.permission', 'description': 'Test Description'}
            ]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('System Permission Scopes'), findsOneWidget);
    expect(find.text('test.permission'), findsOneWidget);
    expect(find.text('Test Description'), findsOneWidget);
  });

  testWidgets('RolesScreen renders correctly with data', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/roles',
      routes: [
        GoRoute(
          path: '/roles',
          builder: (context, state) => const RolesScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          rolesListProvider.overrideWithValue(
            const AsyncValue.data([
              {
                'id': 'r1',
                'name': 'Test Role',
                'description': 'Test Role Description',
                'permissions': [
                  {'id': 'p1', 'name': 'test.permission', 'description': 'desc'}
                ]
              }
            ]),
          ),
          permissionsListProvider.overrideWithValue(
            const AsyncValue.data([]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Role Management'), findsOneWidget);
    expect(find.text('TEST ROLE'), findsOneWidget);
  });

  testWidgets('UsersScreen desktop layout renders and handles status toggle & delete', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockResponse = MockResponse<dynamic>();
    when(() => mockResponse.data).thenReturn({'id': 'u1'});
    when(() => mockApi.put(any(), data: any(named: 'data')))
        .thenAnswer((_) async => mockResponse);
    when(() => mockApi.delete(any()))
        .thenAnswer((_) async => mockResponse);

    final router = GoRouter(
      initialLocation: '/users',
      routes: [
        GoRoute(
          path: '/users',
          builder: (context, state) => const UsersScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          usersListProvider.overrideWithValue(
            const AsyncValue.data([
              {
                'id': 'u1',
                'email': 'operator@example.com',
                'first_name': 'Operator',
                'last_name': 'User',
                'is_active': true,
                'is_superuser': false,
                'roles': [
                  {'id': 'r1', 'name': 'Operator'}
                ]
              }
            ]),
          ),
          rolesListProvider.overrideWithValue(
            const AsyncValue.data([]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('User Management'), findsOneWidget);
    expect(find.text('operator@example.com'), findsOneWidget);

    // Test toggle status
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    verify(() => mockApi.put('/users/u1', data: {'is_active': false})).called(1);

    // Test delete user
    final deleteButton = find.byTooltip('Delete Operator');
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Confirm dialog is shown
    expect(find.text('Delete User'), findsOneWidget);
    final confirmDeleteButton = find.widgetWithText(FilledButton, 'Delete');
    await tester.tap(confirmDeleteButton);
    await tester.pumpAndSettle();

    verify(() => mockApi.delete('/users/u1')).called(1);
  });

  testWidgets('UsersScreen mobile layout renders and handles status toggle & delete', (WidgetTester tester) async {
    // Mobile dimensions (below 1024 is non-desktop, card view)
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockResponse = MockResponse<dynamic>();
    when(() => mockResponse.data).thenReturn({'id': 'u1'});
    when(() => mockApi.put(any(), data: any(named: 'data')))
        .thenAnswer((_) async => mockResponse);
    when(() => mockApi.delete(any()))
        .thenAnswer((_) async => mockResponse);

    final router = GoRouter(
      initialLocation: '/users',
      routes: [
        GoRoute(
          path: '/users',
          builder: (context, state) => const UsersScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          usersListProvider.overrideWithValue(
            const AsyncValue.data([
              {
                'id': 'u1',
                'email': 'operator@example.com',
                'first_name': 'Operator',
                'last_name': 'User',
                'is_active': true,
                'is_superuser': true,
                'roles': [
                  {'id': 'r1', 'name': 'Operator'}
                ]
              }
            ]),
          ),
          rolesListProvider.overrideWithValue(
            const AsyncValue.data([]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify it builds card view
    expect(find.text('operator@example.com'), findsOneWidget);
    expect(find.text('Superuser account'), findsOneWidget);

    // Test toggle status
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    verify(() => mockApi.put('/users/u1', data: {'is_active': false})).called(1);

    // Test delete user
    final deleteButton = find.widgetWithText(TextButton, 'Delete');
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Confirm dialog is shown
    expect(find.text('Delete User'), findsOneWidget);
    final confirmDeleteButton = find.widgetWithText(FilledButton, 'Delete');
    await tester.tap(confirmDeleteButton);
    await tester.pumpAndSettle();

    verify(() => mockApi.delete('/users/u1')).called(1);
  });

  testWidgets('ProfileScreen renders correctly with data', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          profileProvider.overrideWithValue(
            const AsyncValue.data({
              'email': 'profile@example.com',
              'first_name': 'Profile',
              'last_name': 'User',
              'is_active': true,
              'is_superuser': true,
              'role': {'name': 'Super Administrator', 'description': 'desc'}
            }),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('profile@example.com'), findsOneWidget);
  });
}
