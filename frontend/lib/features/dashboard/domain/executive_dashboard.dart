import 'package:ags_gold/features/dashboard/domain/dashboard_stats.dart';
import 'package:ags_gold/features/inventory/domain/inventory_item.dart';
import 'package:ags_gold/features/transactions/domain/transaction.dart';

class RevenueTrendPoint {
  final String label;
  final double revenue;
  final int transactionCount;

  const RevenueTrendPoint({
    required this.label,
    required this.revenue,
    this.transactionCount = 0,
  });

  factory RevenueTrendPoint.fromJson(Map<String, dynamic> json) {
    return RevenueTrendPoint(
      label: json['label'] as String? ?? '',
      revenue: _parseDecimal(json['revenue']),
      transactionCount: json['transaction_count'] as int? ?? 0,
    );
  }
}

class AppDashboardMetrics {
  final double totalRevenue;
  final double monthlyRevenue;
  final double dailyRevenue;
  final int totalTransactions;
  final int monthlyTransactions;
  final int memberCount;
  final int membersNewThisMonth;
  final double metalInventoryValue;
  final double goldAvailableGrams;
  final double silverAvailableGrams;
  final int lowStockMetalCount;
  final int pendingSellRequests;
  final int sellRequestsThisMonth;

  const AppDashboardMetrics({
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.dailyRevenue,
    required this.totalTransactions,
    required this.monthlyTransactions,
    required this.memberCount,
    required this.membersNewThisMonth,
    required this.metalInventoryValue,
    required this.goldAvailableGrams,
    required this.silverAvailableGrams,
    this.lowStockMetalCount = 0,
    this.pendingSellRequests = 0,
    this.sellRequestsThisMonth = 0,
  });

  factory AppDashboardMetrics.fromJson(Map<String, dynamic> json) {
    return AppDashboardMetrics(
      totalRevenue: _parseDecimal(json['total_revenue']),
      monthlyRevenue: _parseDecimal(json['monthly_revenue']),
      dailyRevenue: _parseDecimal(json['daily_revenue']),
      totalTransactions: json['total_transactions'] as int? ?? 0,
      monthlyTransactions: json['monthly_transactions'] as int? ?? 0,
      memberCount: json['member_count'] as int? ?? 0,
      membersNewThisMonth: json['members_new_this_month'] as int? ?? 0,
      metalInventoryValue: _parseDecimal(json['metal_inventory_value']),
      goldAvailableGrams: _parseDecimal(json['gold_available_grams']),
      silverAvailableGrams: _parseDecimal(json['silver_available_grams']),
      lowStockMetalCount: json['low_stock_metal_count'] as int? ?? 0,
      pendingSellRequests: json['pending_sell_requests'] as int? ?? 0,
      sellRequestsThisMonth: json['sell_requests_this_month'] as int? ?? 0,
    );
  }
}

class CustomerDashboardMetrics {
  final int totalCustomers;
  final int activeCustomers;
  final int newThisMonth;

  const CustomerDashboardMetrics({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.newThisMonth,
  });

  factory CustomerDashboardMetrics.fromJson(Map<String, dynamic> json) {
    return CustomerDashboardMetrics(
      totalCustomers: json['total_customers'] as int? ?? 0,
      activeCustomers: json['active_customers'] as int? ?? 0,
      newThisMonth: json['new_this_month'] as int? ?? 0,
    );
  }
}

class TeamDashboardMetrics {
  final int activeUsers;
  final int pendingApprovals;
  final int loginsToday;
  final int teamActivityToday;

  const TeamDashboardMetrics({
    required this.activeUsers,
    required this.pendingApprovals,
    required this.loginsToday,
    required this.teamActivityToday,
  });

  factory TeamDashboardMetrics.fromJson(Map<String, dynamic> json) {
    return TeamDashboardMetrics(
      activeUsers: json['active_users'] as int? ?? 0,
      pendingApprovals: json['pending_approvals'] as int? ?? 0,
      loginsToday: json['logins_today'] as int? ?? 0,
      teamActivityToday: json['team_activity_today'] as int? ?? 0,
    );
  }
}

class WorkflowApprovalSummary {
  final String id;
  final String requestNumber;
  final String title;
  final String state;
  final String? requesterName;
  final String? assigneeName;
  final DateTime? pendingSince;
  final int escalationLevel;

  const WorkflowApprovalSummary({
    required this.id,
    required this.requestNumber,
    required this.title,
    required this.state,
    this.requesterName,
    this.assigneeName,
    this.pendingSince,
    this.escalationLevel = 0,
  });

  factory WorkflowApprovalSummary.fromJson(Map<String, dynamic> json) {
    return WorkflowApprovalSummary(
      id: json['id'] as String,
      requestNumber: json['request_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      state: json['state'] as String? ?? '',
      requesterName: json['requester_name'] as String?,
      assigneeName: json['assignee_name'] as String?,
      pendingSince: json['pending_since'] != null
          ? DateTime.parse(json['pending_since'] as String)
          : null,
      escalationLevel: json['escalation_level'] as int? ?? 0,
    );
  }
}

class AssignedTaskSummary {
  final String id;
  final String requestNumber;
  final String title;
  final String state;
  final String requestType;
  final DateTime? submittedAt;

  const AssignedTaskSummary({
    required this.id,
    required this.requestNumber,
    required this.title,
    required this.state,
    required this.requestType,
    this.submittedAt,
  });

  factory AssignedTaskSummary.fromJson(Map<String, dynamic> json) {
    return AssignedTaskSummary(
      id: json['id'] as String,
      requestNumber: json['request_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      state: json['state'] as String? ?? '',
      requestType: json['request_type'] as String? ?? 'general',
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
    );
  }
}

class DailyActivityItem {
  final String id;
  final String action;
  final String? entityType;
  final String? entityId;
  final DateTime timestamp;
  final String description;

  const DailyActivityItem({
    required this.id,
    required this.action,
    this.entityType,
    this.entityId,
    required this.timestamp,
    required this.description,
  });

  factory DailyActivityItem.fromJson(Map<String, dynamic> json) {
    return DailyActivityItem(
      id: json['id'] as String,
      action: json['action'] as String? ?? '',
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      description: json['description'] as String? ?? '',
    );
  }
}

class ExecutiveDashboard {
  final String role;
  final String displayName;
  final int unreadNotifications;
  final DateTime refreshedAt;
  final List<RevenueTrendPoint> revenueTrend;
  final double? revenueGrowthPercent;
  final CustomerDashboardMetrics? customerMetrics;
  final AppDashboardMetrics? appMetrics;
  final InventoryMetrics? inventoryMetrics;
  final TransactionMetrics? transactionMetrics;
  final TeamDashboardMetrics? teamMetrics;
  final List<WorkflowApprovalSummary> pendingApprovals;
  final List<InventoryItem> inventoryAlerts;
  final List<AssignedTaskSummary> assignedTasks;
  final List<DailyActivityItem> dailyActivities;
  final List<ActivityTrendPoint> activityTrend;

  const ExecutiveDashboard({
    required this.role,
    required this.displayName,
    required this.unreadNotifications,
    required this.refreshedAt,
    this.revenueTrend = const [],
    this.revenueGrowthPercent,
    this.customerMetrics,
    this.appMetrics,
    this.inventoryMetrics,
    this.transactionMetrics,
    this.teamMetrics,
    this.pendingApprovals = const [],
    this.inventoryAlerts = const [],
    this.assignedTasks = const [],
    this.dailyActivities = const [],
    this.activityTrend = const [],
  });

  factory ExecutiveDashboard.fromJson(Map<String, dynamic> json) {
    return ExecutiveDashboard(
      role: json['role'] as String? ?? 'employee',
      displayName: json['display_name'] as String? ?? '',
      unreadNotifications: json['unread_notifications'] as int? ?? 0,
      refreshedAt: DateTime.parse(json['refreshed_at'] as String),
      revenueTrend:
          (json['revenue_trend'] as List<dynamic>?)
              ?.map(
                (e) => RevenueTrendPoint.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      revenueGrowthPercent: json['revenue_growth_percent'] != null
          ? _parseDecimal(json['revenue_growth_percent'])
          : null,
      customerMetrics: json['customer_metrics'] != null
          ? CustomerDashboardMetrics.fromJson(
              json['customer_metrics'] as Map<String, dynamic>,
            )
          : null,
      appMetrics: json['app_metrics'] != null
          ? AppDashboardMetrics.fromJson(
              json['app_metrics'] as Map<String, dynamic>,
            )
          : null,
      inventoryMetrics: json['inventory_metrics'] != null
          ? InventoryMetrics.fromJson(
              json['inventory_metrics'] as Map<String, dynamic>,
            )
          : null,
      transactionMetrics: json['transaction_metrics'] != null
          ? TransactionMetrics.fromJson(
              json['transaction_metrics'] as Map<String, dynamic>,
            )
          : null,
      teamMetrics: json['team_metrics'] != null
          ? TeamDashboardMetrics.fromJson(
              json['team_metrics'] as Map<String, dynamic>,
            )
          : null,
      pendingApprovals:
          (json['pending_approvals'] as List<dynamic>?)
              ?.map(
                (e) =>
                    WorkflowApprovalSummary.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      inventoryAlerts:
          (json['inventory_alerts'] as List<dynamic>?)
              ?.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      assignedTasks:
          (json['assigned_tasks'] as List<dynamic>?)
              ?.map(
                (e) => AssignedTaskSummary.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      dailyActivities:
          (json['daily_activities'] as List<dynamic>?)
              ?.map(
                (e) => DailyActivityItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      activityTrend:
          (json['activity_trend'] as List<dynamic>?)
              ?.map(
                (e) => ActivityTrendPoint.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}

double _parseDecimal(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
