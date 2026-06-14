import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/notifications/domain/notification.dart';

class NotificationCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final notificationCategoryFilterProvider =
    NotifierProvider<NotificationCategoryFilterNotifier, String?>(
      NotificationCategoryFilterNotifier.new,
    );

final notificationsListProvider =
    FutureProvider.autoDispose<NotificationListResult>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      final category = ref.watch(notificationCategoryFilterProvider);

      final params = <String, dynamic>{'skip': 0, 'limit': 50};
      if (category != null) params['category'] = category;

      final response = await apiClient.get(
        '/notifications/',
        queryParameters: params,
      );
      return NotificationListResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    });

final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/notifications/unread-count');
  final data = response.data as Map<String, dynamic>;
  return data['unread_count'] as int? ?? 0;
});

final markNotificationsReadProvider =
    Provider<Future<void> Function({List<String>? ids, bool markAll})>((ref) {
      return ({List<String>? ids, bool markAll = false}) async {
        final apiClient = ref.read(apiClientProvider);
        await apiClient.post(
          '/notifications/read',
          data: {'mark_all': markAll, 'notification_ids': ?ids},
        );
        ref.invalidate(notificationsListProvider);
        ref.invalidate(unreadNotificationsCountProvider);
      };
    });
