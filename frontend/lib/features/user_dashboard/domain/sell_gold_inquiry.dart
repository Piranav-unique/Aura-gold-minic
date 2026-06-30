class SellGoldInquiry {
  final String id;
  final String name;
  final String mobileNumber;
  final double? quantityGrams;
  final String message;
  final String status;
  final String? adminResponse;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final double? netPayableInr;
  final String? referenceNumber;
  final String? rejectionReason;
  final String? razorpayPayoutId;
  final String? payoutStatus;
  final String? payoutFailureReason;

  const SellGoldInquiry({
    required this.id,
    required this.name,
    required this.mobileNumber,
    this.quantityGrams,
    required this.message,
    required this.status,
    this.adminResponse,
    required this.createdAt,
    this.respondedAt,
    this.netPayableInr,
    this.referenceNumber,
    this.rejectionReason,
    this.razorpayPayoutId,
    this.payoutStatus,
    this.payoutFailureReason,
  });

  factory SellGoldInquiry.fromJson(Map<String, dynamic> json) {
    return SellGoldInquiry(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String? ?? '',
      quantityGrams: _parseDouble(json['quantity_grams']),
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      adminResponse: json['admin_response'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      netPayableInr: _parseDouble(json['net_payable_inr']),
      referenceNumber: json['reference_number'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      razorpayPayoutId: json['razorpay_payout_id'] as String?,
      payoutStatus: json['payout_status'] as String?,
      payoutFailureReason: json['payout_failure_reason'] as String?,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class AdminSellGoldInquiry extends SellGoldInquiry {
  final String userId;
  final String? userEmail;
  final double? goldBalanceGrams;
  final String? goldSchemeStatus;
  final String? kycStatus;

  const AdminSellGoldInquiry({
    required super.id,
    required this.userId,
    required super.name,
    required super.mobileNumber,
    super.quantityGrams,
    required super.message,
    required super.status,
    super.adminResponse,
    required super.createdAt,
    super.respondedAt,
    super.netPayableInr,
    super.referenceNumber,
    super.rejectionReason,
    super.razorpayPayoutId,
    super.payoutStatus,
    super.payoutFailureReason,
    this.userEmail,
    this.goldBalanceGrams,
    this.goldSchemeStatus,
    this.kycStatus,
  });

  factory AdminSellGoldInquiry.fromJson(Map<String, dynamic> json) {
    return AdminSellGoldInquiry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String? ?? '',
      quantityGrams: SellGoldInquiry._parseDouble(json['quantity_grams']),
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      adminResponse: json['admin_response'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      netPayableInr: SellGoldInquiry._parseDouble(json['net_payable_inr']),
      referenceNumber: json['reference_number'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      razorpayPayoutId: json['razorpay_payout_id'] as String?,
      payoutStatus: json['payout_status'] as String?,
      payoutFailureReason: json['payout_failure_reason'] as String?,
      userEmail: json['user_email'] as String?,
      goldBalanceGrams: SellGoldInquiry._parseDouble(json['gold_balance_grams']),
      goldSchemeStatus: json['gold_scheme_status'] as String?,
      kycStatus: json['kyc_status'] as String?,
    );
  }
}

class SellPayoutBreakdown {
  final double sellRatePerGram;
  final double quantityGrams;
  final double grossAmountInr;
  final double platformChargeInr;
  final double taxAmountInr;
  final double netPayableInr;

  const SellPayoutBreakdown({
    required this.sellRatePerGram,
    required this.quantityGrams,
    required this.grossAmountInr,
    required this.platformChargeInr,
    required this.taxAmountInr,
    required this.netPayableInr,
  });

  factory SellPayoutBreakdown.fromJson(Map<String, dynamic> json) {
    double d(String key) => SellGoldInquiry._parseDouble(json[key]) ?? 0;
    return SellPayoutBreakdown(
      sellRatePerGram: d('sell_rate_per_gram'),
      quantityGrams: d('quantity_grams'),
      grossAmountInr: d('gross_amount_inr'),
      platformChargeInr: d('platform_charge_inr'),
      taxAmountInr: d('tax_amount_inr'),
      netPayableInr: d('net_payable_inr'),
    );
  }
}

class SellInquiryDetail extends AdminSellGoldInquiry {
  final String? kycAadhaarLast4;
  final String? kycPanLast4;
  final double silverBalanceGrams;
  final double goldInvestedInr;
  final double? goldSchemeTargetGrams;
  final DateTime? goldSchemeStartedAt;
  final bool schemeCompleted;
  final String? schemeWarning;
  final SellPayoutBreakdown? payout;
  final String? userPaymentMethod;
  final String? userPaymentDestination;

  const SellInquiryDetail({
    required super.id,
    required super.userId,
    required super.name,
    required super.mobileNumber,
    super.quantityGrams,
    required super.message,
    required super.status,
    super.adminResponse,
    required super.createdAt,
    super.respondedAt,
    super.netPayableInr,
    super.referenceNumber,
    super.rejectionReason,
    super.razorpayPayoutId,
    super.payoutStatus,
    super.payoutFailureReason,
    super.userEmail,
    super.goldBalanceGrams,
    super.goldSchemeStatus,
    super.kycStatus,
    this.kycAadhaarLast4,
    this.kycPanLast4,
    this.silverBalanceGrams = 0,
    this.goldInvestedInr = 0,
    this.goldSchemeTargetGrams,
    this.goldSchemeStartedAt,
    this.schemeCompleted = false,
    this.schemeWarning,
    this.payout,
    this.userPaymentMethod,
    this.userPaymentDestination,
  });

  factory SellInquiryDetail.fromJson(Map<String, dynamic> json) {
    return SellInquiryDetail(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String? ?? '',
      quantityGrams: SellGoldInquiry._parseDouble(json['quantity_grams']),
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      adminResponse: json['admin_response'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      netPayableInr: SellGoldInquiry._parseDouble(json['net_payable_inr']),
      referenceNumber: json['reference_number'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      razorpayPayoutId: json['razorpay_payout_id'] as String?,
      payoutStatus: json['payout_status'] as String?,
      payoutFailureReason: json['payout_failure_reason'] as String?,
      userEmail: json['user_email'] as String?,
      goldBalanceGrams: SellGoldInquiry._parseDouble(json['gold_balance_grams']),
      goldSchemeStatus: json['gold_scheme_status'] as String?,
      kycStatus: json['kyc_status'] as String?,
      kycAadhaarLast4: json['kyc_aadhaar_last4'] as String?,
      kycPanLast4: json['kyc_pan_last4'] as String?,
      silverBalanceGrams:
          SellGoldInquiry._parseDouble(json['silver_balance_grams']) ?? 0,
      goldInvestedInr:
          SellGoldInquiry._parseDouble(json['gold_invested_inr']) ?? 0,
      goldSchemeTargetGrams:
          SellGoldInquiry._parseDouble(json['gold_scheme_target_grams']),
      goldSchemeStartedAt: json['gold_scheme_started_at'] != null
          ? DateTime.parse(json['gold_scheme_started_at'] as String)
          : null,
      schemeCompleted: json['scheme_completed'] as bool? ?? false,
      schemeWarning: json['scheme_warning'] as String?,
      payout: json['payout'] != null
          ? SellPayoutBreakdown.fromJson(
              json['payout'] as Map<String, dynamic>,
            )
          : null,
      userPaymentMethod: json['user_payment_method'] as String?,
      userPaymentDestination: json['user_payment_destination'] as String?,
    );
  }
}
