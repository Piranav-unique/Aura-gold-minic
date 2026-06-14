import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';

void main() {
  test('ExecutiveDashboard.fromJson parses admin payload', () {
    final dashboard = ExecutiveDashboard.fromJson({
      'role': 'admin',
      'display_name': 'Admin User',
      'unread_notifications': 3,
      'refreshed_at': '2026-06-08T10:00:00Z',
      'revenue_growth_percent': '12.5',
      'revenue_trend': [
        {'label': 'Jun 1', 'revenue': '1000', 'transaction_count': 2},
      ],
      'customer_metrics': {
        'total_customers': 100,
        'active_customers': 90,
        'new_this_month': 5,
      },
      'inventory_metrics': {
        'total_stock': 500,
        'inventory_value': '1000000',
        'low_stock_count': 2,
        'low_stock_items': [],
      },
      'transaction_metrics': {
        'daily_revenue': '5000',
        'monthly_revenue': '50000',
        'top_customers': [],
      },
      'activity_trend': [
        {'label': 'Mon', 'count': 3},
      ],
    });

    expect(dashboard.role, 'admin');
    expect(dashboard.revenueGrowthPercent, 12.5);
    expect(dashboard.customerMetrics?.totalCustomers, 100);
    expect(dashboard.inventoryMetrics?.totalStock, 500);
    expect(dashboard.transactionMetrics?.dailyRevenue, 5000);
    expect(dashboard.revenueTrend.single.revenue, 1000);
  });

  test('ExecutiveDashboard.fromJson parses employee payload', () {
    final dashboard = ExecutiveDashboard.fromJson({
      'role': 'employee',
      'display_name': 'Staff User',
      'unread_notifications': 0,
      'refreshed_at': '2026-06-08T10:00:00Z',
      'assigned_tasks': [
        {
          'id': 'task-1',
          'request_number': 'WR-001',
          'title': 'Draft request',
          'state': 'draft',
          'request_type': 'general',
          'submitted_at': '2026-06-08T09:00:00Z',
        },
      ],
      'daily_activities': [
        {
          'id': 'log-1',
          'action': 'login_success',
          'entity_type': 'User',
          'entity_id': 'u1',
          'timestamp': '2026-06-08T08:00:00Z',
          'description': 'Signed in',
        },
      ],
      'inventory_alerts': [
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'item_name': 'Low Gold',
          'item_category': 'gold_bar',
          'stock_quantity': 2,
          'reorder_level': 5,
          'status': 'active',
          'created_at': '2026-06-08T00:00:00Z',
          'updated_at': '2026-06-08T00:00:00Z',
        },
      ],
    });

    expect(dashboard.assignedTasks.single.title, 'Draft request');
    expect(dashboard.dailyActivities.single.action, 'login_success');
    expect(dashboard.inventoryAlerts.single.itemName, 'Low Gold');
  });

  test('WorkflowApprovalSummary parses assignee metadata', () {
    final item = WorkflowApprovalSummary.fromJson({
      'id': 'wf-1',
      'request_number': 'WR-002',
      'title': 'Approval',
      'state': 'pending',
      'requester_name': 'Alice',
      'assignee_name': 'Bob',
      'pending_since': '2026-06-08T10:00:00Z',
      'escalation_level': 1,
    });
    expect(item.requesterName, 'Alice');
    expect(item.pendingSince, isNotNull);
    expect(item.escalationLevel, 1);
  });
}
