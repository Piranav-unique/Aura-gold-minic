import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/domain/market_linked_holdings.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/user_statements_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_hero_portfolio_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_investment_summary_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_recent_transactions_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_transaction_history_section.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

/// Consumer "My Portfolio" tab: luxury portfolio hero, investment summary,
/// recent transactions snippet, and dedicated filterable transaction history.
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dashboardAsync = ref.watch(personalDashboardProvider);
    final pricesAsync = ref.watch(metalPricesProvider);
    final statementsAsync = ref.watch(userStatementsProvider);

    return ResponsiveNavigationWrapper(
      title: l10n.myPortfolio,
      child: RefreshIndicator(
        color: AppTheme.primaryGold,
        onRefresh: () async {
          ref.invalidate(userStatementsProvider);
          await ref.read(personalDashboardProvider.notifier).refresh();
          ref.invalidate(metalPricesProvider);
        },
        child: dashboardAsync.when(
          data: (data) {
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
                ? goldValue + silverValue
                : totalInvested;
            final gainInr = totalValue - totalInvested;
            final gainPct = totalInvested > 0 ? (gainInr / totalInvested) * 100 : 0.0;

            final totalTxCount = statementsAsync.asData?.value.total ??
                statementsAsync.asData?.value.items.length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // 1. Portfolio Overview (Total value, returns, gold & silver holdings, privacy toggle)
                AurumHeroPortfolioCard(
                  totalValue: totalValue,
                  gainPct: gainPct,
                  gainInr: gainInr,
                  goldGrams: data.goldSavingsGrams,
                  silverGrams: data.silverSavingsGrams,
                ),
                const SizedBox(height: 14),

                // 2. Investment Summary (Invested, Value, Gain %, Grams, Avg buy, Current rate, Total Tx Count)
                AurumInvestmentSummaryCard(
                  totalInvestedInr: data.goldInvestedInr,
                  currentValueInr: goldValue,
                  gainPct: gainPct,
                  goldGrams: data.goldSavingsGrams,
                  liveGoldRate: goldRate,
                  totalTransactionsCount: totalTxCount,
                ),
                const SizedBox(height: 14),

                // Silver Holdings Card (only shown if user owns silver)
                if (data.silverSavingsGrams > 0) ...[
                  _SilverHoldingsCard(
                    silverGrams: data.silverSavingsGrams,
                    silverInvestedInr: data.silverInvestedInr,
                    silverValue: silverValue,
                    silverRate: silverRate,
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. Recent Transactions (Last 5 transactions snippet with [View All >])
                AurumRecentTransactionsCard(
                  onViewAll: () => context.push('/user-transactions'),
                ),
                const SizedBox(height: 14),

                // 4. Dedicated Filterable Transaction History (All, Buy, Sell, Successful, Pending, Failed)
                const AurumTransactionHistorySection(),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: PremiumSkeletonList(itemCount: 3),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppTheme.rose,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.failedToLoadDashboard('$e'),
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

class _SilverHoldingsCard extends StatelessWidget {
  final double silverGrams;
  final double silverInvestedInr;
  final double silverValue;
  final double silverRate;

  const _SilverHoldingsCard({
    required this.silverGrams,
    required this.silverInvestedInr,
    required this.silverValue,
    required this.silverRate,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final isDark = AurumConsumerTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurumConsumerTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AurumConsumerTheme.borderOf(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.hexagon_outlined, size: 18, color: Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.silverSavings,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E1A14),
                    ),
                  ),
                  Text(
                    context.l10n.ratePerGram(currencyFormatter.format(silverRate)),
                    style: TextStyle(
                      fontSize: 11,
                      color: AurumConsumerTheme.muted(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${silverGrams.toStringAsFixed(2)} g',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E1A14),
                ),
              ),
              Text(
                currencyFormatter.format(silverValue),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
