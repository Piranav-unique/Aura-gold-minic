// test/widget/dashboard_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/kpi_provider.dart';
import 'package:ags_gold/features/dashboard/domain/kpi.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/services/api_client.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockApiClient mockApi;
  late List<Kpi> mockKpis;

  setUp(() {
    mockApi = MockApiClient();
    mockKpis = [
      const Kpi(id: 'vault', title: 'Total Gold Vault', value: '142.84 kg'),
      const Kpi(id: 'users', title: 'Active Users', value: '24 Users'),
      const Kpi(id: 'health', title: 'System Health', value: 'Optimal'),
    ];
  });

  testWidgets('DashboardScreen shows KPI cards and interacts with chart', (WidgetTester tester) async {
    // Large screen to ensure no horizontal overflow on KPI trend labels
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
          kpiProvider.overrideWithValue(mockKpis),
          auditLogsProvider.overrideWithValue(const AsyncValue.data([])),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify KPI cards
    for (final kpi in mockKpis) {
      expect(find.text(kpi.title), findsOneWidget);
      expect(find.text(kpi.value), findsOneWidget);
    }

    // Find the chart widget and simulate pan
    final chartFinder = find.byType(PremiumFintechChart);
    expect(chartFinder, findsOneWidget);

    // Pan (hover) simulation on chart
    final gesture = await tester.startGesture(tester.getCenter(chartFinder));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    
    // Release gesture
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('DashboardScreen renders recent audit logs success/error/loading states', (WidgetTester tester) async {
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

    // 1. Success logs state
    final testLogs = [
      {
        'id': 'l1',
        'action': 'user_login_success',
        'ip_address': '192.168.1.1',
        'entity_type': 'user',
        'entity_id': 'u1',
        'timestamp': '2026-06-07T12:00:00Z',
      },
      {
        'id': 'l2',
        'action': 'role_deleted',
        'ip_address': '192.168.1.2',
        'entity_type': 'role',
        'entity_id': 'r2',
        'timestamp': '2026-06-07T12:15:00Z',
      }
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          kpiProvider.overrideWithValue(mockKpis),
          auditLogsProvider.overrideWithValue(AsyncValue.data(testLogs)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('USER LOGIN SUCCESS'), findsOneWidget);
    expect(find.text('ROLE DELETED'), findsOneWidget);

    // 2. Loading state
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          kpiProvider.overrideWithValue(mockKpis),
          auditLogsProvider.overrideWithValue(const AsyncValue.loading()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Card), findsAtLeastNWidgets(2)); // KPI cards & skeleton card

    // 3. Error state
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          kpiProvider.overrideWithValue(mockKpis),
          auditLogsProvider.overrideWithValue(AsyncValue.error('Forbidden access', StackTrace.empty)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Failed to load audit logs: Forbidden access'), findsOneWidget);
  });

  testWidgets('DashboardScreen quick action buttons navigate correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
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
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) {
            routesNavigated.add('/admin/users');
            return const Scaffold(body: Text('Users Screen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          kpiProvider.overrideWithValue(mockKpis),
          auditLogsProvider.overrideWithValue(const AsyncValue.data([])),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find and tap "Create User" quick operation
    final createUserBtn = find.text('Create User');
    expect(createUserBtn, findsOneWidget);
    await tester.tap(createUserBtn);
    await tester.pumpAndSettle();

    expect(routesNavigated, contains('/admin/users'));
  });
}
