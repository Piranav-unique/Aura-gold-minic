import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/gold_holdings_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/home_promo_section.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/kyc_prompt_dialog.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/core/logging/app_event_log.dart';

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  void _onStartSip(BuildContext context, bool kycComplete) {
    AppEventLog.action('start_sip_tap', data: {'kyc_complete': kycComplete});
    context.push(kycComplete ? '/buy-gold?metal=gold' : '/kyc');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dashboardAsync = ref.watch(personalDashboardProvider);

    return ResponsiveNavigationWrapper(
      title: l10n.navAurum,
      child: RefreshIndicator(
        color: AurumConsumerTheme.chipGold,
        onRefresh: () async {
          AppEventLog.action('dashboard_pull_refresh');
          await ref.read(personalDashboardProvider.notifier).refresh();
          ref.invalidate(metalPricesProvider);
        },
        child: dashboardAsync.when(
          data: (data) {
            final verified = data.kycStatus.isComplete;

            // Unverified users get a one-time-per-session reminder popup
            // instead of any KYC banner on the home page itself.
            maybeShowKycPrompt(context, ref, verified: verified);

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GoldHoldingsCard(
                    goldGrams: data.goldSavingsGrams,
                    goldInvestedInr: data.goldInvestedInr,
                    kycStatus: data.kycStatus,
                    goldScheme: data.goldScheme,
                  ),
                  const SizedBox(height: 22),
                  StartSipBanner(
                    onTap: () => _onStartSip(context, verified),
                  ),
                  const SizedBox(height: 16),
                  const SocialProofCard(),
                  const SizedBox(height: 14),
                  const FeatureBadgesRow(),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: PremiumSkeletonList(itemCount: 3),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.failedToLoadDashboard('$error'),
                  style: TextStyle(color: AurumConsumerTheme.textMuted),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(personalDashboardProvider.notifier).refresh(),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
