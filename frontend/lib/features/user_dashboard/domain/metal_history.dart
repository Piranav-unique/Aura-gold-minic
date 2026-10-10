import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';

enum MetalHistoryRange {
  m1('1M', '1 Month'),
  m3('3M', '3 Months'),
  m6('6M', '6 Months'),
  y1('1Y', '1 Year'),
  y3('3Y', '3 Years');

  final String apiValue;
  final String label;
  const MetalHistoryRange(this.apiValue, this.label);

  static const List<MetalHistoryRange> selectable = [m1, m3, m6, y1];
}

class MetalHistory {
  final MetalType metal;
  final MetalHistoryRange range;
  final String unit;
  final double performancePercent;
  final List<MetalPricePoint> points;
  final DateTime refreshedAt;

  const MetalHistory({
    required this.metal,
    required this.range,
    required this.unit,
    required this.performancePercent,
    this.points = const [],
    required this.refreshedAt,
  });

  factory MetalHistory.fromJson(
    Map<String, dynamic> json,
    MetalType metal,
    MetalHistoryRange range,
  ) {
    return MetalHistory(
      metal: metal,
      range: range,
      unit: json['unit'] as String? ?? 'INR/gm',
      performancePercent: _parseDecimal(json['performance_percent']),
      points: (json['points'] as List<dynamic>? ?? [])
          .map((e) => MetalPricePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      refreshedAt: DateTime.parse(json['refreshed_at'] as String),
    );
  }

  bool get isUp => performancePercent >= 0;
}

double _parseDecimal(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
