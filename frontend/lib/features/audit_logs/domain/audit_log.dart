class AuditLog {
  final String id;
  final String? userId;
  final String action;
  final String? entityType;
  final String? entityId;
  final String? ipAddress;
  final String? userAgent;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const AuditLog({
    required this.id,
    this.userId,
    required this.action,
    this.entityType,
    this.entityId,
    this.ipAddress,
    this.userAgent,
    required this.timestamp,
    this.metadata,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      action: json['action'] as String? ?? '',
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class PaginatedAuditLogs {
  final List<AuditLog> items;
  final int total;
  final int skip;
  final int limit;

  const PaginatedAuditLogs({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory PaginatedAuditLogs.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedAuditLogs(
      items: items,
      total: json['total'] as int? ?? items.length,
      skip: json['skip'] as int? ?? 0,
      limit: json['limit'] as int? ?? items.length,
    );
  }
}
