class KpiCard {
  final String key;
  final String label;
  final String value;
  final String? trendLabel;
  final bool? trendPositive;

  const KpiCard({
    required this.key,
    required this.label,
    required this.value,
    this.trendLabel,
    this.trendPositive,
  });

  factory KpiCard.fromJson(Map<String, dynamic> json) {
    return KpiCard(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
      trendLabel: json['trend_label'] as String?,
      trendPositive: json['trend_positive'] as bool?,
    );
  }
}

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

class InventoryTrendPoint {
  final String label;
  final int netChange;
  final int movementCount;

  const InventoryTrendPoint({
    required this.label,
    required this.netChange,
    this.movementCount = 0,
  });

  factory InventoryTrendPoint.fromJson(Map<String, dynamic> json) {
    return InventoryTrendPoint(
      label: json['label'] as String? ?? '',
      netChange: json['net_change'] as int? ?? 0,
      movementCount: json['movement_count'] as int? ?? 0,
    );
  }
}

class AnalyticsOverview {
  final List<KpiCard> kpis;
  final List<RevenueTrendPoint> revenueTrend;
  final List<InventoryTrendPoint> inventoryTrend;
  final double? revenueGrowthPercent;
  final List<ActivityTrendPoint> activityTrend;

  const AnalyticsOverview({
    this.kpis = const [],
    this.revenueTrend = const [],
    this.inventoryTrend = const [],
    this.revenueGrowthPercent,
    this.activityTrend = const [],
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverview(
      kpis: (json['kpis'] as List<dynamic>? ?? [])
          .map((e) => KpiCard.fromJson(e as Map<String, dynamic>))
          .toList(),
      revenueTrend: (json['revenue_trend'] as List<dynamic>? ?? [])
          .map((e) => RevenueTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      inventoryTrend: (json['inventory_trend'] as List<dynamic>? ?? [])
          .map((e) => InventoryTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      revenueGrowthPercent: json['revenue_growth_percent'] != null
          ? _parseDecimal(json['revenue_growth_percent'])
          : null,
      activityTrend: (json['activity_trend'] as List<dynamic>? ?? [])
          .map((e) => ActivityTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ActivityTrendPoint {
  final String label;
  final int count;

  const ActivityTrendPoint({required this.label, required this.count});

  factory ActivityTrendPoint.fromJson(Map<String, dynamic> json) {
    return ActivityTrendPoint(
      label: json['label'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class RevenueReport {
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalRevenue;
  final int transactionCount;
  final double? revenueGrowthPercent;
  final List<RevenueTrendPoint> dailyTrend;
  final List<Map<String, dynamic>> topCustomers;

  const RevenueReport({
    required this.periodStart,
    required this.periodEnd,
    required this.totalRevenue,
    required this.transactionCount,
    this.revenueGrowthPercent,
    this.dailyTrend = const [],
    this.topCustomers = const [],
  });

  factory RevenueReport.fromJson(Map<String, dynamic> json) {
    return RevenueReport(
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      totalRevenue: _parseDecimal(json['total_revenue']),
      transactionCount: json['transaction_count'] as int? ?? 0,
      revenueGrowthPercent: json['revenue_growth_percent'] != null
          ? _parseDecimal(json['revenue_growth_percent'])
          : null,
      dailyTrend: (json['daily_trend'] as List<dynamic>? ?? [])
          .map((e) => RevenueTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      topCustomers: (json['top_customers'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }
}

class InventoryReport {
  final int totalStock;
  final double inventoryValue;
  final int lowStockCount;
  final int itemCount;
  final List<Map<String, dynamic>> byCategory;
  final List<InventoryTrendPoint> movementTrend;

  const InventoryReport({
    required this.totalStock,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.itemCount,
    this.byCategory = const [],
    this.movementTrend = const [],
  });

  factory InventoryReport.fromJson(Map<String, dynamic> json) {
    return InventoryReport(
      totalStock: json['total_stock'] as int? ?? 0,
      inventoryValue: _parseDecimal(json['inventory_value']),
      lowStockCount: json['low_stock_count'] as int? ?? 0,
      itemCount: json['item_count'] as int? ?? 0,
      byCategory: (json['by_category'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      movementTrend: (json['movement_trend'] as List<dynamic>? ?? [])
          .map((e) => InventoryTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomerReport {
  final int totalCustomers;
  final int activeCustomers;
  final double totalRevenue;
  final int totalPurchases;
  final List<Map<String, dynamic>> topCustomers;
  final List<Map<String, dynamic>> byType;

  const CustomerReport({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.totalRevenue,
    required this.totalPurchases,
    this.topCustomers = const [],
    this.byType = const [],
  });

  factory CustomerReport.fromJson(Map<String, dynamic> json) {
    return CustomerReport(
      totalCustomers: json['total_customers'] as int? ?? 0,
      activeCustomers: json['active_customers'] as int? ?? 0,
      totalRevenue: _parseDecimal(json['total_revenue']),
      totalPurchases: json['total_purchases'] as int? ?? 0,
      topCustomers: (json['top_customers'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      byType: (json['by_type'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }
}

class TransactionReport {
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int totalCount;
  final List<Map<String, dynamic>> breakdown;

  const TransactionReport({
    this.periodStart,
    this.periodEnd,
    required this.totalCount,
    this.breakdown = const [],
  });

  factory TransactionReport.fromJson(Map<String, dynamic> json) {
    return TransactionReport(
      periodStart: json['period_start'] != null
          ? DateTime.parse(json['period_start'] as String)
          : null,
      periodEnd: json['period_end'] != null
          ? DateTime.parse(json['period_end'] as String)
          : null,
      totalCount: json['total_count'] as int? ?? 0,
      breakdown: (json['breakdown'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }
}

class AuditReport {
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int totalEvents;
  final List<Map<String, dynamic>> breakdown;

  const AuditReport({
    this.periodStart,
    this.periodEnd,
    required this.totalEvents,
    this.breakdown = const [],
  });

  factory AuditReport.fromJson(Map<String, dynamic> json) {
    return AuditReport(
      periodStart: json['period_start'] != null
          ? DateTime.parse(json['period_start'] as String)
          : null,
      periodEnd: json['period_end'] != null
          ? DateTime.parse(json['period_end'] as String)
          : null,
      totalEvents: json['total_events'] as int? ?? 0,
      breakdown: (json['breakdown'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }
}

double _parseDecimal(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

const reportTypes = [
  ('revenue', 'Revenue Report', 'transaction.view'),
  ('inventory', 'Inventory Report', 'inventory.view'),
  ('customer', 'Customer Report', 'customer.view'),
  ('transaction', 'Transaction Report', 'transaction.view'),
  ('audit', 'Audit Report', 'audit.view'),
];

const exportFormats = ['csv', 'xlsx', 'pdf'];
