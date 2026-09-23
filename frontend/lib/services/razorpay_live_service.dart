import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';

class RazorpayLiveData {
  final double totalRevenueInr;
  final int totalCapturedCount;
  final int totalFailedCount;
  final double totalFailedAmountInr;
  final List<AdminPaymentItem> allPayments;
  final List<CustomerPaymentSummary> customerSummaries;
  final AdminPaymentSummary summary;

  const RazorpayLiveData({
    required this.totalRevenueInr,
    required this.totalCapturedCount,
    required this.totalFailedCount,
    required this.totalFailedAmountInr,
    required this.allPayments,
    required this.customerSummaries,
    required this.summary,
  });
}

class RazorpayLiveService {
  static const String keyId = 'rzp_live_TeduS7UBp3zY8P';
  static const String keySecret = 'HcTCERztC9Y53fi7WEQEQBJz';

  final Dio _dio;

  RazorpayLiveService([Dio? dio]) : _dio = dio ?? Dio();

  Future<RazorpayLiveData> fetchLivePayments() async {
    final auth = 'Basic ${base64Encode(utf8.encode('$keyId:$keySecret'))}';
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.razorpay.com/v1/payments',
      queryParameters: {'count': 100},
      options: Options(
        headers: {'Authorization': auth},
        sendTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );

    final data = response.data;
    final items = (data?['items'] as List<dynamic>? ?? []);

    final payments = <AdminPaymentItem>[];
    double capturedTotal = 0.0;
    int capturedCount = 0;
    int failedCount = 0;
    double failedTotal = 0.0;

    final Map<String, List<AdminPaymentItem>> customerMap = {};

    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final status = raw['status'] as String? ?? 'created';
      final amountPaise = (raw['amount'] as num?)?.toInt() ?? 0;
      final amountInr = amountPaise / 100.0;
      final contact = raw['contact'] as String?;
      final email = raw['email'] as String?;
      final feePaise = (raw['fee'] as num?)?.toInt();
      final feeInr = feePaise != null ? feePaise / 100.0 : null;
      final taxPaise = (raw['tax'] as num?)?.toInt();
      final taxInr = taxPaise != null ? taxPaise / 100.0 : null;
      final rrn = raw['acquirer_data'] is Map
          ? raw['acquirer_data']['rrn']?.toString()
          : null;
      final failureReason = raw['error_description']?.toString() ??
          raw['error_reason']?.toString();
      final notes = raw['notes'] is Map
          ? raw['notes'] as Map<String, dynamic>
          : null;

      final createdAtSec = (raw['created_at'] as num?)?.toInt() ?? 0;
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        createdAtSec * 1000,
        isUtc: true,
      );

      final isCaptured = status == 'captured';
      final isFailed = status == 'failed';

      if (isCaptured) {
        capturedTotal += amountInr;
        capturedCount++;
      } else if (isFailed) {
        failedTotal += amountInr;
        failedCount++;
      }

      final gramsStr = notes?['grams']?.toString();
      final grams = (gramsStr != null ? double.tryParse(gramsStr) : null) ??
          (amountInr > 0 ? (amountInr / 9200.0) : 0.0);
      final metal = notes?['metal']?.toString() ?? 'gold';

      final item = AdminPaymentItem(
        id: raw['id'] as String? ?? '',
        razorpayOrderId: raw['order_id'] as String? ?? '',
        razorpayPaymentId: raw['id'] as String?,
        bankRrn: rrn,
        paymentMethod: raw['method'] as String? ?? 'upi',
        customerName: null,
        customerMobile: contact,
        customerEmail: email != 'void@razorpay.com' ? email : null,
        metal: metal,
        grams: grams,
        amountInr: amountInr,
        status: isCaptured ? 'captured' : status,
        failureReason: failureReason,
        createdAt: createdAt,
        paidAt: isCaptured ? createdAt : null,
        gstPercent: 3.0,
        gstAmountInr: taxInr ?? (amountInr * 0.03),
        razorpayFeeInr: feeInr,
        merchantSettlementInr: amountInr - (feeInr ?? (amountInr * 0.02)),
      );

      payments.add(item);

      final userKey = contact != null && contact.isNotEmpty
          ? contact
          : (email ?? 'Customer');
      customerMap.putIfAbsent(userKey, () => []).add(item);
    }

    final summaries = <CustomerPaymentSummary>[];
    customerMap.forEach((userKey, userPayments) {
      double userCapturedTotal = 0.0;
      int userCapturedCount = 0;
      double userGrams = 0.0;

      for (final p in userPayments) {
        if (p.status == 'captured' || p.status == 'paid') {
          userCapturedTotal += p.amountInr;
          userCapturedCount++;
          userGrams += p.grams;
        }
      }

      summaries.add(CustomerPaymentSummary(
        mobile: userKey,
        name: null,
        email: userPayments.first.customerEmail,
        totalPaidInr: userCapturedTotal,
        successCount: userCapturedCount,
        totalGrams: userGrams,
        payments: userPayments,
      ));
    });

    summaries.sort((a, b) => b.totalPaidInr.compareTo(a.totalPaidInr));

    final now = DateTime.now();
    final summary = AdminPaymentSummary(
      totalCapturedRevenue: capturedTotal,
      totalCapturedCount: capturedCount,
      totalPendingCount: 0,
      totalFailedCount: failedCount,
      todayCapturedRevenue: capturedTotal,
      todayCapturedCount: capturedCount,
      lastSyncedAt: now,
    );

    return RazorpayLiveData(
      totalRevenueInr: capturedTotal,
      totalCapturedCount: capturedCount,
      totalFailedCount: failedCount,
      totalFailedAmountInr: failedTotal,
      allPayments: payments,
      customerSummaries: summaries,
      summary: summary,
    );
  }
}
