import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/premium_trend_chart.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/executive_dashboard_provider.dart';

/// Admin "Command Center" overview, laid out as an executive-insights board:
/// live sync header → revenue hero → monthly/txns pair → payment status strip →
/// live user payments → performance chart → app ecosystem trio →
/// aggregate portfolio → executive brief. Cream/gold theme, real data only.
class AdminExecutiveView extends ConsumerStatefulWidget {
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
  ConsumerState<AdminExecutiveView> createState() => _AdminExecutiveViewState();
}

enum _TrendRange { monthly, quarterly }

class _AdminExecutiveViewState extends ConsumerState<AdminExecutiveView> {
  _TrendRange _range = _TrendRange.monthly;
  String? _selectedCustomerMobile;

  ExecutiveDashboard get data => widget.data;

  @override
  Widget build(BuildContext context) {
    final countFmt = NumberFormat.decimalPattern();
    final app = data.appMetrics;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: (app?.totalRevenue ?? 0) % 1 == 0 ? 0 : 2,
    );

    final isSyncing = ref.watch(razorpaySyncProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SyncStatusHeader(
          lastSyncedAt: data.paymentSummary?.lastSyncedAt ?? data.refreshedAt,
          isSyncing: isSyncing,
          onSync: () async {
            try {
              final result =
                  await ref.read(razorpaySyncProvider.notifier).syncNow();
              if (context.mounted) {
                final captured = result?['captured_count'] ?? 0;
                final rev = result?['total_revenue'] ?? 0;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Live Razorpay Synced: ₹$rev ($captured successful payments)',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sync failed: $e'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        ),
        const SizedBox(height: 16),
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
        if (data.paymentSummary != null) ...[
          _PaymentSummaryStrip(summary: data.paymentSummary!),
          const SizedBox(height: 20),
        ],
        if (data.customerSummaries.isNotEmpty) ...[
          _CustomerPaidBreakdownSection(
            customers: data.customerSummaries,
            selectedMobile: _selectedCustomerMobile,
            onCustomerTap: (mobile) {
              setState(() {
                if (_selectedCustomerMobile == mobile) {
                  _selectedCustomerMobile = null;
                } else {
                  _selectedCustomerMobile = mobile;
                }
              });
            },
          ),
          const SizedBox(height: 20),
        ],
        _RecentUserPaymentsSection(
          payments: data.recentPayments,
          initialSearchQuery: _selectedCustomerMobile,
          onViewAll: () => context.go('/admin/payment-settlements'),
        ),
        const SizedBox(height: 24),
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

class _SyncStatusHeader extends StatelessWidget {
  final DateTime? lastSyncedAt;
  final bool isSyncing;
  final VoidCallback onSync;

  const _SyncStatusHeader({
    required this.lastSyncedAt,
    required this.isSyncing,
    required this.onSync,
  });

  String _formatLastSynced(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.creamElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.creamBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppTheme.emerald,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Razorpay Live Sync',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Last synced: ${_formatLastSynced(lastSyncedAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isSyncing ? null : onSync,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGold.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSyncing)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.goldDeep,
                        ),
                      )
                    else
                      const Icon(
                        Icons.sync_rounded,
                        size: 16,
                        color: AppTheme.goldDeep,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      isSyncing ? 'Syncing...' : 'Sync with Razorpay',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppTheme.goldDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSummaryStrip extends StatelessWidget {
  final AdminPaymentSummary summary;

  const _PaymentSummaryStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.creamBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              label: 'CAPTURED',
              count: summary.totalCapturedCount,
              amount: summary.totalCapturedRevenue,
              color: AppTheme.emerald,
            ),
          ),
          Container(width: 1, height: 36, color: AppTheme.creamBorder),
          Expanded(
            child: _summaryItem(
              label: 'PENDING',
              count: summary.totalPendingCount,
              amount: null,
              color: const Color(0xFFD97706),
            ),
          ),
          Container(width: 1, height: 36, color: AppTheme.creamBorder),
          Expanded(
            child: _summaryItem(
              label: 'FAILED',
              count: summary.totalFailedCount,
              amount: null,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String label,
    required int count,
    required double? amount,
    required Color color,
  }) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (amount != null) ...[
            Text(
              currency.format(amount),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerPaidBreakdownSection extends StatelessWidget {
  final List<CustomerPaymentSummary> customers;
  final String? selectedMobile;
  final ValueChanged<String> onCustomerTap;

  const _CustomerPaidBreakdownSection({
    required this.customers,
    required this.selectedMobile,
    required this.onCustomerTap,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    'Paying Customers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${customers.length} users',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selectedMobile != null)
              TextButton.icon(
                onPressed: () => onCustomerTap(selectedMobile!),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Clear Filter', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.inkMuted,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Exact live successful payments captured via Razorpay. Tap any user to filter transactions below.',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.inkMuted,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.creamBorder),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: customers.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.creamBorder.withValues(alpha: 0.6),
            ),
            itemBuilder: (context, index) {
              final c = customers[index];
              final isSelected = selectedMobile != null &&
                  (selectedMobile == c.mobile ||
                      selectedMobile == c.mobile.replaceAll(RegExp(r'\D'), ''));

              final displayPhone = c.mobile.startsWith('+91')
                  ? c.mobile
                  : (c.mobile.length == 10
                      ? '+91 ${c.mobile.substring(0, 5)} ${c.mobile.substring(5)}'
                      : c.mobile);

              return Material(
                color: isSelected
                    ? AppTheme.primaryGold.withValues(alpha: 0.12)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => onCustomerTap(c.mobile),
                  borderRadius: index == 0
                      ? const BorderRadius.vertical(top: Radius.circular(16))
                      : (index == customers.length - 1
                          ? const BorderRadius.vertical(bottom: Radius.circular(16))
                          : BorderRadius.zero),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryGold.withValues(alpha: 0.25)
                                : AppTheme.creamElevated,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.goldDeep
                                  : AppTheme.creamBorder,
                            ),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 20,
                            color: isSelected
                                ? AppTheme.goldDeep
                                : AppTheme.inkMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    displayPhone,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? AppTheme.goldDeep
                                          : AppTheme.ink,
                                    ),
                                  ),
                                  if (c.name != null && c.name!.isNotEmpty)
                                    Text(
                                      '(${c.name})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.inkMuted,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 11,
                                          color: AppTheme.emerald,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${c.successCount} paid',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.emerald,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (c.totalGrams > 0)
                                    Text(
                                      '${c.totalGrams.toStringAsFixed(4)}g gold',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.inkMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currency.format(c.totalPaidInr),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSelected ? 'Filtering \u25BC' : 'Tap to filter',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.goldDeep
                                    : AppTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentUserPaymentsSection extends StatefulWidget {
  final List<AdminPaymentItem> payments;
  final String? initialSearchQuery;
  final VoidCallback onViewAll;

  const _RecentUserPaymentsSection({
    required this.payments,
    this.initialSearchQuery,
    required this.onViewAll,
  });

  @override
  State<_RecentUserPaymentsSection> createState() =>
      _RecentUserPaymentsSectionState();
}

class _RecentUserPaymentsSectionState
    extends State<_RecentUserPaymentsSection> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    _searchController = TextEditingController(text: _searchQuery);
  }

  @override
  void didUpdateWidget(covariant _RecentUserPaymentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery) {
      final newQuery = widget.initialSearchQuery ?? '';
      _searchController.text = newQuery;
      setState(() {
        _searchQuery = newQuery;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminPaymentItem> get _filteredPayments {
    return widget.payments.where((item) {
      if (_selectedFilter == 'Captured' &&
          item.status != 'paid' &&
          item.status != 'captured') {
        return false;
      }
      if (_selectedFilter == 'Pending' &&
          item.status != 'created' &&
          item.status != 'pending') {
        return false;
      }
      if (_selectedFilter == 'Failed' && item.status != 'failed') {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final mobile = (item.customerMobile ?? '').toLowerCase();
        final name = (item.customerName ?? '').toLowerCase();
        final email = (item.customerEmail ?? '').toLowerCase();
        final payId = (item.razorpayPaymentId ?? '').toLowerCase();
        final orderId = item.razorpayOrderId.toLowerCase();
        final rrn = (item.bankRrn ?? '').toLowerCase();
        if (!mobile.contains(query) &&
            !name.contains(query) &&
            !email.contains(query) &&
            !payId.contains(query) &&
            !orderId.contains(query) &&
            !rrn.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  int _countFor(String filter) {
    if (filter == 'All') return widget.payments.length;
    if (filter == 'Captured') {
      return widget.payments
          .where((i) => i.status == 'paid' || i.status == 'captured')
          .length;
    }
    if (filter == 'Pending') {
      return widget.payments
          .where((i) => i.status == 'created' || i.status == 'pending')
          .length;
    }
    if (filter == 'Failed') {
      return widget.payments.where((i) => i.status == 'failed').length;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, h:mm a');
    final items = _filteredPayments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'User Payments',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
            ),
            TextButton(
              onPressed: widget.onViewAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View Settlements',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.goldDeep,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Captured', 'Pending', 'Failed'].map((filter) {
              final selected = _selectedFilter == filter;
              final count = _countFor(filter);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('$filter ($count)'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                  selectedColor: AppTheme.primaryGold,
                  backgroundColor: AppTheme.creamElevated,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppTheme.ink : AppTheme.inkMuted,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppTheme.primaryGold
                        : AppTheme.creamBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        // Search TextField
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search mobile, pay_id, or RRN...',
            hintStyle: TextStyle(fontSize: 13, color: AppTheme.inkMuted),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.creamBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.creamBorder),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.creamBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: AppTheme.inkMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.payments.isEmpty
                      ? 'No user payments synced yet.'
                      : 'No payments match your filter.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length > 10 ? 10 : items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final row = items[index];
              return _PaymentCard(
                item: row,
                currency: currency,
                dateFormat: dateFormat,
                onTap: () => _showPaymentDetailSheet(context, row),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final AdminPaymentItem item;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _PaymentCard({
    required this.item,
    required this.currency,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCaptured = item.status == 'paid' || item.status == 'captured';
    final isFailed = item.status == 'failed';

    final statusColor = isCaptured
        ? AppTheme.emerald
        : isFailed
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706);

    final statusBg = isCaptured
        ? const Color(0xFFE8F5E9)
        : isFailed
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFFFF8E1);

    final statusText = isCaptured
        ? 'Captured'
        : isFailed
            ? 'Failed'
            : 'Pending';

    final effectiveDate = item.paidAt ?? item.createdAt;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.creamBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Customer Contact & Status
              Row(
                children: [
                  Icon(Icons.phone_android_rounded,
                      size: 16, color: AppTheme.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.customerMobile != null &&
                              item.customerMobile!.isNotEmpty
                          ? (item.customerMobile!.startsWith('+91')
                              ? item.customerMobile!
                              : '+91 ${item.customerMobile!}')
                          : (item.customerName ?? 'Customer'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCaptured
                              ? Icons.check_circle_rounded
                              : isFailed
                                  ? Icons.cancel_rounded
                                  : Icons.hourglass_top_rounded,
                          size: 13,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (item.customerName != null &&
                  item.customerMobile != null &&
                  item.customerName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.customerName!,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.inkMuted,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // Body: Amount and Asset
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currency.format(item.amountInr),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${item.metal.toUpperCase()} • ${item.grams.toStringAsFixed(4)} g',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.goldDeep,
                    ),
                  ),
                ],
              ),
              if (item.failureReason != null &&
                  item.failureReason!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.failureReason!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
              const Divider(height: 18),
              // Footer: Payment ID, Bank RRN & Date
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        final idToCopy =
                            item.razorpayPaymentId ?? item.razorpayOrderId;
                        Clipboard.setData(ClipboardData(text: idToCopy));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment ID copied'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              item.razorpayPaymentId ?? item.razorpayOrderId,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppTheme.inkMuted,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy_rounded,
                              size: 13, color: AppTheme.inkMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(effectiveDate.toLocal()),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                ],
              ),
              if (item.bankRrn != null && item.bankRrn!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'RRN: ${item.bankRrn!} • ${(item.paymentMethod ?? 'UPI').toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _showPaymentDetailSheet(BuildContext context, AdminPaymentItem item) {
  final currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  final dateFormat = DateFormat('MMM d, yyyy • h:mm:ss a');
  final isCaptured = item.status == 'paid' || item.status == 'captured';
  final effectiveDate = item.paidAt ?? item.createdAt;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.creamBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment Audit Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCaptured
                        ? const Color(0xFFE8F5E9)
                        : item.status == 'failed'
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCaptured
                        ? 'CAPTURED'
                        : item.status == 'failed'
                            ? 'FAILED'
                            : 'PENDING',
                    style: TextStyle(
                      color: isCaptured
                          ? AppTheme.emerald
                          : item.status == 'failed'
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFD97706),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sheetRow('Customer Phone', item.customerMobile ?? 'N/A'),
            if (item.customerName != null && item.customerName!.isNotEmpty)
              _sheetRow('Customer Name', item.customerName!),
            if (item.customerEmail != null && item.customerEmail!.isNotEmpty)
              _sheetRow('Customer Email', item.customerEmail!),
            _sheetRow('Payment ID', item.razorpayPaymentId ?? 'N/A', copyable: true, context: context),
            _sheetRow('Razorpay Order ID', item.razorpayOrderId, copyable: true, context: context),
            if (item.bankRrn != null && item.bankRrn!.isNotEmpty)
              _sheetRow('Bank RRN / UTR', item.bankRrn!, copyable: true, context: context),
            _sheetRow('Method', (item.paymentMethod ?? 'UPI').toUpperCase()),
            _sheetRow('Date & Time', dateFormat.format(effectiveDate.toLocal())),
            const Divider(height: 24),
            _sheetRow('Customer Paid', currency.format(item.amountInr), bold: true),
            _sheetRow('Metal Credited', '${item.grams.toStringAsFixed(4)} g ${item.metal.toUpperCase()}'),
            if (item.gstAmountInr != null)
              _sheetRow('GST (3%, internal)', currency.format(item.gstAmountInr!)),
            if (item.razorpayFeeInr != null)
              _sheetRow('Razorpay Fee', currency.format(item.razorpayFeeInr!)),
            if (item.merchantSettlementInr != null) ...[
              const Divider(height: 24),
              _sheetRow(
                'Merchant Net Settlement',
                currency.format(item.merchantSettlementInr!),
                bold: true,
                valueColor: AppTheme.emerald,
              ),
            ],
            if (item.failureReason != null && item.failureReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Reason: ${item.failureReason!}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _sheetRow(
  String label,
  String value, {
  bool bold = false,
  Color? valueColor,
  bool copyable = false,
  BuildContext? context,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.inkMuted,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (copyable && context != null)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $label'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? AppTheme.ink,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.copy_rounded, size: 13, color: AppTheme.inkMuted),
              ],
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppTheme.ink,
            ),
          ),
      ],
    ),
  );
}

