import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/audit_logs/domain/audit_log.dart';

const auditActionOptions = [
  'login_success',
  'login_failure',
  'logout',
  'user_create',
  'user_update',
  'user_delete',
  'role_assign',
  'role_remove',
  'permission_assign',
  'permission_remove',
  'profile_update',
  'password_change',
  'customer_create',
  'customer_update',
  'customer_delete',
];

const auditEntityOptions = ['User', 'Role', 'Customer'];

class AuditLogsSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final auditLogsSearchProvider =
    NotifierProvider<AuditLogsSearchNotifier, String>(
      AuditLogsSearchNotifier.new,
    );

class AuditLogsActionFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final auditLogsActionFilterProvider =
    NotifierProvider<AuditLogsActionFilterNotifier, String?>(
      AuditLogsActionFilterNotifier.new,
    );

class AuditLogsEntityFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final auditLogsEntityFilterProvider =
    NotifierProvider<AuditLogsEntityFilterNotifier, String?>(
      AuditLogsEntityFilterNotifier.new,
    );

class AuditDateRange {
  final DateTime start;
  final DateTime end;
  const AuditDateRange(this.start, this.end);
}

class AuditLogsDateRangeNotifier extends Notifier<AuditDateRange?> {
  @override
  AuditDateRange? build() => null;
  void update(AuditDateRange? value) => state = value;
}

final auditLogsDateRangeProvider =
    NotifierProvider<AuditLogsDateRangeNotifier, AuditDateRange?>(
      AuditLogsDateRangeNotifier.new,
    );

class AuditLogsSortNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void update(int value) => state = value;
}

final auditLogsSortProvider = NotifierProvider<AuditLogsSortNotifier, int>(
  AuditLogsSortNotifier.new,
);

class AuditLogsSortAscNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final auditLogsSortAscProvider =
    NotifierProvider<AuditLogsSortAscNotifier, bool>(
      AuditLogsSortAscNotifier.new,
    );

class AuditLogsSkipNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void update(int value) => state = value;
}

final auditLogsSkipProvider = NotifierProvider<AuditLogsSkipNotifier, int>(
  AuditLogsSkipNotifier.new,
);

class AuditLogsLimitNotifier extends Notifier<int> {
  @override
  int build() => 25;
  void update(int value) => state = value;
}

final auditLogsLimitProvider = NotifierProvider<AuditLogsLimitNotifier, int>(
  AuditLogsLimitNotifier.new,
);

class AuditLogsTimelineViewNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final auditLogsTimelineViewProvider =
    NotifierProvider<AuditLogsTimelineViewNotifier, bool>(
      AuditLogsTimelineViewNotifier.new,
    );

final auditLogsListProvider = FutureProvider.autoDispose<PaginatedAuditLogs>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final search = ref.watch(auditLogsSearchProvider);
  final action = ref.watch(auditLogsActionFilterProvider);
  final entityType = ref.watch(auditLogsEntityFilterProvider);
  final dateRange = ref.watch(auditLogsDateRangeProvider);
  final skip = ref.watch(auditLogsSkipProvider);
  final limit = ref.watch(auditLogsLimitProvider);

  final params = <String, dynamic>{'skip': skip, 'limit': limit};
  if (search.isNotEmpty) params['search'] = search;
  if (action != null) params['action'] = action;
  if (entityType != null) params['entity_type'] = entityType;
  if (dateRange != null) {
    params['start_date'] = dateRange.start.toUtc().toIso8601String();
    params['end_date'] = dateRange.end.toUtc().toIso8601String();
  }

  final response = await apiClient.get('/audit-logs/', queryParameters: params);
  return PaginatedAuditLogs.fromJson(response.data as Map<String, dynamic>);
});
