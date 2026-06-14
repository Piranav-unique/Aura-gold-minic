import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/features/admin/presentation/users_screen.dart';
import 'package:ags_gold/features/profile/presentation/profile_screen.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

const xssPayload = "<script>alert('xss')</script>";

void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
    registerFallbackValue(<String, dynamic>{});
  });

  Future<void> pumpDesktop(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  testWidgets('UsersScreen renders XSS payload as literal text in DataTable', (
    WidgetTester tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/users',
      routes: [
        GoRoute(
          path: '/users',
          builder: (context, state) => const UsersScreen(),
        ),
      ],
    );

    await pumpDesktop(
      tester,
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          usersListProvider.overrideWithValue(
            AsyncValue.data([
              {
                'id': 'u1',
                'email': 'xss@example.com',
                'first_name': xssPayload,
                'last_name': 'User',
                'is_superuser': false,
                'is_active': true,
                'roles': [
                  {'id': 'r1', 'name': 'user'},
                ],
              },
            ]),
          ),
          rolesListProvider.overrideWithValue(const AsyncValue.data([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.textContaining('<script>'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders XSS payload in name as literal text', (
    WidgetTester tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    );

    await pumpDesktop(
      tester,
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          profileProvider.overrideWithValue(
            AsyncValue.data(
              UserProfile(
                id: '22222222-2222-2222-2222-222222222222',
                email: 'xss@example.com',
                firstName: xssPayload,
                lastName: 'User',
                isActive: true,
                isSuperuser: false,
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ),
          ),
          profileActivityProvider.overrideWithValue(const AsyncValue.data([])),
          unreadNotificationsCountProvider.overrideWithValue(
            const AsyncValue.data(0),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.textContaining('<script>'), findsOneWidget);
    expect(find.textContaining("alert('xss')"), findsOneWidget);
  });
}
