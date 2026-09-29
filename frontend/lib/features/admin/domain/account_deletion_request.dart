class AdminAccountDeletionRequest {
  final String id;
  final String? userId;
  final String? userEmail;
  final String? userMobile;
  final String? userName;
  final String status;
  final String? reason;
  final double goldBalanceGrams;
  final double silverBalanceGrams;
  final String? reviewedById;
  final String? adminComment;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminAccountDeletionRequest({
    required this.id,
    this.userId,
    this.userEmail,
    this.userMobile,
    this.userName,
    required this.status,
    this.reason,
    required this.goldBalanceGrams,
    required this.silverBalanceGrams,
    this.reviewedById,
    this.adminComment,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminAccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    return AdminAccountDeletionRequest(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      userEmail: json['user_email'] as String?,
      userMobile: json['user_mobile'] as String?,
      userName: json['user_name'] as String?,
      status: json['status'] as String? ?? 'pending',
      reason: json['reason'] as String?,
      goldBalanceGrams: _parseDouble(json['gold_balance_grams']),
      silverBalanceGrams: _parseDouble(json['silver_balance_grams']),
      reviewedById: json['reviewed_by_id']?.toString(),
      adminComment: json['admin_comment'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}
