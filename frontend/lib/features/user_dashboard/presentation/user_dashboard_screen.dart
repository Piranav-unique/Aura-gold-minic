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
import 'package:ags_gold/core/utils/email_validator.dart';
import 'package:ags_gold/features/profile/presentation/widgets/add_email_dialog.dart';
import 'package:ags_gold/services/service_providers.dart';
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
            final hasValidEmail = !isPlaceholderEmail(data.email);
            maybeShowKycPrompt(context, ref, verified: kycComplete);
            if (!hasValidEmail && (kycComplete || ref.read(kycPromptShownProvider))) {
              maybeShowEmailPrompt(context, ref, currentEmail: data.email);
            }

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

              final userEmail = data.email ?? ref.read(profileProvider).value?.email;
              if (isPlaceholderEmail(userEmail)) {
                showAddEmailDialog(
                  context,
                  ref,
                  currentEmail: userEmail,
                  onEmailSaved: () {
                    if (context.mounted) {
                      handleBuyGold(amount: amount);
                    }
                  },
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
                'amount': amount,
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
              final userEmail = data.email ?? ref.read(profileProvider).value?.email;
              if (isPlaceholderEmail(userEmail)) {
                showAddEmailDialog(
                  context,
                  ref,
                  currentEmail: userEmail,
                  onEmailSaved: () {
                    if (context.mounted) {
                      handleSellGold();
                    }
                  },
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
                  if (!hasValidEmail) ...[
                    const SizedBox(height: 12),
                    _GmailVerificationBanner(
                      onVerifyTap: () => showAddEmailDialog(
                        context,
                        ref,
                        currentEmail: data.email,
                      ),
                    ),
                  ],
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

class _GmailVerificationBanner extends StatelessWidget {
  final VoidCallback onVerifyTap;

  const _GmailVerificationBanner({required this.onVerifyTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AurumConsumerTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF261D10) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gmail Verification Required',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Link your personal @gmail.com to receive official 24K Tax Invoices, gold vault custody certificates, and trade receipts.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.white70 : const Color(0xFF78350F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onVerifyTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text(
                'Verify Gmail',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
