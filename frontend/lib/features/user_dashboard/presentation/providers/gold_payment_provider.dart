import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';

class RazorpayOrderDetails {
  final String orderId;
  final String keyId;
  final int amountPaise;
  final String userEmail;
  final String userName;

  const RazorpayOrderDetails({
    required this.orderId,
    required this.keyId,
    required this.amountPaise,
    required this.userEmail,
    required this.userName,
  });

  factory RazorpayOrderDetails.fromJson(Map<String, dynamic> json) {
    return RazorpayOrderDetails(
      orderId: json['order_id'] as String,
      keyId: json['key_id'] as String,
      amountPaise: json['amount_paise'] as int,
      userEmail: json['user_email'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
    );
  }
}

class PaymentVerifyResult {
  final String status;
  final double goldSavingsGrams;
  final double gramsPurchased;
  final String message;

  const PaymentVerifyResult({
    required this.status,
    required this.goldSavingsGrams,
    required this.gramsPurchased,
    required this.message,
  });

  factory PaymentVerifyResult.fromJson(Map<String, dynamic> json) {
    return PaymentVerifyResult(
      status: json['status'] as String? ?? 'paid',
      goldSavingsGrams: _toDouble(json['gold_savings_grams']),
      gramsPurchased: _toDouble(json['grams_purchased']),
      message: json['message'] as String? ?? 'Payment successful.',
    );
  }
}

class PaymentSyncResult {
  final String status;
  final String message;
  final double? goldSavingsGrams;
  final double? gramsPurchased;

  const PaymentSyncResult({
    required this.status,
    required this.message,
    this.goldSavingsGrams,
    this.gramsPurchased,
  });

  factory PaymentSyncResult.fromJson(Map<String, dynamic> json) {
    return PaymentSyncResult(
      status: json['status'] as String? ?? 'pending',
      message: json['message'] as String? ?? '',
      goldSavingsGrams: json['gold_savings_grams'] == null
          ? null
          : _toDouble(json['gold_savings_grams']),
      gramsPurchased: json['grams_purchased'] == null
          ? null
          : _toDouble(json['grams_purchased']),
    );
  }

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

final goldPaymentProvider = Provider((ref) {
  final api = ref.watch(apiClientProvider);

  return ({
    required String metal,
    double? grams,
    double? amountInr,
  }) async {
    final response = await api.post(
      '/payments/razorpay/order',
      data: {
        'metal': metal,
        'grams': ?grams,
        'amount_inr': ?amountInr,
      },
    );
    return RazorpayOrderDetails.fromJson(response.data as Map<String, dynamic>);
  };
});

final verifyGoldPaymentProvider = Provider((ref) {
  final api = ref.watch(apiClientProvider);

  return ({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final response = await api.post(
      '/payments/razorpay/verify',
      data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
    );
    return PaymentVerifyResult.fromJson(response.data as Map<String, dynamic>);
  };
});

final syncGoldPaymentProvider = Provider((ref) {
  final api = ref.watch(apiClientProvider);

  return ({required String orderId}) async {
    final response = await api.post(
      '/payments/razorpay/sync',
      data: {'razorpay_order_id': orderId},
    );
    return PaymentSyncResult.fromJson(response.data as Map<String, dynamic>);
  };
});
