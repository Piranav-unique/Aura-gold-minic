import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/premium_trend_chart.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_history.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_price_history_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/metal_history_range_selector.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

const _aurumPurple = AppTheme.primaryGold;

class LivePriceScreen extends ConsumerStatefulWidget {
  final MetalType initialMetal;

  const LivePriceScreen({super.key, this.initialMetal = MetalType.gold});

  @override
  ConsumerState<LivePriceScreen> createState() => _LivePriceScreenState();
}

class _LivePriceScreenState extends ConsumerState<LivePriceScreen> {
  late MetalType _metal;
  MetalHistoryRange _range = MetalHistoryRange.y1;
  ChartPointSelection? _chartSelection;
  bool _chartScrubbing = false;

  @override
  void initState() {
    super.initState();
    _metal = widget.initialMetal;
  }

  @override
  void didUpdateWidget(covariant LivePriceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMetal != widget.initialMetal) {
      setState(() {
        _metal = widget.initialMetal;
        _chartSelection = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final spotAsync = ref.watch(metalPricesProvider);
    final historyAsync = ref.watch(
      metalHistoryProvider((metal: _metal, range: _range)),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.livePriceTitle),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: Text(l10n.setAlert),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(metalPricesProvider);
          ref.invalidate(metalHistoryProvider((metal: _metal, range: _range)));
          await Future.wait([
            ref.read(metalPricesProvider.future),
            ref.read(
              metalHistoryProvider((metal: _metal, range: _range)).future,
            ),
          ]);
        },
        child: ListView(
          physics: _chartScrubbing
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _MetalSegmentedToggle(
              selected: _metal,
              goldLabel: l10n.gold,
              silverLabel: l10n.silver,
              onChanged: (m) => setState(() {
                _metal = m;
                _chartSelection = null;
              }),
            ),
            const SizedBox(height: 20),
            spotAsync.when(
              data: (prices) {
                final quote = prices.quoteFor(_metal);
                return historyAsync.when(
                  data: (history) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _metal == MetalType.gold
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
                                  style: theme.textTheme.headlineMedium?.copyWith(
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
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PremiumTrendChart(
                        title: l10n.priceHistory,
                        subtitle: _metal == MetalType.gold
                            ? l10n.priceHistorySubtitleGold
                            : l10n.priceHistorySubtitleSilver,
                        values: _chartValues(history, quote),
                        labels: _chartLabels(history, quote),
                        tooltipDates: _chartTooltipDates(history, quote),
                        lineColor: _metal == MetalType.gold
                            ? AppTheme.primaryGold
                            : const Color(0xFFC0C0C0),
                        badge: l10n.live,
                        interactive: true,
                        formatValue: (v) => currency.format(v),
                        onSelectionChanged: (s) =>
                            setState(() => _chartSelection = s),
                        onScrubActiveChanged: (active) =>
                            setState(() => _chartScrubbing = active),
                        bottomChild: MetalHistoryRangeSelector(
                          selected: _range,
                          selectedColor: _aurumPurple,
                          onChanged: (r) => setState(() {
                            _range = r;
                            _chartSelection = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text(l10n.failedToLoadChart('$e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(l10n.failedToLoadLivePrice('$e')),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: () => context.go('/user-dashboard'),
            style: FilledButton.styleFrom(
              backgroundColor: _aurumPurple,
              foregroundColor: AppTheme.ink,
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(l10n.backToAurum),
          ),
        ),
      ),
    );
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
}

class _MetalSegmentedToggle extends StatelessWidget {
  final MetalType selected;
  final String goldLabel;
  final String silverLabel;
  final ValueChanged<MetalType> onChanged;

  const _MetalSegmentedToggle({
    required this.selected,
    required this.goldLabel,
    required this.silverLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: goldLabel,
              selected: selected == MetalType.gold,
              onTap: () => onChanged(MetalType.gold),
            ),
          ),
          Expanded(
            child: _Segment(
              label: silverLabel,
              selected: selected == MetalType.silver,
              onTap: () => onChanged(MetalType.silver),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _aurumPurple : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.ink : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
