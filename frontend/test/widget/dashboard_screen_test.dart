import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';
import 'package:ags_gold/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/executive_dashboard_provider.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

final _adminProfile = UserProfile(
  id: '11111111-1111-1111-1111-111111111111',
  mobileNumber: '9876543210',
  firstName: 'Admin',
  lastName: 'User',
  isActive: true,
  isSuperuser: true,
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

ExecutiveDashboard _mockExecutive({String role = 'admin'}) {
  return ExecutiveDashboard(
    role: role,
    displayName: 'Admin User',
    unreadNotifications: 2,
    refreshedAt: DateTime.utc(2026, 6, 8, 10),
    customerMetrics: const CustomerDashboardMetrics(
      totalCustomers: 120,
      activeCustomers: 110,
      newThisMonth: 8,
    ),
    transactionMetrics: null,
  );
}

void main() {
  testWidgets('DashboardScreen shows executive hero and admin KPIs', (
    WidgetTester tester,
  ) async {
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
          apiClientProvider.overrideWithValue(MockApiClient()),
          profileProvider.overrideWithValue(AsyncValue.data(_adminProfile)),
          executiveDashboardProvider.overrideWith(
            (ref) => Stream.value(_mockExecutive()),
          )
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Executive Dashboard'), findsOneWidget);
    expect(find.text('ADMINISTRATOR'), findsOneWidget);
    expect(find.text('Customers'), findsWidgets);
    expect(find.text('120'), findsOneWidget);
  });
}
