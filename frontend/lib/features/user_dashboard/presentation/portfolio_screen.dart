import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/aura_components.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/premium_trend_chart.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/domain/market_linked_holdings.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_history.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_price_history_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/metal_history_range_selector.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

/// Consumer "My Portfolio" tab: total value, gold/silver split, milestone
/// progress, an investment-growth chart, and recent holdings. Reuses the same
/// providers as the dashboard and My Savings so no new data source is needed.
class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  MetalHistoryRange _range = MetalHistoryRange.m6;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dashboardAsync = ref.watch(personalDashboardProvider);
    final pricesAsync = ref.watch(metalPricesProvider);
    final currency0 = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return ResponsiveNavigationWrapper(
      title: 'My Portfolio',
      child: RefreshIndicator(
        color: AppTheme.primaryGold,
        onRefresh: () async {
          await ref.read(personalDashboardProvider.notifier).refresh();
          ref.invalidate(metalPricesProvider);
        },
        child: dashboardAsync.when(
          data: (data) {
            final goldRate = pricesAsync.asData?.value.gold.displayPrice ?? 0;
            final silverRate =
                pricesAsync.asData?.value.silver.displayPrice ?? 0;

            final goldValue = MarketLinkedHoldings.currentValueInr(
              storedGrams: data.goldSavingsGrams,
              liveRatePerGram: goldRate,
            );
            final silverValue = MarketLinkedHoldings.currentValueInr(
              storedGrams: data.silverSavingsGrams,
              liveRatePerGram: silverRate,
            );
            final totalInvested =
                data.goldInvestedInr + data.silverInvestedInr;
            final totalValue = (goldValue + silverValue) > 0
                ? goldValue + silverValue
                : totalInvested;
            final gain = totalValue - totalInvested;
            final gainPct =
                totalInvested > 0 ? (gain / totalInvested) * 100 : 0.0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _TotalValueHero(
                  totalValue: currency0.format(totalValue),
                  gainPct: gainPct,
                  goldValue: currency0.format(goldValue),
                  silverValue: currency0.format(silverValue),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetalOwnedCard(
                        label: l10n.gold.toUpperCase(),
                        dotColor: AppTheme.primaryGold,
                        grams: data.goldSavingsGrams,
                        rate: goldRate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetalOwnedCard(
                        label: l10n.silver.toUpperCase(),
                        dotColor: const Color(0xFF9AA0A6),
                        grams: data.silverSavingsGrams,
                        rate: silverRate,
                      ),
                    ),
                  ],
                ),
                if (data.goldScheme.targetGrams != null) ...[
                  const SizedBox(height: 14),
                  AuraCard(
                    child: MilestoneProgressBar(
                      title:
                          'Progress to ${_trimGrams(data.goldScheme.targetGrams!)}g Milestone',
                      progress:
                          (data.goldScheme.progressPercent / 100).clamp(0, 1),
                      percentLabel:
                          '${data.goldScheme.progressPercent.toStringAsFixed(0)}%',
                      caption: data.goldScheme.remainingGrams > 0
                          ? '${_trimGrams(data.goldScheme.remainingGrams)}g more to reach your next milestone'
                          : 'Milestone reached',
                      captionIcon: Icons.flag_outlined,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _InvestmentGrowthCard(
                  range: _range,
                  onRangeChanged: (r) => setState(() => _range = r),
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'Recent Savings',
                  actionLabel: 'View All',
                  onAction: () => context.push('/my-savings'),
                ),
                const SizedBox(height: 6),
                AuraCard(
                  child: Column(
                    children: [
                      ListRowTile(
                        icon: Icons.monetization_on_rounded,
                        title: l10n.gold,
                        subtitle: goldRate > 0
                            ? '${currency0.format(goldRate)}/g'
                            : null,
                        trailing:
                            '${_trimGrams(data.goldSavingsGrams, 4)} g',
                        trailingSub: goldValue > 0
                            ? currency0.format(goldValue)
                            : null,
                      ),
                      Divider(
                        height: 20,
                        color: Theme.of(context).dividerColor,
                      ),
                      ListRowTile(
                        icon: Icons.hexagon_outlined,
                        title: l10n.silver,
                        subtitle: silverRate > 0
                            ? '${currency0.format(silverRate)}/g'
                            : null,
                        trailing:
                            '${_trimGrams(data.silverSavingsGrams, 4)} g',
                        trailingSub: silverValue > 0
                            ? currency0.format(silverValue)
                            : null,
                      ),
                    ],
                  ),
                ),
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
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.rose),
                const SizedBox(height: 12),
                Text(l10n.failedToLoadDashboard('$e')),
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

  String _trimGrams(double value, [int digits = 2]) {
    final s = value.toStringAsFixed(digits);
    if (!s.contains('.')) return s;
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}

class _TotalValueHero extends StatelessWidget {
  final String totalValue;
  final double gainPct;
  final String goldValue;
  final String silverValue;

  const _TotalValueHero({
    required this.totalValue,
    required this.gainPct,
    required this.goldValue,
    required this.silverValue,
  });

  @override
  Widget build(BuildContext context) {
    return GoldGradientCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Portfolio Value',
            style: TextStyle(
              color: AppTheme.goldDeep,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                totalValue,
                style: const TextStyle(
                  color: Color(0xFF20180A),
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                gainPct >= 0 ? Icons.north_east : Icons.south_east,
                size: 16,
                color: AppTheme.goldDeep,
              ),
              const SizedBox(width: 2),
              Text(
                '${gainPct >= 0 ? '' : ''}${gainPct.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: AppTheme.goldDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.35), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroSplit(label: 'Gold Value', value: goldValue),
              ),
              Expanded(
                child: _HeroSplit(
                  label: 'Silver Value',
                  value: silverValue,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSplit extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _HeroSplit({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.onGoldMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF20180A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MetalOwnedCard extends StatelessWidget {
  final String label;
  final Color dotColor;
  final double grams;
  final double rate;

  const _MetalOwnedCard({
    required this.label,
    required this.dotColor,
    required this.grams,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return AuraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Owned',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '${grams.toStringAsFixed(grams == grams.roundToDouble() ? 0 : 2)}g',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rate > 0 ? 'Price: ${currency.format(rate)}/g' : 'Price: —',
            style: const TextStyle(
              color: AppTheme.goldDeep,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestmentGrowthCard extends ConsumerWidget {
  final MetalHistoryRange range;
  final ValueChanged<MetalHistoryRange> onRangeChanged;

  const _InvestmentGrowthCard({
    required this.range,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      metalHistoryProvider((metal: MetalType.gold, range: range)),
    );
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return historyAsync.when(
      data: (history) {
        final points = history.points;
        final values = points.map((p) => p.price).toList();
        final labels = points.map((p) => p.label).toList();
        final tooltipDates = points.map((p) => p.date ?? '').toList();
        final minVal =
            values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
        final maxVal =
            values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
        final profit =
            values.length >= 2 ? values.last - values.first : 0.0;

        return PremiumTrendChart(
          title: 'Investment Growth',
          subtitle: 'Gold price per gram',
          values: values,
          labels: labels,
          tooltipDates: tooltipDates,
          interactive: true,
          formatValue: (v) => currency.format(v),
          badge: range.apiValue,
          bottomChild: Column(
            children: [
              const SizedBox(height: 8),
              MetalHistoryRangeSelector(
                selected: range,
                onChanged: onRangeChanged,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(label: 'Min', value: currency.format(minVal)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(label: 'Max', value: currency.format(maxVal)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'Profit',
                      value:
                          '${profit >= 0 ? '+' : ''}${currency.format(profit)}',
                      highlight: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const AuraCard(
        child: SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => AuraCard(
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'Unable to load chart',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primaryGold.withValues(alpha: 0.16)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? AppTheme.goldDeep : muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight ? AppTheme.goldDeep : theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
