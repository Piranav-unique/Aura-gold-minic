import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/logging/app_event_log.dart';
import 'package:ags_gold/core/widgets/premium_trend_chart.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_history.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_price_history_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/metal_history_range_selector.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

const _aurumPurple = AppTheme.goldDeep;

void showLivePriceSheet(
  BuildContext context, {
  MetalType initialMetal = MetalType.gold,
}) {
  AppEventLog.action(
    'live_price_sheet_open',
    data: {'metal': initialMetal == MetalType.silver ? 'silver' : 'gold'},
  );
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) => LivePriceSheet(
        initialMetal: initialMetal,
        scrollController: scrollController,
      ),
    ),
  );
}

class LivePriceSheet extends ConsumerStatefulWidget {
  final MetalType initialMetal;
  final ScrollController scrollController;

  const LivePriceSheet({
    super.key,
    this.initialMetal = MetalType.gold,
    required this.scrollController,
  });

  @override
  ConsumerState<LivePriceSheet> createState() => _LivePriceSheetState();
}

class _LivePriceSheetState extends ConsumerState<LivePriceSheet> {
  late MetalType _selected;
  MetalHistoryRange _range = MetalHistoryRange.m1;
  ChartPointSelection? _chartSelection;
  bool _chartScrubbing = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMetal;
  }

  List<double> _chartValues(MetalHistory history, MetalQuote quote) {
    final points = history.points.isNotEmpty ? history.points : quote.trend;
    return points.map((p) => p.price).toList();
  }

  List<String> _chartLabels(MetalHistory history, MetalQuote quote) {
    final points = history.points.isNotEmpty ? history.points : quote.trend;
    return points.map((p) => p.label).toList();
  }

  List<String> _chartTooltipDates(MetalHistory history, MetalQuote quote) {
    final points = history.points.isNotEmpty ? history.points : quote.trend;
    return points.map((p) => p.date ?? '').toList();
  }

  String _formatChartDate(
    ChartPointSelection selection,
    MetalHistory history,
    MetalQuote quote,
  ) {
    final dates = _chartTooltipDates(history, quote);
    if (selection.index >= 0 && selection.index < dates.length) {
      final raw = dates[selection.index];
      if (raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) {
          return DateFormat('d MMM yyyy').format(parsed.toLocal());
        }
        return raw;
      }
    }
    return selection.label;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pricesAsync = ref.watch(metalPricesProvider);
    final historyAsync = ref.watch(
      metalHistoryProvider((metal: _selected, range: _range)),
    );
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return ListView(
      controller: widget.scrollController,
      physics: _chartScrubbing
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          l10n.livePrice,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        pricesAsync.when(
          data: (data) {
            final quote = data.quoteFor(_selected);
            return historyAsync.when(
              data: (history) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetalPriceTile(
                          label: l10n.gold,
                          price: currency.format(data.gold.displayPrice),
                          change: data.gold.changePercent,
                          selected: _selected == MetalType.gold,
                          accent: AppTheme.primaryGold,
                          icon: Icons.monetization_on_rounded,
                          onTap: () => setState(() {
                            _selected = MetalType.gold;
                            _chartSelection = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetalPriceTile(
                          label: l10n.silver,
                          price: currency.format(data.silver.displayPrice),
                          change: data.silver.changePercent,
                          selected: _selected == MetalType.silver,
                          accent: const Color(0xFFC0C0C0),
                          icon: Icons.hexagon_outlined,
                          onTap: () => setState(() {
                            _selected = MetalType.silver;
                            _chartSelection = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selected == MetalType.gold
                                  ? l10n.metalSpotGoldTamilNadu
                                  : l10n.metalSpotSilverTamilNadu,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                                Text(
                                  currency.format(
                                    _chartSelection?.value ?? quote.displayPrice,
                                  ),
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (_chartSelection != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatChartDate(
                                      _chartSelection!,
                                      history,
                                      quote,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.55),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                            Text(
                              l10n.perGramLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            l10n.performanceInRange(_range.apiValue),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (history.isUp
                                      ? AppTheme.emerald
                                      : AppTheme.rose)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              l10n.performanceChangeInRange(
                                history.isUp ? '↑' : '↓',
                                history.performancePercent
                                    .abs()
                                    .toStringAsFixed(2),
                                _range.apiValue,
                              ),
                              style: TextStyle(
                                color: history.isUp
                                    ? AppTheme.emerald
                                    : AppTheme.rose,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PremiumTrendChart(
                    title: l10n.priceHistory,
                    subtitle: _selected == MetalType.gold
                        ? l10n.priceHistorySubtitleGold
                        : l10n.priceHistorySubtitleSilver,
                    values: _chartValues(history, quote),
                    labels: _chartLabels(history, quote),
                    tooltipDates: _chartTooltipDates(history, quote),
                    lineColor: _selected == MetalType.gold
                        ? AppTheme.primaryGold
                        : const Color(0xFFC0C0C0),
                    badge: l10n.live,
                    compact: true,
                    interactive: true,
                    formatValue: (v) => currency.format(v),
                    onSelectionChanged: (s) =>
                        setState(() => _chartSelection = s),
                    onScrubActiveChanged: (active) =>
                        setState(() => _chartScrubbing = active),
                    bottomChild: MetalHistoryRangeSelector(
                      selected: _range,
                      onChanged: (r) => setState(() {
                        _range = r;
                        _chartSelection = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.priceUpdatedAt(
                      DateFormat('HH:mm').format(data.refreshedAt.toLocal()),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(l10n.failedToLoadLivePrice('$e')),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(l10n.failedToLoadLivePrice('$e')),
        ),
      ],
    );
  }
}

class _MetalPriceTile extends StatelessWidget {
  final String label;
  final String price;
  final double change;
  final bool selected;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _MetalPriceTile({
    required this.label,
    required this.price,
    required this.change,
    required this.selected,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isUp = change >= 0;

    return Material(
      color: selected
          ? accent.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? _aurumPurple : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                l10n.perGram,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${isUp ? '↑' : '↓'} ${change.abs().toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isUp ? AppTheme.emerald : AppTheme.rose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
