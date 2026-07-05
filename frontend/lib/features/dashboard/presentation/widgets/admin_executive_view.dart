import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/premium_trend_chart.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';

/// Admin "Command Center" overview, laid out as an executive-insights board:
/// revenue hero → monthly/txns pair → performance chart → app ecosystem trio →
/// aggregate portfolio → executive brief. Cream/gold theme, real data only.
class AdminExecutiveView extends StatefulWidget {
  final ExecutiveDashboard data;

  const AdminExecutiveView({super.key, required this.data});

  static String formatGrams(double grams) {
    final kg = grams / 1000;
    final fmt = NumberFormat('#,##0.##');
    if (kg >= 1) {
      return '${fmt.format(kg)} KG';
    }
    return '${fmt.format(grams)} g';
  }

  @override
  State<AdminExecutiveView> createState() => _AdminExecutiveViewState();
}

enum _TrendRange { monthly, quarterly }

class _AdminExecutiveViewState extends State<AdminExecutiveView> {
  _TrendRange _range = _TrendRange.monthly;

  ExecutiveDashboard get data => widget.data;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final countFmt = NumberFormat.decimalPattern();
    final app = data.appMetrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (app != null) ...[
          _RevenueHeroCard(
            value: currency.format(app.totalRevenue),
            growthPercent: data.revenueGrowthPercent,
            onTap: () => context.go('/admin/payment-settlements'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  label: 'MONTHLY',
                  value: currency.format(app.monthlyRevenue),
                  trend: data.revenueGrowthPercent != null
                      ? '${data.revenueGrowthPercent! >= 0 ? '+' : ''}${data.revenueGrowthPercent!.toStringAsFixed(1)}%'
                      : 'this month',
                  positive: (data.revenueGrowthPercent ?? 0) >= 0,
                  onTap: () => context.go('/admin/payment-settlements'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStatCard(
                  label: 'TXNS',
                  value: countFmt.format(app.totalTransactions),
                  trend: '${countFmt.format(app.monthlyTransactions)} this mo',
                  positive: true,
                  onTap: () => context.go('/transactions'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (data.revenueTrend.isNotEmpty) ...[
          _buildPerformance(context),
          const SizedBox(height: 24),
        ],
        if (app != null) ...[
          _EcosystemSection(
            app: app,
            countFmt: countFmt,
          ),
          const SizedBox(height: 24),
          _PortfolioCard(
            valueLabel: currency.format(app.metalInventoryValue),
            goldLabel: AdminExecutiveView.formatGrams(app.goldAvailableGrams),
            silverLabel:
                AdminExecutiveView.formatGrams(app.silverAvailableGrams),
            onTap: () => context.go('/inventory'),
          ),
          const SizedBox(height: 24),
          _ExecutiveBriefCard(
            growthPercent: data.revenueGrowthPercent,
            lowStockCount: app.lowStockMetalCount,
            hasMonthlyRevenue: app.monthlyRevenue > 0,
          ),
        ],
      ],
    );
  }

  Widget _buildPerformance(BuildContext context) {
    final monthly = _range == _TrendRange.monthly;
    final points = monthly
        ? data.revenueTrend
        : _aggregateWeekly(data.revenueTrend);
    final values = points.map((p) => p.revenue).toList();
    final labels = points
        .map((p) => p.label.length > 10 ? p.label.substring(5) : p.label)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Performance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
            const Spacer(),
            _RangeToggle(
              range: _range,
              onChanged: (r) => setState(() => _range = r),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PremiumTrendChart(
          title: 'App Revenue',
          subtitle: monthly
              ? 'Daily paid gold purchases, last 30 days'
              : 'Weekly totals across the period',
          values: values,
          labels: labels,
          lineColor: AppTheme.goldDeep,
          interactive: true,
          formatValue: (v) => NumberFormat.currency(
            symbol: '₹',
            decimalDigits: 0,
          ).format(v),
          badge: data.revenueGrowthPercent != null
              ? '${data.revenueGrowthPercent! >= 0 ? '+' : ''}${data.revenueGrowthPercent!.toStringAsFixed(1)}% MoM'
              : null,
        ),
      ],
    );
  }

  List<RevenueTrendPoint> _aggregateWeekly(List<RevenueTrendPoint> raw) {
    if (raw.isEmpty) return raw;
    final buckets = <RevenueTrendPoint>[];
    for (var i = 0; i < raw.length; i += 7) {
      final end = (i + 7) <= raw.length ? i + 7 : raw.length;
      final chunk = raw.sublist(i, end);
      final total = chunk.fold<double>(0, (sum, p) => sum + p.revenue);
      final txns = chunk.fold<int>(0, (sum, p) => sum + p.transactionCount);
      buckets.add(
        RevenueTrendPoint(
          label: 'W${buckets.length + 1}',
          revenue: total,
          transactionCount: txns,
        ),
      );
    }
    return buckets;
  }
}

class _RevenueHeroCard extends StatelessWidget {
  final String value;
  final double? growthPercent;
  final VoidCallback onTap;

  const _RevenueHeroCard({
    required this.value,
    required this.growthPercent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = (growthPercent ?? 0) >= 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.goldGlowShadow,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TOTAL APP REVENUE',
                      style: TextStyle(
                        color: AppTheme.goldDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  if (growthPercent != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          positive
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 16,
                          color: const Color(0xFF1E5B34),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${positive ? '+' : ''}${growthPercent!.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Color(0xFF1E5B34),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AppTheme.ctaBlack,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final bool positive;
  final VoidCallback onTap;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.positive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    trend,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: positive ? AppTheme.emerald : AppTheme.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EcosystemSection extends StatelessWidget {
  final AppDashboardMetrics app;
  final NumberFormat countFmt;

  const _EcosystemSection({
    required this.app,
    required this.countFmt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = app.memberCount - app.membersNewThisMonth;
    final memberGrowth = base > 0
        ? (app.membersNewThisMonth / base) * 100
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App Ecosystem',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _EcosystemCard(
                label: 'MEMBERS',
                value: countFmt.format(app.memberCount),
                footnote: memberGrowth != null
                    ? '+${memberGrowth.toStringAsFixed(0)}%'
                    : '+${app.membersNewThisMonth}',
                footnotePositive: true,
                onTap: () => context.go('/admin/user-wallets'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EcosystemCard(
                label: 'ACQUISITION',
                value: countFmt.format(app.membersNewThisMonth),
                footnote: 'this month',
                footnotePositive: false,
                onTap: () => context.go('/admin/user-wallets'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EcosystemCard(
                label: 'SELL REQUESTS',
                value: countFmt.format(app.pendingSellRequests),
                footnote: app.sellRequestsThisMonth > 0
                    ? '${countFmt.format(app.sellRequestsThisMonth)} this month'
                    : 'awaiting review',
                footnotePositive: app.pendingSellRequests == 0,
                highlightPending: app.pendingSellRequests > 0,
                onTap: () => context.go('/admin/sell-inquiries'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EcosystemCard extends StatelessWidget {
  final String label;
  final String value;
  final String? footnote;
  final bool footnotePositive;
  final bool highlightPending;
  final VoidCallback onTap;

  const _EcosystemCard({
    required this.label,
    required this.value,
    this.footnote,
    this.footnotePositive = false,
    this.highlightPending = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.inkMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 16,
                child: Center(
                  child: footnote != null
                      ? Text(
                          footnote!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: highlightPending
                                ? const Color(0xFFB45309)
                                : footnotePositive
                                    ? AppTheme.emerald
                                    : AppTheme.inkMuted,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final String valueLabel;
  final String goldLabel;
  final String silverLabel;
  final VoidCallback onTap;

  const _PortfolioCard({
    required this.valueLabel,
    required this.goldLabel,
    required this.silverLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_outlined,
                    size: 18,
                    color: AppTheme.goldDeep,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AGGREGATE PORTFOLIO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        valueLabel,
                        maxLines: 1,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _MetalRow(
                      accent: AppTheme.primaryGold,
                      name: 'Gold (AU)',
                      amount: goldLabel,
                    ),
                  ),
                  Expanded(
                    child: _MetalRow(
                      accent: AppTheme.profileMuted,
                      name: 'Silver (AG)',
                      amount: silverLabel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetalRow extends StatelessWidget {
  final Color accent;
  final String name;
  final String amount;

  const _MetalRow({
    required this.accent,
    required this.name,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 2.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExecutiveBriefCard extends StatelessWidget {
  final double? growthPercent;
  final int lowStockCount;
  final bool hasMonthlyRevenue;

  const _ExecutiveBriefCard({
    required this.growthPercent,
    required this.lowStockCount,
    required this.hasMonthlyRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = (growthPercent ?? 0) >= 0;
    final healthWord = positive ? 'robust' : 'softening';
    final growthText = growthPercent != null
        ? '${positive ? '+' : ''}${growthPercent!.toStringAsFixed(1)}% MoM'
        : 'steady'; 
    final inventoryText = lowStockCount == 0
        ? 'Metal inventory is stable'
        : '$lowStockCount metal line(s) running low';
    final brief =
        'Ecosystem health $healthWord with $growthText revenue movement. '
        '$inventoryText; keep allocation conservative.';

    final liquidity = hasMonthlyRevenue ? 'High' : 'Low';
    final risk = lowStockCount == 0 ? 'Low' : 'Elevated';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Executive Brief',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppTheme.inkMuted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              brief,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: AppTheme.ink.withValues(alpha: 0.8),
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _BriefMetric(
                    label: 'LIQUIDITY',
                    value: liquidity,
                    color: hasMonthlyRevenue
                        ? AppTheme.emerald
                        : AppTheme.inkMuted,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppTheme.creamBorder,
                ),
                Expanded(
                  child: _BriefMetric(
                    label: 'RISK',
                    value: risk,
                    color: lowStockCount == 0
                        ? AppTheme.emerald
                        : AppTheme.amber,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  const _BriefMetric({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.inkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final _TrendRange range;
  final ValueChanged<_TrendRange> onChanged;

  const _RangeToggle({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.creamElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.creamBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(context, 'M', _TrendRange.monthly),
          _seg(context, 'Q', _TrendRange.quarterly),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, String label, _TrendRange value) {
    final selected = range == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? AppTheme.ink : AppTheme.inkMuted,
          ),
        ),
      ),
    );
  }
}
