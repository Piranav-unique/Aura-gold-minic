import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/notifications/domain/notification.dart';

void main() {
  test('AppNotification.fromJson parses fields', () {
    final n = AppNotification.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'user_id': '22222222-2222-2222-2222-222222222222',
      'title': 'Alert',
      'message': 'Something happened',
      'category': 'security',
      'is_read': false,
      'created_at': '2026-06-08T10:00:00Z',
    });
    expect(n.category, 'security');
    expect(n.isRead, false);
  });

  test('NotificationListResult.fromJson parses envelope', () {
    final result = NotificationListResult.fromJson({
      'items': [],
      'total': 0,
      'unread_count': 3,
      'skip': 0,
      'limit': 50,
    });
    expect(result.unreadCount, 3);
  });
}
