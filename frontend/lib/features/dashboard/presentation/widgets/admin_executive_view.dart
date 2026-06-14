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

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final txn = data.transactionMetrics;
    final customers = data.customerMetrics;
    final inventory = data.inventoryMetrics;

    final kpis = <Widget>[
      if (txn != null)
        DashboardKpiCard(
          label: 'Daily Revenue',
          value: currency.format(txn.dailyRevenue),
          trend: 'Paid transactions today',
          icon: Icons.payments_outlined,
          color: AppTheme.emerald,
        ),
      if (txn != null)
        DashboardKpiCard(
          label: 'Monthly Revenue',
          value: currency.format(txn.monthlyRevenue),
          trend: 'Month to date',
          icon: Icons.calendar_month_outlined,
          color: AppTheme.primaryGold,
        ),
      if (customers != null)
        DashboardKpiCard(
          label: 'Customers',
          value: '${customers.totalCustomers}',
          trend: '${customers.newThisMonth} new this month',
          icon: Icons.storefront_outlined,
          color: AppTheme.sapphireBlue,
        ),
      if (inventory != null)
        DashboardKpiCard(
          label: 'Inventory Value',
          value: currency.format(inventory.inventoryValue),
          trend: '${inventory.totalStock} units in stock',
          icon: Icons.inventory_2_outlined,
          color: AppTheme.amber,
        ),
      if (inventory != null && inventory.lowStockCount > 0)
        DashboardKpiCard(
          label: 'Low Stock',
          value: '${inventory.lowStockCount}',
          trend: 'Items below reorder level',
          icon: Icons.warning_amber_outlined,
          color: Colors.orange,
          positive: false,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dashboardKpiGrid(context, kpis),
        const SizedBox(height: 24),
        if (data.revenueTrend.isNotEmpty)
          DashboardSection(
            title: 'Revenue',
            actionLabel: 'Reports',
            onAction: () => context.go('/reports'),
            child: PremiumTrendChart(
              title: 'Revenue Performance',
              subtitle: 'Net revenue over the last 30 days',
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
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 900;
            final txnCard = _moduleCard(
              context,
              title: 'Transactions',
              icon: Icons.receipt_long_outlined,
              color: AppTheme.emerald,
              onTap: () => context.go('/transactions'),
              lines: txn == null
                  ? const ['No transaction access']
                  : [
                      'Daily: ${currency.format(txn.dailyRevenue)}',
                      'Monthly: ${currency.format(txn.monthlyRevenue)}',
                      if (txn.topCustomers.isNotEmpty)
                        'Top: ${txn.topCustomers.first.fullName}',
                    ],
            );
            final customerCard = _moduleCard(
              context,
              title: 'Customers',
              icon: Icons.people_outline,
              color: AppTheme.sapphireBlue,
              onTap: () => context.go('/customers'),
              lines: customers == null
                  ? const ['No customer access']
                  : [
                      'Total: ${customers.totalCustomers}',
                      'Active: ${customers.activeCustomers}',
                      'New: ${customers.newThisMonth} this month',
                    ],
            );
            final inventoryCard = _moduleCard(
              context,
              title: 'Inventory',
              icon: Icons.inventory_2_outlined,
              color: AppTheme.amber,
              onTap: () => context.go('/inventory'),
              lines: inventory == null
                  ? const ['No inventory access']
                  : [
                      'Value: ${currency.format(inventory.inventoryValue)}',
                      'Stock: ${inventory.totalStock} units',
                      'Alerts: ${inventory.lowStockCount} low stock',
                    ],
            );

            if (stacked) {
              return Column(
                children: [
                  txnCard,
                  const SizedBox(height: 12),
                  customerCard,
                  const SizedBox(height: 12),
                  inventoryCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: txnCard),
                const SizedBox(width: 12),
                Expanded(child: customerCard),
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
