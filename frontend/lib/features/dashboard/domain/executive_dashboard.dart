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

class AdminPaymentItem {
  final String id;
  final String razorpayOrderId;
  final String? razorpayPaymentId;
  final String? bankRrn;
  final String? paymentMethod;
  final String? customerName;
  final String? customerMobile;
  final String? customerEmail;
  final String metal;
  final double grams;
  final double amountInr;
  final String status;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? paidAt;
  final double? gstPercent;
  final double? metalValueInr;
  final double? gstAmountInr;
  final double? razorpayFeeInr;
  final double? merchantSettlementInr;

  const AdminPaymentItem({
    required this.id,
    required this.razorpayOrderId,
    this.razorpayPaymentId,
    this.bankRrn,
    this.paymentMethod,
    this.customerName,
    this.customerMobile,
    this.customerEmail,
    required this.metal,
    required this.grams,
    required this.amountInr,
    required this.status,
    this.failureReason,
    required this.createdAt,
    this.paidAt,
    this.gstPercent,
    this.metalValueInr,
    this.gstAmountInr,
    this.razorpayFeeInr,
    this.merchantSettlementInr,
  });

  factory AdminPaymentItem.fromJson(Map<String, dynamic> json) {
    return AdminPaymentItem(
      id: json['id'] as String? ?? '',
      razorpayOrderId: json['razorpay_order_id'] as String? ?? '',
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      bankRrn: json['bank_rrn'] as String?,
      paymentMethod: json['payment_method'] as String?,
      customerName: json['customer_name'] as String?,
      customerMobile: json['customer_mobile'] as String?,
      customerEmail: json['customer_email'] as String?,
      metal: json['metal'] as String? ?? 'gold',
      grams: _parseDecimal(json['grams']),
      amountInr: _parseDecimal(json['amount_inr']),
      status: json['status'] as String? ?? 'created',
      failureReason: json['failure_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      gstPercent: json['gst_percent'] != null
          ? _parseDecimal(json['gst_percent'])
          : null,
      metalValueInr: json['metal_value_inr'] != null
          ? _parseDecimal(json['metal_value_inr'])
          : null,
      gstAmountInr: json['gst_amount_inr'] != null
          ? _parseDecimal(json['gst_amount_inr'])
          : null,
      razorpayFeeInr: json['razorpay_fee_inr'] != null
          ? _parseDecimal(json['razorpay_fee_inr'])
          : null,
      merchantSettlementInr: json['merchant_settlement_inr'] != null
          ? _parseDecimal(json['merchant_settlement_inr'])
          : null,
    );
  }
}

class AdminPaymentSummary {
  final double totalCapturedRevenue;
  final int totalCapturedCount;
  final int totalPendingCount;
  final int totalFailedCount;
  final double todayCapturedRevenue;
  final int todayCapturedCount;
  final DateTime? lastSyncedAt;

  const AdminPaymentSummary({
    required this.totalCapturedRevenue,
    required this.totalCapturedCount,
    required this.totalPendingCount,
    required this.totalFailedCount,
    required this.todayCapturedRevenue,
    required this.todayCapturedCount,
    this.lastSyncedAt,
  });

  factory AdminPaymentSummary.fromJson(Map<String, dynamic> json) {
    return AdminPaymentSummary(
      totalCapturedRevenue: _parseDecimal(json['total_captured_revenue']),
      totalCapturedCount: json['total_captured_count'] as int? ?? 0,
      totalPendingCount: json['total_pending_count'] as int? ?? 0,
      totalFailedCount: json['total_failed_count'] as int? ?? 0,
      todayCapturedRevenue: _parseDecimal(json['today_captured_revenue']),
      todayCapturedCount: json['today_captured_count'] as int? ?? 0,
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.parse(json['last_synced_at'] as String)
          : null,
    );
  }
}

class CustomerPaymentSummary {
  final String mobile;
  final String? name;
  final String? email;
  final double totalPaidInr;
  final int successCount;
  final double totalGrams;
  final List<AdminPaymentItem> payments;

  const CustomerPaymentSummary({
    required this.mobile,
    this.name,
    this.email,
    required this.totalPaidInr,
    required this.successCount,
    this.totalGrams = 0.0,
    this.payments = const [],
  });

  factory CustomerPaymentSummary.fromJson(Map<String, dynamic> json) {
    return CustomerPaymentSummary(
      mobile: json['mobile'] as String? ?? 'Unknown',
      name: json['name'] as String?,
      email: json['email'] as String?,
      totalPaidInr: _parseDecimal(json['total_paid_inr']),
      successCount: json['success_count'] as int? ?? 0,
      totalGrams: _parseDecimal(json['total_grams']),
      payments: (json['payments'] as List<dynamic>?)
              ?.map((e) => AdminPaymentItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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
  final List<AdminPaymentItem> recentPayments;
  final AdminPaymentSummary? paymentSummary;
  final List<CustomerPaymentSummary> customerSummaries;

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
    this.recentPayments = const [],
    this.paymentSummary,
    this.customerSummaries = const [],
  });

  ExecutiveDashboard copyWith({
    String? role,
    String? displayName,
    int? unreadNotifications,
    DateTime? refreshedAt,
    List<RevenueTrendPoint>? revenueTrend,
    double? revenueGrowthPercent,
    CustomerDashboardMetrics? customerMetrics,
    AppDashboardMetrics? appMetrics,
    InventoryMetrics? inventoryMetrics,
    TransactionMetrics? transactionMetrics,
    TeamDashboardMetrics? teamMetrics,
    List<WorkflowApprovalSummary>? pendingApprovals,
    List<InventoryItem>? inventoryAlerts,
    List<AssignedTaskSummary>? assignedTasks,
    List<DailyActivityItem>? dailyActivities,
    List<ActivityTrendPoint>? activityTrend,
    List<AdminPaymentItem>? recentPayments,
    AdminPaymentSummary? paymentSummary,
    List<CustomerPaymentSummary>? customerSummaries,
  }) {
    return ExecutiveDashboard(
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      refreshedAt: refreshedAt ?? this.refreshedAt,
      revenueTrend: revenueTrend ?? this.revenueTrend,
      revenueGrowthPercent: revenueGrowthPercent ?? this.revenueGrowthPercent,
      customerMetrics: customerMetrics ?? this.customerMetrics,
      appMetrics: appMetrics ?? this.appMetrics,
      inventoryMetrics: inventoryMetrics ?? this.inventoryMetrics,
      transactionMetrics: transactionMetrics ?? this.transactionMetrics,
      teamMetrics: teamMetrics ?? this.teamMetrics,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      inventoryAlerts: inventoryAlerts ?? this.inventoryAlerts,
      assignedTasks: assignedTasks ?? this.assignedTasks,
      dailyActivities: dailyActivities ?? this.dailyActivities,
      activityTrend: activityTrend ?? this.activityTrend,
      recentPayments: recentPayments ?? this.recentPayments,
      paymentSummary: paymentSummary ?? this.paymentSummary,
      customerSummaries: customerSummaries ?? this.customerSummaries,
    );
  }

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
      recentPayments:
          (json['recent_payments'] as List<dynamic>?)
              ?.map(
                (e) => AdminPaymentItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      paymentSummary: json['payment_summary'] != null
          ? AdminPaymentSummary.fromJson(
              json['payment_summary'] as Map<String, dynamic>,
            )
          : null,
      customerSummaries: (json['customer_summaries'] as List<dynamic>?)
              ?.map(
                (e) => CustomerPaymentSummary.fromJson(
                  e as Map<String, dynamic>,
                ),
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
