// test/widget/responsive_navigation_wrapper_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import '../mocks/mock_services.dart';

final _testProfile = UserProfile(
  id: '11111111-1111-1111-1111-111111111111',
  email: 'operator@agsgold.com',
  firstName: 'AGS GOLD',
  lastName: 'Operator',
  isActive: true,
  isSuperuser: true,
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

void main() {
  late MockApiClient mockApi;
  late MockSecureStorage mockStorage;

  setUp(() {
    mockApi = MockApiClient();
    mockStorage = MockSecureStorage();
  });

  Widget buildTestWidget({
    required Widget child,
    required String title,
    required GoRouter router,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
        secureStorageProvider.overrideWithValue(mockStorage),
        unreadNotificationsCountProvider.overrideWithValue(
          const AsyncValue.data(0),
        ),
        profileProvider.overrideWithValue(AsyncValue.data(_testProfile)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
    'ResponsiveNavigationWrapper renders NavigationRail on Desktop and handles theme toggle, logout, and navigation',
    (WidgetTester tester) async {
      // Desktop layout (width >= 1024)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final routesNavigated = <String>[];
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const ResponsiveNavigationWrapper(
              title: 'Overview',
              child: Text('Dashboard Content'),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) {
              routesNavigated.add('/profile');
              return const Scaffold(body: Text('Profile Content'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: const Text('Dashboard Content'),
          title: 'Overview',
          router: router,
        ),
      );

      await tester.pumpAndSettle();

      // Verify NavigationRail exists
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Overview'), findsNWidgets(2));
      expect(find.text('Profile'), findsOneWidget);

      // Test Navigation action (tap rail icon; label may be hidden when unselected)
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(Icons.person_outline),
        ),
      );
      await tester.pumpAndSettle();
      expect(routesNavigated, contains('/profile'));

      // Go back to dashboard to test other sidebar actions
      router.go('/dashboard');
      await tester.pumpAndSettle();

      // Test Theme Toggle
      final themeToggleFinder = find.byTooltip('Toggle Theme');
      expect(themeToggleFinder, findsOneWidget);
      await tester.tap(themeToggleFinder);
      await tester.pumpAndSettle();

      // Test Logout cancel
      final logoutFinder = find.byTooltip('Log Out');
      expect(logoutFinder, findsOneWidget);
      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();

      // Verify dialog shown
      expect(find.text('Log Out'), findsNWidgets(2));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Log Out'), findsNothing);

      // Test Logout confirm
      when(() => mockStorage.getRefreshToken()).thenAnswer((_) async => null);
      when(() => mockStorage.clearTokens()).thenAnswer((_) async => {});

      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
      await tester.pumpAndSettle();
      // Resolve AuthNotifier's 2-second artificial splash delay timer
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'ResponsiveNavigationWrapper renders Drawer on Mobile/Tablet and handles drawer open, list navigation, and logout',
    (WidgetTester tester) async {
      // Mobile/Tablet layout (width < 1024)
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final routesNavigated = <String>[];
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const ResponsiveNavigationWrapper(
              title: 'Overview',
              child: Text('Dashboard Content'),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) {
              routesNavigated.add('/profile');
              return const Scaffold(body: Text('Profile Content'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: const Text('Dashboard Content'),
          title: 'Overview',
          router: router,
        ),
      );

      await tester.pumpAndSettle();

      // Verify AppBar actions for mobile
      expect(find.byType(NavigationRail), findsNothing);
      final themeToggleBtn = find.byTooltip('Toggle Theme');
      expect(themeToggleBtn, findsOneWidget);
      await tester.tap(themeToggleBtn);
      await tester.pumpAndSettle();

      // Open Drawer
      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      // Verify Drawer is open and matches headers
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('AGS GOLD Operator'), findsOneWidget);
      expect(find.text('operator@agsgold.com'), findsOneWidget);

      // Navigate from Drawer list item
      final profileTile = find.widgetWithText(ListTile, 'Profile');
      expect(profileTile, findsOneWidget);
      await tester.tap(profileTile);
      await tester.pumpAndSettle();

      expect(routesNavigated, contains('/profile'));
    },
  );
}
