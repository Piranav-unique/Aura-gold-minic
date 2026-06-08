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
}
