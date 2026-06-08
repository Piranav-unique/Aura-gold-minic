class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String category;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.category,
    required this.isRead,
    required this.createdAt,
    this.metadata,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      category: json['category'] as String? ?? 'system',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class NotificationListResult {
  final List<AppNotification> items;
  final int total;
  final int unreadCount;
  final int skip;
  final int limit;

  const NotificationListResult({
    required this.items,
    required this.total,
    required this.unreadCount,
    required this.skip,
    required this.limit,
  });

  factory NotificationListResult.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationListResult(
      items: items,
      total: json['total'] as int? ?? items.length,
      unreadCount: json['unread_count'] as int? ?? 0,
      skip: json['skip'] as int? ?? 0,
      limit: json['limit'] as int? ?? items.length,
    );
  }
}
