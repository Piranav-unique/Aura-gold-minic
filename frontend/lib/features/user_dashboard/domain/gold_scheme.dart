enum GoldSchemeStatus {
  notSelected('not_selected'),
  active('active'),
  completed('completed');

  const GoldSchemeStatus(this.value);
  final String value;

  static GoldSchemeStatus fromValue(String? raw) {
    return GoldSchemeStatus.values.firstWhere(
      (s) => s.value == raw,
      orElse: () => GoldSchemeStatus.notSelected,
    );
  }

  bool get isNotSelected => this == GoldSchemeStatus.notSelected;
  bool get isActive => this == GoldSchemeStatus.active;
  bool get isCompleted => this == GoldSchemeStatus.completed;
}

class GoldScheme {
  final GoldSchemeStatus status;
  final double? targetGrams;
  final double savedGrams;
  final double progressPercent;
  final bool canSell;
  final bool canSellInquiry;
  final String? sellLockedReason;
  final DateTime? startedAt;

  const GoldScheme({
    this.status = GoldSchemeStatus.notSelected,
    this.targetGrams,
    this.savedGrams = 0,
    this.progressPercent = 0,
    this.canSell = false,
    this.canSellInquiry = false,
    this.sellLockedReason,
    this.startedAt,
  });

  factory GoldScheme.fromJson(Map<String, dynamic> json) {
    return GoldScheme(
      status: GoldSchemeStatus.fromValue(json['status'] as String?),
      targetGrams: _parseNullable(json['target_grams']),
      savedGrams: _parseDecimal(json['saved_grams']),
      progressPercent: _parseDecimal(json['progress_percent']),
      canSell: json['can_sell'] as bool? ?? false,
      canSellInquiry: json['can_sell_inquiry'] as bool? ?? false,
      sellLockedReason: json['sell_locked_reason'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
    );
  }

  double get remainingGrams {
    final target = targetGrams;
    if (target == null) return 0;
    return (target - savedGrams).clamp(0, target);
  }
}

double _parseDecimal(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

double? _parseNullable(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
