import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/referral/domain/referral_summary.dart';
import 'package:ags_gold/features/referral/presentation/providers/referral_provider.dart';
import 'package:ags_gold/features/referral/presentation/refer_and_earn_screen.dart';
import 'package:ags_gold/l10n/app_localizations.dart';

void main() {
  testWidgets('ReferAndEarnScreen displays scheme-wise coupon rewards and min deposits', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const mockSummary = ReferralSummary(
      referralCode: 'GOLD777',
      walletBalanceInr: 500,
      totalReferrals: 3,
      totalEarnedInr: 1050,
      tiers: [
        ReferralTier(schemeGrams: 1, rewardInr: 150, minPurchaseInr: 100),
        ReferralTier(schemeGrams: 5, rewardInr: 350, minPurchaseInr: 1000),
        ReferralTier(schemeGrams: 10, rewardInr: 550, minPurchaseInr: 2000),
      ],
    );

    final router = GoRouter(
      initialLocation: '/refer',
      routes: [
        GoRoute(
          path: '/refer',
          builder: (context, state) => const ReferAndEarnScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralSummaryProvider.overrideWith((ref) => Future.value(mockSummary)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify referral code
    expect(find.text('GOLD777'), findsOneWidget);

    // Verify scheme tiers
    expect(find.text('1g Scheme'), findsOneWidget);
    expect(find.text('5g Scheme'), findsOneWidget);
    expect(find.text('10g Scheme'), findsOneWidget);

    // Verify coupon rewards and min deposits
    expect(find.text('₹150'), findsWidgets);
    expect(find.text('₹100'), findsWidgets);

    expect(find.text('₹350'), findsWidgets);
    expect(find.text('₹1,000'), findsWidgets);

    expect(find.text('₹550'), findsWidgets);
    expect(find.text('₹2,000'), findsWidgets);
  });
}
