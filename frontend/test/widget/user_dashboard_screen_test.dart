import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/dashboard/domain/dashboard_stats.dart';
import 'package:ags_gold/features/user_dashboard/domain/personal_dashboard.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/user_dashboard_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/kyc_prompt_dialog.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/l10n/app_localizations.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';
import '../test_helpers/auth_dashboard_overrides.dart';

final _userProfile = UserProfile(
  id: '22222222-2222-2222-2222-222222222222',
  mobileNumber: '9876543210',
  firstName: 'Gold',
  lastName: 'User',
  isActive: true,
  isSuperuser: false,
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

class _ShownKycPromptNotifier extends KycPromptShownNotifier {
  @override
  bool build() => true;
}

PersonalDashboard _mockPersonal({KycStatus kycStatus = KycStatus.notStarted}) {
  return PersonalDashboard(
    displayName: 'Gold User',
    mobileNumber: '9876543210',
    roles: const ['employee'],
    unreadNotifications: 3,
    refreshedAt: DateTime.utc(2026, 6, 8, 10),
    loginStatistics: const LoginStatistics(today: 1, week: 4, month: 12),
    pendingTaskCount: 2,
    draftTaskCount: 1,
    kycStatus: kycStatus,
  );
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required PersonalDashboard dashboard,
  bool showKycPopup = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final router = GoRouter(
    initialLocation: '/user-dashboard',
    routes: [
      GoRoute(
        path: '/user-dashboard',
        builder: (context, state) => const UserDashboardScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(MockApiClient()),
        profileProvider.overrideWithValue(AsyncValue.data(_userProfile)),
        personalDashboardProvider.overrideWith(
          () => FixedPersonalDashboardNotifier(dashboard),
        ),
        metalPricesProvider.overrideWith(
          (ref) => Stream.value(dashboardTestMetalPrices()),
        )
        if (!showKycPopup)
          kycPromptShownProvider.overrideWith(_ShownKycPromptNotifier.new),
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
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('UserDashboardScreen shows pre-KYC consumer layout', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester, dashboard: _mockPersonal());

    expect(find.text('AURUM'), findsWidgets);
    // No KYC banner/prompt should be rendered inline on the home page.
    expect(find.text('Complete KYC to trade'), findsNothing);
    expect(find.text('Verify your identity'), findsNothing);
    expect(find.text('0.0000 g'), findsOneWidget);
    expect(find.text('Buy Gold'), findsOneWidget);
    expect(find.text('Sell Gold'), findsOneWidget);
    expect(find.text('My Profile'), findsNothing);
  });

  testWidgets('UserDashboardScreen shows verified consumer layout', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(
      tester,
      dashboard: _mockPersonal(kycStatus: KycStatus.verified),
    );

    expect(find.text('Gold holdings'), findsOneWidget);
    expect(find.text('Buy Gold'), findsOneWidget);
    expect(find.text('Sell Gold'), findsOneWidget);
    expect(find.text('KYC required'), findsNothing);
    expect(find.text('Complete KYC'), findsNothing);
    expect(find.text('Complete KYC to trade'), findsNothing);
    // Verified users never see the KYC popup.
    expect(find.text('Verify your identity'), findsNothing);
  });

  testWidgets('UserDashboardScreen pops up KYC reminder for unverified users', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(
      tester,
      dashboard: _mockPersonal(),
      showKycPopup: true,
    );

    expect(find.text('Verify your identity'), findsOneWidget);
    expect(find.text('Verify now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });
}
