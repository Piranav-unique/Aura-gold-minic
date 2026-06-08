import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/dashboard_stats_provider.dart';
import 'package:ags_gold/features/dashboard/domain/dashboard_stats.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockApiClient mockApi;

  final mockStats = DashboardStats(
    recentActivity: const [],
    unreadNotifications: 2,
    securityAlerts: const [],
    recentNotifications: const [],
    loginStatistics: const LoginStatistics(today: 5, week: 12, month: 40),
  );

  setUp(() {
    mockApi = MockApiClient();
  });

  testWidgets('DashboardScreen shows stats and chart', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          dashboardStatsProvider.overrideWithValue(AsyncValue.data(mockStats)),
          auditLogsProvider.overrideWithValue(const AsyncValue.data([])),
          unreadNotificationsCountProvider.overrideWithValue(const AsyncValue.data(2)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Logins Today'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('Unread Alerts'), findsOneWidget);
    expect(find.byType(PremiumFintechChart), findsOneWidget);
  });

}
