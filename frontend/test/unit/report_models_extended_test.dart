import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/reports/domain/report.dart';

void main() {
  test('KpiCard and trend points parse edge values', () {
    final kpi = KpiCard.fromJson({'key': '', 'label': '', 'value': ''});
    expect(kpi.trendLabel, isNull);

    final revenue = RevenueTrendPoint.fromJson({
      'label': 'Jun',
      'revenue': 'invalid',
      'transaction_count': 0,
    });
    expect(revenue.revenue, 0);

    final inventory = InventoryTrendPoint.fromJson({});
    expect(inventory.netChange, 0);
    expect(inventory.movementCount, 0);

    final activity = ActivityTrendPoint.fromJson({'label': 'Mon', 'count': 2});
    expect(activity.count, 2);
  });

  test('AnalyticsOverview parses activity trend', () {
    final overview = AnalyticsOverview.fromJson({
      'activity_trend': [
        {'label': 'Mon', 'count': 4},
      ],
    });
    expect(overview.activityTrend.single.count, 4);
  });

  test('RevenueReport parses period and top customers', () {
    final report = RevenueReport.fromJson({
      'period_start': '2026-06-01T00:00:00Z',
      'period_end': '2026-06-30T00:00:00Z',
      'total_revenue': '15000.50',
      'transaction_count': 12,
      'revenue_growth_percent': '5.5',
      'daily_trend': [
        {'label': '2026-06-01', 'revenue': '1000', 'transaction_count': 1},
      ],
      'top_customers': [
        {'full_name': 'Acme', 'revenue': '5000'},
      ],
    });
    expect(report.totalRevenue, 15000.50);
    expect(report.dailyTrend, hasLength(1));
    expect(report.topCustomers.single['full_name'], 'Acme');
  });

  test('InventoryReport parses category breakdown', () {
    final report = InventoryReport.fromJson({
      'total_stock': 100,
      'inventory_value': '250000',
      'low_stock_count': 2,
      'item_count': 15,
      'by_category': [
        {'category': 'gold_bar', 'item_count': 5},
      ],
      'movement_trend': [
        {'label': 'Week 1', 'net_change': -3, 'movement_count': 4},
      ],
    });
    expect(report.itemCount, 15);
    expect(report.byCategory.single['category'], 'gold_bar');
    expect(report.movementTrend.single.netChange, -3);
  });

  test('CustomerReport parses revenue totals', () {
    final report = CustomerReport.fromJson({
      'total_customers': 50,
      'active_customers': 45,
      'total_revenue': '90000',
      'total_purchases': 120,
      'top_customers': [],
      'by_type': [
        {'customer_type': 'business', 'count': 10},
      ],
    });
    expect(report.totalRevenue, 90000);
    expect(report.byType.single['customer_type'], 'business');
  });

  test('TransactionReport and AuditReport parse optional periods', () {
    final txn = TransactionReport.fromJson({
      'period_start': '2026-06-01T00:00:00Z',
      'period_end': '2026-06-30T00:00:00Z',
      'total_count': 8,
      'breakdown': [
        {'transaction_type': 'sale', 'count': 5},
      ],
    });
    expect(txn.totalCount, 8);
    expect(txn.periodStart, isNotNull);

    final audit = AuditReport.fromJson({
      'total_events': 20,
      'breakdown': [
        {'action': 'login_success', 'count': 10},
      ],
    });
    expect(audit.totalEvents, 20);
    expect(audit.periodStart, isNull);
  });

  test('reportTypes and exportFormats constants are defined', () {
    expect(reportTypes, hasLength(5));
    expect(exportFormats, contains('csv'));
  });
}
