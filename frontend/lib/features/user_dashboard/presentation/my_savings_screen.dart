import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/domain/market_linked_holdings.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class MySavingsScreen extends ConsumerWidget {
  const MySavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dashboardAsync = ref.watch(personalDashboardProvider);
    final pricesAsync = ref.watch(metalPricesProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return ResponsiveNavigationWrapper(
        title: l10n.mySavings,
        child: dashboardAsync.when(
          data: (data) {
            final goldRate = pricesAsync.asData?.value.gold.displayPrice ?? 0;
            final silverRate = pricesAsync.asData?.value.silver.displayPrice ?? 0;
            final goldDisplayGrams = data.goldSavingsGrams > 0 && goldRate > 0
                ? MarketLinkedHoldings.marketLinkedGrams(
                    storedGrams: data.goldSavingsGrams,
                    investedInr: data.goldInvestedInr,
                    liveRatePerGram: goldRate,
                  )
                : data.goldSavingsGrams;
            final silverDisplayGrams = data.silverSavingsGrams > 0 && silverRate > 0
                ? MarketLinkedHoldings.marketLinkedGrams(
                    storedGrams: data.silverSavingsGrams,
                    investedInr: data.silverInvestedInr,
                    liveRatePerGram: silverRate,
                  )
                : data.silverSavingsGrams;
            final goldCurrent = data.goldSavingsGrams > 0 && goldRate > 0
                ? MarketLinkedHoldings.currentValueInr(
                    storedGrams: data.goldSavingsGrams,
                    liveRatePerGram: goldRate,
                  )
                : null;
            final silverCurrent = data.silverSavingsGrams > 0 && silverRate > 0
                ? MarketLinkedHoldings.currentValueInr(
                    storedGrams: data.silverSavingsGrams,
                    liveRatePerGram: silverRate,
                  )
                : null;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SavingsCard(
                  title: l10n.gold,
                  grams: goldDisplayGrams,
                  invested: l10n.goldInvestedAmount(
                    currency.format(data.goldInvestedInr),
                  ),
                  currentValue: goldCurrent != null
                      ? l10n.goldCurrentValue(currency.format(goldCurrent))
                      : null,
                  icon: Icons.monetization_on_rounded,
                  color: AppTheme.primaryGold,
                ),
                const SizedBox(height: 12),
                _SavingsCard(
                  title: l10n.silver,
                  grams: silverDisplayGrams,
                  invested: l10n.goldInvestedAmount(
                    currency.format(data.silverInvestedInr),
                  ),
                  currentValue: silverCurrent != null
                      ? l10n.goldCurrentValue(currency.format(silverCurrent))
                      : null,
                  icon: Icons.hexagon_outlined,
                  color: const Color(0xFFC0C0C0),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.failedToLoadDashboard('$e')),
          ),
        ),
    );
  }
}

class _SavingsCard extends StatelessWidget {
  final String title;
  final double grams;
  final String invested;
  final String? currentValue;
  final IconData icon;
  final Color color;

  const _SavingsCard({
    required this.title,
    required this.grams,
    required this.invested,
    this.currentValue,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AurumSurfaceCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AurumConsumerTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (currentValue != null) ...[
                  Text(
                    currentValue!,
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${grams.toStringAsFixed(4)} g',
                    style: TextStyle(
                      color: AurumConsumerTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else
                  Text(
                    '${grams.toStringAsFixed(4)} g',
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                Text(
                  invested,
                  style: TextStyle(
                    color: AurumConsumerTheme.textMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
