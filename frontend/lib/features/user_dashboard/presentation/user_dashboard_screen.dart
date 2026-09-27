import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/logging/app_event_log.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/domain/market_linked_holdings.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/kyc_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_buy_sell_buttons.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_dashboard_header.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_hero_portfolio_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_live_gold_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_quick_buy_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_scheme_journey_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_scheme_selection_sheet.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_security_trust_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_shop_withdrawal_sheet.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_useful_gold_info_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/kyc_prompt_dialog.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/kyc_trading_prompt_dialog.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dashboardAsync = ref.watch(personalDashboardProvider);
    final pricesAsync = ref.watch(metalPricesProvider);
    final kycComplete = ref.watch(effectiveKycCompleteProvider);

    return ResponsiveNavigationWrapper(
      title: l10n.navAurum,
      child: RefreshIndicator(
        color: AurumConsumerTheme.chipGold,
        onRefresh: () async {
          AppEventLog.action('dashboard_pull_refresh');
          ref.invalidate(kycStatusProvider);
          await ref.read(personalDashboardProvider.notifier).refresh();
          ref.invalidate(metalPricesProvider);
        },
        child: dashboardAsync.when(
          data: (data) {
            maybeShowKycPrompt(context, ref, verified: kycComplete);

            final goldRate = pricesAsync.asData?.value.gold.displayPrice ?? 15736.0;
            final silverRate = pricesAsync.asData?.value.silver.displayPrice ?? 255.0;

            final goldValue = MarketLinkedHoldings.currentValueInr(
              storedGrams: data.goldSavingsGrams,
              liveRatePerGram: goldRate,
            );
            final silverValue = MarketLinkedHoldings.currentValueInr(
              storedGrams: data.silverSavingsGrams,
              liveRatePerGram: silverRate,
            );

            final totalInvested = data.goldInvestedInr + data.silverInvestedInr;
            final totalValue = (goldValue + silverValue) > 0
                ? (goldValue + silverValue)
                : totalInvested;
            final gainInr = totalValue - totalInvested;
            final gainPct = totalInvested > 0 ? (gainInr / totalInvested) * 100 : 0.0;

            void handleBuyGold({double? amount}) {
              if (!kycComplete) {
                showKycTradingPrompt(
                  context,
                  ref,
                  isBuy: true,
                  metal: MetalType.gold,
                );
                return;
              }
              if (data.goldScheme.status.isNotSelected) {
                showSelectOrUpgradeSchemeSheet(
                  context: context,
                  ref: ref,
                  currentScheme: data.goldScheme,
                );
                return;
              }
              AppEventLog.action('buy_gold_tap', data: {
                'kyc_complete': true,
                'amount': ?amount,
              });
              final uri = amount != null
                  ? '/buy-gold?metal=gold&amount=${amount.toStringAsFixed(0)}'
                  : '/buy-gold?metal=gold';
              context.push(uri);
            }

            void handleSellGold() {
              if (!kycComplete) {
                showKycTradingPrompt(
                  context,
                  ref,
                  isBuy: false,
                  metal: MetalType.gold,
                );
                return;
              }
              if (data.goldScheme.status.isCompleted) {
                showShopWithdrawalSheet(
                  context: context,
                  goldGrams: data.goldSavingsGrams,
                  liveRatePerGram: goldRate,
                  onSellInquiryTap: () => context.push('/sell-gold-inquiry'),
                );
                return;
              }
              context.push('/sell-gold-inquiry');
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header (Greeting, User Name/Initials, Notification Icon with badge, Profile Avatar)
                  AurumDashboardHeader(
                    unreadNotifications: data.unreadNotifications,
                  ),
                  const SizedBox(height: 12),

                  // 2. Portfolio Overview (Total Value, Returns/Gain, Gold/Silver holdings, privacy toggle)
                  AurumHeroPortfolioCard(
                    totalValue: totalValue,
                    gainPct: gainPct,
                    gainInr: gainInr,
                    goldGrams: data.goldSavingsGrams,
                    silverGrams: data.silverSavingsGrams,
                    onDetailsTap: () => context.push('/portfolio'),
                  ),
                  const SizedBox(height: 14),

                  // 3. Live 24K Gold Price (24K only, live rate, 24h change, sparkline chart, [Full Chart >] linking to /live-price)
                  AurumLiveGoldCard(
                    livePricePerGram: goldRate,
                    change24hPct: 0.2,
                    onChartTap: () => context.push('/live-price'),
                  ),
                  const SizedBox(height: 14),

                  // 4. Clear [BUY GOLD] & [SELL GOLD] Actions (No SIP, No Add Funds)
                  AurumBuySellButtons(
                    onBuyGold: () => handleBuyGold(),
                    onSellGold: handleSellGold,
                  ),
                  const SizedBox(height: 14),

                  // 5. Quick Buy (Instant chips: ₹50, ₹100, ₹250, ₹500, ₹1,000, ₹2,000 + weight + Razorpay)
                  AurumQuickBuyCard(
                    liveGoldRatePerGram: goldRate,
                    onBuy: (amount) => handleBuyGold(amount: amount),
                    onCustomAmount: () => handleBuyGold(),
                  ),
                  const SizedBox(height: 14),

                  // 6. Scheme Journey (Goal progress tracking, 6-stage roadmap, completed state with Choose Another Scheme & Withdraw at Shop)
                  AurumSchemeJourneyCard(
                    goldScheme: data.goldScheme,
                    currentGrams: data.goldSavingsGrams,
                    liveRatePerGram: goldRate,
                    onChooseNextScheme: () => showSelectOrUpgradeSchemeSheet(
                      context: context,
                      ref: ref,
                      currentScheme: data.goldScheme,
                    ),
                    onSellInquiry: () => context.push('/sell-gold-inquiry'),
                  ),
                  const SizedBox(height: 14),

                  // 7. Verified Security & Trust (Razorpay, 256-bit SSL, User Isolation, 24K 99.9% Pure Gold)
                  const AurumSecurityTrustCard(),
                  const SizedBox(height: 14),

                  // 8. Useful Gold Information (Educational accordion: inflation hedge, purity, showroom redemption)
                  const AurumUsefulGoldInfoCard(),
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
