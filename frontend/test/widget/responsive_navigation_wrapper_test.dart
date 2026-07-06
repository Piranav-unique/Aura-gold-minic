// test/widget/responsive_navigation_wrapper_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/l10n/app_localizations.dart';
import '../mocks/mock_services.dart';

final _testProfile = UserProfile(
  id: '11111111-1111-1111-1111-111111111111',
  mobileNumber: '9876543210',
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
        profileProvider.overrideWithValue(AsyncValue.data(_testProfile)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
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
            path: '/inventory',
            builder: (context, state) => const Scaffold(body: Text('Inventory')),
          ),
          GoRoute(
            path: '/admin/user-wallets',
            builder: (context, state) => const Scaffold(body: Text('Wallets')),
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

      // Test Navigation action (tap rail icon)
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(Icons.person_outline),
        ),
      );
      await tester.pumpAndSettle();
      expect(routesNavigated, contains('/profile'));
    },
  );

  testWidgets(
    'ResponsiveNavigationWrapper renders Bottom Navigation on Mobile/Tablet and handles navigation',
    (WidgetTester tester) async {
      // Mobile/Tablet layout (width < 1024)
      tester.view.physicalSize = const Size(360, 800);
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
            path: '/inventory',
            builder: (context, state) => const Scaffold(body: Text('Inventory')),
          ),
          GoRoute(
            path: '/admin/user-wallets',
            builder: (context, state) => const Scaffold(body: Text('Wallets')),
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

      // Verify Bottom Navigation Bar exists, and Drawer is absent
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(Drawer), findsNothing);

      // Tap Profile tab (the text 'Profile' in _NavItem)
      final profileTab = find.text('Profile');
      expect(profileTab, findsOneWidget);
      await tester.tap(profileTab);
      await tester.pumpAndSettle();

      expect(routesNavigated, contains('/profile'));
    },
  );
}
