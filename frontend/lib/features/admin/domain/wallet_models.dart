double parseWalletDecimal(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

class WalletUserSearchItem {
  final String id;
  final String fullName;
  final String email;
  final String? mobileNumber;
  final String kycStatus;
  final String? kycAadhaarLast4;
  final String? kycPanLast4;
  final bool isActive;
  final double goldBalanceGrams;
  final double silverBalanceGrams;
  final double walletBalanceInr;
  final DateTime createdAt;

  const WalletUserSearchItem({
    required this.id,
    required this.fullName,
    required this.email,
    this.mobileNumber,
    required this.kycStatus,
    this.kycAadhaarLast4,
    this.kycPanLast4,
    required this.isActive,
    required this.goldBalanceGrams,
    required this.silverBalanceGrams,
    required this.walletBalanceInr,
    required this.createdAt,
  });

  factory WalletUserSearchItem.fromJson(Map<String, dynamic> json) {
    return WalletUserSearchItem(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String?,
      kycStatus: json['kyc_status'] as String? ?? 'not_started',
      kycAadhaarLast4: json['kyc_aadhaar_last4'] as String?,
      kycPanLast4: json['kyc_pan_last4'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      goldBalanceGrams: parseWalletDecimal(json['gold_balance_grams']),
      silverBalanceGrams: parseWalletDecimal(json['silver_balance_grams']),
      walletBalanceInr: parseWalletDecimal(json['wallet_balance_inr']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class WalletSummary {
  final double goldBalanceGrams;
  final double silverBalanceGrams;
  final double totalInrInvested;
  final double totalBoughtGrams;
  final double totalSoldGrams;
  final int pendingSellInquiries;
  final double referralRewardInr;
  final double referralRewardGrams;
  final double? savingsSchemeTargetGrams;
  final String savingsSchemeStatus;
  final double walletBalanceInr;

  const WalletSummary({
    required this.goldBalanceGrams,
    required this.silverBalanceGrams,
    required this.totalInrInvested,
    required this.totalBoughtGrams,
    required this.totalSoldGrams,
    required this.pendingSellInquiries,
    required this.referralRewardInr,
    required this.referralRewardGrams,
    this.savingsSchemeTargetGrams,
    required this.savingsSchemeStatus,
    required this.walletBalanceInr,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      goldBalanceGrams: parseWalletDecimal(json['gold_balance_grams']),
      silverBalanceGrams: parseWalletDecimal(json['silver_balance_grams']),
      totalInrInvested: parseWalletDecimal(json['total_inr_invested']),
      totalBoughtGrams: parseWalletDecimal(json['total_bought_grams']),
      totalSoldGrams: parseWalletDecimal(json['total_sold_grams']),
      pendingSellInquiries: json['pending_sell_inquiries'] as int? ?? 0,
      referralRewardInr: parseWalletDecimal(json['referral_reward_inr']),
      referralRewardGrams: parseWalletDecimal(json['referral_reward_grams']),
      savingsSchemeTargetGrams: json['savings_scheme_target_grams'] != null
          ? parseWalletDecimal(json['savings_scheme_target_grams'])
          : null,
      savingsSchemeStatus:
          json['savings_scheme_status'] as String? ?? 'not_selected',
      walletBalanceInr: parseWalletDecimal(json['wallet_balance_inr']),
    );
  }
}

class WalletUserDetail {
  final String id;
  final String fullName;
  final String email;
  final String? mobileNumber;
  final String kycStatus;
  final String? kycAadhaarLast4;
  final String? kycPanLast4;
  final DateTime createdAt;
  final bool isActive;
  final WalletSummary wallet;

  const WalletUserDetail({
    required this.id,
    required this.fullName,
    required this.email,
    this.mobileNumber,
    required this.kycStatus,
    this.kycAadhaarLast4,
    this.kycPanLast4,
    required this.createdAt,
    required this.isActive,
    required this.wallet,
  });

  factory WalletUserDetail.fromJson(Map<String, dynamic> json) {
    return WalletUserDetail(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String?,
      kycStatus: json['kyc_status'] as String? ?? 'not_started',
      kycAadhaarLast4: json['kyc_aadhaar_last4'] as String?,
      kycPanLast4: json['kyc_pan_last4'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
      wallet: WalletSummary.fromJson(
        json['wallet'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class WalletTransactionItem {
  final String id;
  final String userId;
  final String? userName;
  final String? userMobile;
  final DateTime occurredAt;
  final String transactionType;
  final String? metal;
  final double? quantityGrams;
  final double? amountInr;
  final String status;
  final String? referenceId;

  const WalletTransactionItem({
    required this.id,
    required this.userId,
    this.userName,
    this.userMobile,
    required this.occurredAt,
    required this.transactionType,
    this.metal,
    this.quantityGrams,
    this.amountInr,
    required this.status,
    this.referenceId,
  });

  factory WalletTransactionItem.fromJson(Map<String, dynamic> json) {
    return WalletTransactionItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      userMobile: json['user_mobile'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      transactionType: json['transaction_type'] as String? ?? '',
      metal: json['metal'] as String?,
      quantityGrams: json['quantity_grams'] != null
          ? parseWalletDecimal(json['quantity_grams'])
          : null,
      amountInr: json['amount_inr'] != null
          ? parseWalletDecimal(json['amount_inr'])
          : null,
      status: json['status'] as String? ?? '',
      referenceId: json['reference_id'] as String?,
    );
  }
}

class WalletStatusHistoryItem {
  final String status;
  final DateTime occurredAt;
  final String? note;

  const WalletStatusHistoryItem({
    required this.status,
    required this.occurredAt,
    this.note,
  });

  factory WalletStatusHistoryItem.fromJson(Map<String, dynamic> json) {
    return WalletStatusHistoryItem(
      status: json['status'] as String? ?? '',
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      note: json['note'] as String?,
    );
  }
}

class WalletTransactionDetail {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? userMobile;
  final DateTime occurredAt;
  final String transactionType;
  final String? metal;
  final double? quantityGrams;
  final double? amountInr;
  final double? ratePerGram;
  final double? gstAmountInr;
  final double? platformFeeInr;
  final double? totalAmountInr;
  final String status;
  final String? referenceId;
  final Map<String, dynamic>? paymentDetails;
  final Map<String, dynamic>? sellDetails;
  final Map<String, dynamic>? referralDetails;
  final Map<String, dynamic>? savingsDetails;
  final List<WalletStatusHistoryItem> statusHistory;
  final String? adminNotes;

  const WalletTransactionDetail({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userMobile,
    required this.occurredAt,
    required this.transactionType,
    this.metal,
    this.quantityGrams,
    this.amountInr,
    this.ratePerGram,
    this.gstAmountInr,
    this.platformFeeInr,
    this.totalAmountInr,
    required this.status,
    this.referenceId,
    this.paymentDetails,
    this.sellDetails,
    this.referralDetails,
    this.savingsDetails,
    this.statusHistory = const [],
    this.adminNotes,
  });

  factory WalletTransactionDetail.fromJson(Map<String, dynamic> json) {
    final history = json['status_history'] as List<dynamic>? ?? [];
    return WalletTransactionDetail(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? '',
      userEmail: json['user_email'] as String? ?? '',
      userMobile: json['user_mobile'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      transactionType: json['transaction_type'] as String? ?? '',
      metal: json['metal'] as String?,
      quantityGrams: json['quantity_grams'] != null
          ? parseWalletDecimal(json['quantity_grams'])
          : null,
      amountInr: json['amount_inr'] != null
          ? parseWalletDecimal(json['amount_inr'])
          : null,
      ratePerGram: json['rate_per_gram'] != null
          ? parseWalletDecimal(json['rate_per_gram'])
          : null,
      gstAmountInr: json['gst_amount_inr'] != null
          ? parseWalletDecimal(json['gst_amount_inr'])
          : null,
      platformFeeInr: json['platform_fee_inr'] != null
          ? parseWalletDecimal(json['platform_fee_inr'])
          : null,
      totalAmountInr: json['total_amount_inr'] != null
          ? parseWalletDecimal(json['total_amount_inr'])
          : null,
      status: json['status'] as String? ?? '',
      referenceId: json['reference_id'] as String?,
      paymentDetails: json['payment_details'] as Map<String, dynamic>?,
      sellDetails: json['sell_details'] as Map<String, dynamic>?,
      referralDetails: json['referral_details'] as Map<String, dynamic>?,
      savingsDetails: json['savings_details'] as Map<String, dynamic>?,
      statusHistory: history
          .map(
            (e) => WalletStatusHistoryItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      adminNotes: json['admin_notes'] as String?,
    );
  }
}
