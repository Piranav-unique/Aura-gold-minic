import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/dashboard/domain/dashboard_stats.dart';

void main() {
  test('DashboardStats.fromJson parses widget data', () {
    final stats = DashboardStats.fromJson({
      'recent_activity': [
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'action': 'login_success',
          'timestamp': '2026-06-08T10:00:00Z',
        },
      ],
      'unread_notifications': 2,
      'security_alerts': [],
      'recent_notifications': [],
      'login_statistics': {'today': 1, 'week': 2, 'month': 3},
    });
    expect(stats.unreadNotifications, 2);
    expect(stats.loginStatistics.month, 3);
    expect(stats.recentActivity.first.action, 'login_success');
  });

  test('DashboardStats.fromJson parses optional metrics and trends', () {
    final stats = DashboardStats.fromJson({
      'recent_activity': [],
      'unread_notifications': 0,
      'security_alerts': [],
      'recent_notifications': [],
      'login_statistics': <String, dynamic>{},
      'activity_trend': [
        {'label': 'Mon', 'count': 5},
      ],
      'inventory_metrics': {
        'total_stock': 100,
        'inventory_value': '500000',
        'low_stock_count': 1,
        'low_stock_items': [],
      },
      'transaction_metrics': {
        'daily_revenue': '1000',
        'monthly_revenue': '10000',
        'top_customers': [],
      },
    });

    expect(stats.activityTrend.single.count, 5);
    expect(stats.inventoryMetrics?.totalStock, 100);
    expect(stats.transactionMetrics?.monthlyRevenue, 10000);
  });

  test('LoginStatistics and ActivityTrendPoint use defaults', () {
    expect(LoginStatistics.fromJson({}).today, 0);
    expect(ActivityTrendPoint.fromJson({}).count, 0);
  });
}
