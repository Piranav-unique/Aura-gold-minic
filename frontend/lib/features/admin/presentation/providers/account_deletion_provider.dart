import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/admin/domain/account_deletion_request.dart';
import 'package:ags_gold/services/service_providers.dart';

final adminAccountDeletionsProvider = FutureProvider.autoDispose
    .family<List<AdminAccountDeletionRequest>, String?>((ref, status) async {
  final apiClient = ref.read(apiClientProvider);
  final queryParams = <String, dynamic>{
    'page': 1,
    'page_size': 100,
  };
  if (status != null && status.isNotEmpty && status != 'all') {
    queryParams['status'] = status;
  }

  final response = await apiClient.get(
    '/admin/account-deletion-requests',
    queryParameters: queryParams,
  );

  final data = response.data as Map<String, dynamic>;
  final items = data['items'] as List<dynamic>? ?? [];
  return items
      .map((e) => AdminAccountDeletionRequest.fromJson(e as Map<String, dynamic>))
      .toList();
});

final approveAccountDeletionProvider = Provider((ref) {
  return ({
    required String requestId,
    String? comment,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post(
      '/admin/account-deletion-requests/$requestId/approve',
      data: {
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
    return AdminAccountDeletionRequest.fromJson(
      response.data as Map<String, dynamic>,
    );
  };
});

final rejectAccountDeletionProvider = Provider((ref) {
  return ({
    required String requestId,
    required String comment,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post(
      '/admin/account-deletion-requests/$requestId/reject',
      data: {
        'comment': comment.trim(),
      },
    );
    return AdminAccountDeletionRequest.fromJson(
      response.data as Map<String, dynamic>,
    );
  };
});
