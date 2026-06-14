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
          yield ExecutiveDashboard.fromJson(
            response.data as Map<String, dynamic>,
          );
          isFirst = false;
        } catch (error) {
          if (isFirst) rethrow;
        }
        await Future<void>.delayed(_refreshInterval);
      }
    });
