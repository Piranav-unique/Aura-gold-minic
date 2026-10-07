import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';
import 'package:ags_gold/services/service_providers.dart';

const _refreshInterval = Duration(seconds: 30);

final executiveDashboardProvider =
    StreamProvider.autoDispose<ExecutiveDashboard>((ref) async* {
      final apiClient = ref.watch(apiClientProvider);

      var isFirst = true;
      while (true) {
        try {
          final response = await apiClient.get('/dashboard/executive');
          final dashboard = ExecutiveDashboard.fromJson(
            response.data as Map<String, dynamic>,
          );

          yield dashboard;
          isFirst = false;
        } catch (error) {
          if (isFirst) rethrow;
        }
        await Future<void>.delayed(_refreshInterval);
      }
    });

/// Merge live Razorpay data with backend-resolved customer names/methods.
/// Backend resolves names from User/Customer tables; live feed often has
class RazorpaySyncNotifier extends Notifier<AsyncValue<Map<String, dynamic>?>> {
  @override
  AsyncValue<Map<String, dynamic>?> build() {
    return const AsyncValue.data(null);
  }

  Future<Map<String, dynamic>?> syncNow() async {
    state = const AsyncValue.loading();
    try {
      final apiClient = ref.read(apiClientProvider);

      // Notify backend to sync payment statuses for application orders
      final response = await apiClient.post('/payments/razorpay/sync-all');
      final result = response.data as Map<String, dynamic>?;

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
