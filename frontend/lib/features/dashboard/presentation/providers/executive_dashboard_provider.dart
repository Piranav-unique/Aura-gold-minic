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

          // For Admin role: Synchronize with live Razorpay payments
          if (dashboard.role == 'admin') {
            try {
              final live = await razorpayLive.fetchLivePayments();
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
                recentPayments: live.allPayments,
                customerSummaries: live.customerSummaries,
              );
            } catch (_) {
              // If Razorpay live call fails, keep backend data
            }
          }

          yield dashboard;
          isFirst = false;
        } catch (error) {
          if (isFirst) rethrow;
        }
        await Future<void>.delayed(_refreshInterval);
      }
    });

class RazorpaySyncNotifier
    extends Notifier<AsyncValue<Map<String, dynamic>?>> {
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
