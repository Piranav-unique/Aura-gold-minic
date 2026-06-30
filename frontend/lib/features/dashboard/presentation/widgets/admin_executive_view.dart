import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/premium_trend_chart.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';
import 'package:ags_gold/features/dashboard/presentation/widgets/dashboard_shared.dart';

class AdminExecutiveView extends StatelessWidget {
  final ExecutiveDashboard data;

  const AdminExecutiveView({super.key, required this.data});

  static String _formatGrams(double grams) {
    final kg = grams / 1000;
    final fmt = NumberFormat('#,##0.##');
    if (kg >= 1) {
      return '${fmt.format(kg)} KG';
    }
    return '${fmt.format(grams)} g';
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final countFmt = NumberFormat.decimalPattern();
    final app = data.appMetrics;

    final kpis = <Widget>[
      if (app != null) ...[
        DashboardKpiCard(
          label: 'Total App Revenue',
          value: currency.format(app.totalRevenue),
          trend: 'All paid gold purchases',
          icon: Icons.payments_outlined,
          color: AppTheme.emerald,
        ),
        DashboardKpiCard(
          label: 'Monthly Revenue',
          value: currency.format(app.monthlyRevenue),
          trend: 'Paid purchases this month',
          icon: Icons.calendar_month_outlined,
          color: AppTheme.primaryGold,
        ),
        DashboardKpiCard(
          label: 'Transactions',
          value: countFmt.format(app.totalTransactions),
          trend: '${countFmt.format(app.monthlyTransactions)} this month',
          icon: Icons.receipt_long_outlined,
          color: AppTheme.sapphireBlue,
        ),
        DashboardKpiCard(
          label: 'App Members',
          value: countFmt.format(app.memberCount),
          trend: '${countFmt.format(app.membersNewThisMonth)} new this month',
          icon: Icons.people_outline,
          color: AppTheme.sapphireBlue,
        ),
        DashboardKpiCard(
          label: 'Metal Inventory Value',
          value: currency.format(app.metalInventoryValue),
          trend:
              'Gold ${_formatGrams(app.goldAvailableGrams)} · Silver ${_formatGrams(app.silverAvailableGrams)} available',
          icon: Icons.inventory_2_outlined,
          color: AppTheme.amber,
        ),
        if (app.lowStockMetalCount > 0)
          DashboardKpiCard(
            label: 'Metal Stock Alerts',
            value: '${app.lowStockMetalCount}',
            trend: 'Metals low or out of stock',
            icon: Icons.warning_amber_outlined,
            color: Colors.orange,
            positive: false,
          ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kpis.isNotEmpty) dashboardKpiGrid(context, kpis),
        if (kpis.isNotEmpty) const SizedBox(height: 24),
        if (data.revenueTrend.isNotEmpty)
          DashboardSection(
            title: 'Revenue',
            actionLabel: 'Transactions',
            onAction: () => context.go('/transactions'),
            child: PremiumTrendChart(
              title: 'App Revenue',
              subtitle: 'Paid gold purchases over the last 30 days',
              values: data.revenueTrend.map((p) => p.revenue).toList(),
              labels: data.revenueTrend
                  .map(
                    (p) => p.label.length > 10 ? p.label.substring(5) : p.label,
                  )
                  .toList(),
              lineColor: AppTheme.emerald,
              badge: data.revenueGrowthPercent != null
                  ? '${data.revenueGrowthPercent! >= 0 ? '+' : ''}${data.revenueGrowthPercent!.toStringAsFixed(1)}% MoM'
                  : null,
            ),
          ),
        if (data.revenueTrend.isNotEmpty) const SizedBox(height: 24),
        if (app != null)
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              final revenueCard = _moduleCard(
                context,
                title: 'Revenue',
                icon: Icons.payments_outlined,
                color: AppTheme.emerald,
                onTap: () => context.go('/admin/payment-settlements'),
                lines: [
                  'Total: ${currency.format(app.totalRevenue)}',
                  'Monthly: ${currency.format(app.monthlyRevenue)}',
                  'Today: ${currency.format(app.dailyRevenue)}',
                ],
              );
              final membersCard = _moduleCard(
                context,
                title: 'App Members',
                icon: Icons.people_outline,
                color: AppTheme.sapphireBlue,
                onTap: () => context.go('/admin/user-wallets'),
                lines: [
                  'Members: ${countFmt.format(app.memberCount)}',
                  'New this month: ${countFmt.format(app.membersNewThisMonth)}',
                  'Wallet activity: ${countFmt.format(app.totalTransactions)} txns',
                ],
              );
              final inventoryCard = _moduleCard(
                context,
                title: 'Metal Inventory',
                icon: Icons.inventory_2_outlined,
                color: AppTheme.amber,
                onTap: () => context.go('/inventory'),
                lines: [
                  'Value: ${currency.format(app.metalInventoryValue)}',
                  'Gold available: ${_formatGrams(app.goldAvailableGrams)}',
                  'Silver available: ${_formatGrams(app.silverAvailableGrams)}',
                ],
              );

              if (stacked) {
                return Column(
                  children: [
                    revenueCard,
                    const SizedBox(height: 12),
                    membersCard,
                    const SizedBox(height: 12),
                    inventoryCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: revenueCard),
                  const SizedBox(width: 12),
                  Expanded(child: membersCard),
                  const SizedBox(width: 12),
                  Expanded(child: inventoryCard),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _moduleCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required List<String> lines,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, size: 16, color: color),
                ],
              ),
              const SizedBox(height: 12),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
