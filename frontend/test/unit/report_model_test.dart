import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/reports/domain/report.dart';

void main() {
  test('AnalyticsOverview parses KPIs and trends', () {
    final analytics = AnalyticsOverview.fromJson({
      'kpis': [
        {
          'key': 'daily_revenue',
          'label': 'Daily Revenue',
          'value': '₹1,000',
          'trend_label': 'Today',
          'trend_positive': true,
        },
      ],
      'revenue_trend': [
        {'label': '2026-06-01', 'revenue': '5000.00', 'transaction_count': 2},
      ],
      'inventory_trend': [
        {'label': '2026-06-01', 'net_change': 5, 'movement_count': 3},
      ],
      'revenue_growth_percent': '12.50',
    });

    expect(analytics.kpis, hasLength(1));
    expect(analytics.revenueTrend.first.revenue, 5000);
    expect(analytics.inventoryTrend.first.netChange, 5);
    expect(analytics.revenueGrowthPercent, 12.5);
  });
}
