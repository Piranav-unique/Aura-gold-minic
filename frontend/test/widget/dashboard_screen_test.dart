import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';
import 'package:ags_gold/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/executive_dashboard_provider.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/presentation/providers/app_audience_provider.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/l10n/app_localizations.dart';
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

class _TestStaffAudienceNotifier extends AppAudienceNotifier {
  @override
  AppAudience? build() => AppAudience.staffAdmin;
}

void main() {
  testWidgets('DashboardScreen shows executive hero and admin KPIs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
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
          appAudienceProvider.overrideWith(_TestStaffAudienceNotifier.new),
          apiClientProvider.overrideWithValue(MockApiClient()),
          profileProvider.overrideWithValue(AsyncValue.data(_adminProfile)),
          executiveDashboardProvider.overrideWith(
            (ref) => Stream.value(_mockExecutive()),
          )
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Executive Dashboard'), findsOneWidget);
    expect(find.text('ADMINISTRATOR'), findsOneWidget);
    expect(find.text('Razorpay Live Sync'), findsOneWidget);
    expect(find.text('User Payments'), findsOneWidget);
  });

  testWidgets('DashboardScreen displays Paying Customers and filters payments on tap', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
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

    final executiveWithCustomers = _mockExecutive().copyWith(
      customerSummaries: [
        const CustomerPaymentSummary(
          mobile: '+918428165069',
          name: 'Piranav',
          totalPaidInr: 100.01,
          successCount: 1,
          totalGrams: 0.0125,
        ),
        const CustomerPaymentSummary(
          mobile: '+917010196231',
          name: 'Customer 2',
          totalPaidInr: 18.41,
          successCount: 5,
          totalGrams: 0.0023,
        ),
      ],
      recentPayments: [
        AdminPaymentItem(
          id: 'pay_1',
          razorpayOrderId: 'order_1',
          razorpayPaymentId: 'pay_test_1',
          customerMobile: '+918428165069',
          customerName: 'Piranav',
          metal: 'gold',
          grams: 0.0125,
          amountInr: 100.01,
          status: 'captured',
          createdAt: DateTime.utc(2026, 6, 8, 10),
        ),
        AdminPaymentItem(
          id: 'pay_2',
          razorpayOrderId: 'order_2',
          razorpayPaymentId: 'pay_test_2',
          customerMobile: '+917010196231',
          customerName: 'Customer 2',
          metal: 'gold',
          grams: 0.0023,
          amountInr: 18.41,
          status: 'captured',
          createdAt: DateTime.utc(2026, 6, 8, 11),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appAudienceProvider.overrideWith(_TestStaffAudienceNotifier.new),
          apiClientProvider.overrideWithValue(MockApiClient()),
          profileProvider.overrideWithValue(AsyncValue.data(_adminProfile)),
          executiveDashboardProvider.overrideWith(
            (ref) => Stream.value(executiveWithCustomers),
          )
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Paying Customers'), findsOneWidget);
    expect(find.text('2 users'), findsOneWidget);
    expect(find.textContaining('84281'), findsWidgets);
    expect(find.text('₹100.01'), findsWidgets);

    // Tap on the customer row to filter
    await tester.tap(find.textContaining('84281').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify filter is active
    expect(find.text('Clear Filter'), findsOneWidget);
  });
}

