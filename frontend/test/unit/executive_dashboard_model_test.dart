import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';

void main() {
  test('ExecutiveDashboard.fromJson parses manager payload', () {
    final json = {
      'role': 'manager',
      'display_name': 'Jane Manager',
      'unread_notifications': 1,
      'refreshed_at': '2026-06-08T10:00:00Z',
      'team_metrics': {
        'active_users': 12,
        'pending_approvals': 3,
        'logins_today': 5,
        'team_activity_today': 42,
      },
      'pending_approvals': [
        {
          'id': 'a1',
          'request_number': 'WR-001',
          'title': 'Discount approval',
          'state': 'pending',
          'escalation_level': 0,
        },
      ],
      'inventory_alerts': [],
      'assigned_tasks': [],
      'daily_activities': [],
      'revenue_trend': [],
      'activity_trend': [],
    };

    final dashboard = ExecutiveDashboard.fromJson(json);

    expect(dashboard.role, 'manager');
    expect(dashboard.teamMetrics?.pendingApprovals, 3);
    expect(dashboard.pendingApprovals.single.title, 'Discount approval');
  });
}
