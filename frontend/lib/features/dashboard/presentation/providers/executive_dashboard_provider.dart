import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';
import 'package:ags_gold/services/service_providers.dart';

const _refreshInterval = Duration(seconds: 30);

final executiveDashboardProvider =
    StreamProvider.autoDispose<ExecutiveDashboard>((ref) async* {
      final apiClient = ref.watch(apiClientProvider);
      final razorpayLive = ref.watch(razorpayLiveServiceProvider);

      var isFirst = true;
      while (true) {
        try {
          final response = await apiClient.get('/dashboard/executive');
          var dashboard = ExecutiveDashboard.fromJson(
            response.data as Map<String, dynamic>,
          );

          // Yield immediate backend data so user sees dashboard without delay
          yield dashboard;
          isFirst = false;

          // For Admin role: Synchronize with live Razorpay payments in background
          if (dashboard.role == 'admin') {
            try {
              final live = await razorpayLive.fetchLivePayments().timeout(
                const Duration(seconds: 8),
              );
              final updatedApp =
                  dashboard.appMetrics ??
                  const AppDashboardMetrics(
                    totalRevenue: 0,
                    monthlyRevenue: 0,
                    dailyRevenue: 0,
                    totalTransactions: 0,
                    monthlyTransactions: 0,
                    memberCount: 0,
                    membersNewThisMonth: 0,
                    metalInventoryValue: 0,
                    goldAvailableGrams: 0,
                    silverAvailableGrams: 0,
                  );

              final liveAppMetrics = AppDashboardMetrics(
                totalRevenue: live.totalRevenueInr,
                monthlyRevenue: live.totalRevenueInr,
                dailyRevenue: live.summary.todayCapturedRevenue,
                totalTransactions: live.totalCapturedCount,
                monthlyTransactions: live.totalCapturedCount,
                memberCount: updatedApp.memberCount,
                membersNewThisMonth: updatedApp.membersNewThisMonth,
                metalInventoryValue: updatedApp.metalInventoryValue,
                goldAvailableGrams: updatedApp.goldAvailableGrams,
                silverAvailableGrams: updatedApp.silverAvailableGrams,
                lowStockMetalCount: updatedApp.lowStockMetalCount,
                pendingSellRequests: updatedApp.pendingSellRequests,
                sellRequestsThisMonth: updatedApp.sellRequestsThisMonth,
              );

              dashboard = dashboard.copyWith(
                appMetrics: liveAppMetrics,
                paymentSummary: live.summary,
                recentPayments: _mergePaymentsWithBackendNames(
                  live.allPayments,
                  dashboard.recentPayments,
                ),
                customerSummaries: _mergeCustomersWithBackendNames(
                  live.customerSummaries,
                  dashboard.customerSummaries,
                ),
              );

              yield dashboard;
            } catch (_) {
              // If Razorpay live call fails or times out, keep backend data
            }
          }
        } catch (error) {
          if (isFirst) rethrow;
        }
        await Future<void>.delayed(_refreshInterval);
      }

    });

/// Merge live Razorpay data with backend-resolved customer names/methods.
/// Backend resolves names from User/Customer tables; live feed often has
/// null names, so preserve backend values when live is missing them.
String _normPhone(String? v) {
  if (v == null) return '';
  final digits = v.replaceAll(RegExp(r'\D'), '');
  if (digits.length > 10) return digits.substring(digits.length - 10);
  return digits;
}

/// Backend-first UNION merge for customer summaries.
/// Backend rows carry real names (resolved from users/customers tables via
/// user_id, even when payment_orders.customer_contact is blank). Live
/// Razorpay rows carry fresh totals keyed by contact phone. Result: every
/// backend customer keeps their name, enriched with live totals/methods;
/// live-only contacts appear as guests.
List<CustomerPaymentSummary> _mergeCustomersWithBackendNames(
  List<CustomerPaymentSummary> live,
  List<CustomerPaymentSummary> backend,
) {
  final merged = <String, CustomerPaymentSummary>{};
  final emailToKey = <String, String>{};

  String keyFor(String mobile, String? email) {
    final p = _normPhone(mobile);
    if (p.isNotEmpty) return 'p:$p';
    if (email?.isNotEmpty == true) {
      return 'e:${email!.trim().toLowerCase()}';
    }
    return 'm:$mobile';
  }

  // 1. Seed with backend (names authoritative).
  for (final b in backend) {
    final k = keyFor(b.mobile, b.email);
    merged[k] = b;
    if (b.email?.isNotEmpty == true) {
      emailToKey[b.email!.trim().toLowerCase()] = k;
    }
  }

  // 2. Fold live rows in (totals/methods authoritative).
  for (final c in live) {
    var k = keyFor(c.mobile, c.email);
    if (merged[k] == null &&
        c.email?.isNotEmpty == true &&
        emailToKey.containsKey(c.email!.trim().toLowerCase())) {
      k = emailToKey[c.email!.trim().toLowerCase()]!;
    }
    final base = merged[k];
    if (base == null) {
      merged[k] = c; // live-only guest, no backend name exists
    } else {
      final mergedMethods = <String>{
        ...base.paymentMethods,
        ...c.paymentMethods,
      }.toList();
      merged[k] = CustomerPaymentSummary(
        // Prefer a real phone-looking mobile for display/tap-to-filter.
        mobile: c.mobile.isNotEmpty ? c.mobile : base.mobile,
        name: (c.name?.isNotEmpty == true) ? c.name : base.name,
        email: (c.email?.isNotEmpty == true) ? c.email : base.email,
        // Live totals are fresher (direct from Razorpay).
        totalPaidInr: c.totalPaidInr != 0 ? c.totalPaidInr : base.totalPaidInr,
        successCount: c.successCount != 0 ? c.successCount : base.successCount,
        totalGrams: c.totalGrams != 0 ? c.totalGrams : base.totalGrams,
        goldGrams: c.goldGrams != 0 ? c.goldGrams : base.goldGrams,
        silverGrams: c.silverGrams != 0 ? c.silverGrams : base.silverGrams,
        paymentMethods: mergedMethods,
        payments: c.payments.isNotEmpty ? c.payments : base.payments,
      );
    }
  }

  final out = merged.values.toList()
    ..sort((a, b) => b.totalPaidInr.compareTo(a.totalPaidInr));
  return out;
}

List<AdminPaymentItem> _mergePaymentsWithBackendNames(
  List<AdminPaymentItem> live,
  List<AdminPaymentItem> backend,
) {
  final byPaymentId = <String, AdminPaymentItem>{};
  final byPhone = <String, AdminPaymentItem>{};
  for (final b in backend) {
    if (b.razorpayPaymentId?.isNotEmpty == true) {
      byPaymentId[b.razorpayPaymentId!] = b;
    }
    final p = _normPhone(b.customerMobile);
    if (p.isNotEmpty && !byPhone.containsKey(p)) byPhone[p] = b;
  }
  return live.map((p) {
    final match = (p.razorpayPaymentId != null
            ? byPaymentId[p.razorpayPaymentId!]
            : null) ??
        byPhone[_normPhone(p.customerMobile)];
    if (match == null) return p;
    return AdminPaymentItem(
      id: p.id,
      razorpayOrderId: p.razorpayOrderId,
      razorpayPaymentId: p.razorpayPaymentId,
      bankRrn: p.bankRrn ?? match.bankRrn,
      paymentMethod: (p.paymentMethod?.isNotEmpty == true)
          ? p.paymentMethod
          : match.paymentMethod,
      customerName: (p.customerName?.isNotEmpty == true)
          ? p.customerName
          : match.customerName,
      customerMobile: p.customerMobile ?? match.customerMobile,
      customerEmail: p.customerEmail ?? match.customerEmail,
      metal: p.metal,
      grams: p.grams,
      amountInr: p.amountInr,
      status: p.status,
      failureReason: p.failureReason,
      createdAt: p.createdAt,
      paidAt: p.paidAt,
      gstPercent: p.gstPercent ?? match.gstPercent,
      metalValueInr: p.metalValueInr ?? match.metalValueInr,
      gstAmountInr: p.gstAmountInr ?? match.gstAmountInr,
      razorpayFeeInr: p.razorpayFeeInr ?? match.razorpayFeeInr,
      merchantSettlementInr:
          p.merchantSettlementInr ?? match.merchantSettlementInr,
    );
  }).toList();
}

class RazorpaySyncNotifier extends Notifier<AsyncValue<Map<String, dynamic>?>> {
  @override
  AsyncValue<Map<String, dynamic>?> build() {
    return const AsyncValue.data(null);
  }

  Future<Map<String, dynamic>?> syncNow() async {
    state = const AsyncValue.loading();
    try {
      final apiClient = ref.read(apiClientProvider);
      final razorpayLive = ref.read(razorpayLiveServiceProvider);

      // 1. Fetch live directly from Razorpay
      final live = await razorpayLive.fetchLivePayments();

      // 2. Also notify backend to sync if backend is reachable
      try {
        await apiClient.post('/payments/razorpay/sync-all');
      } catch (_) {}

      final result = {
        'total_revenue': live.totalRevenueInr,
        'captured_count': live.totalCapturedCount,
        'failed_count': live.totalFailedCount,
        'customers_count': live.customerSummaries.length,
      };

      state = AsyncValue.data(result);
      ref.invalidate(executiveDashboardProvider);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final razorpaySyncProvider =
    NotifierProvider<
      RazorpaySyncNotifier,
      AsyncValue<Map<String, dynamic>?>
    >(RazorpaySyncNotifier.new);
