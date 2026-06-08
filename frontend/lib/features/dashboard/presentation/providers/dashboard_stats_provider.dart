import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/dashboard/domain/dashboard_stats.dart';

final dashboardStatsProvider =
    FutureProvider.autoDispose<DashboardStats>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/dashboard/stats');
  return DashboardStats.fromJson(response.data as Map<String, dynamic>);
});
