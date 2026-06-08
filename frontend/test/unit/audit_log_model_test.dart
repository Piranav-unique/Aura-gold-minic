import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/audit_logs/domain/audit_log.dart';

void main() {
  test('AuditLog.fromJson parses fields', () {
    final log = AuditLog.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'user_id': '22222222-2222-2222-2222-222222222222',
      'action': 'login_success',
      'entity_type': 'User',
      'entity_id': '22222222-2222-2222-2222-222222222222',
      'ip_address': '127.0.0.1',
      'timestamp': '2026-06-08T10:00:00Z',
      'metadata': {'email': 'test@example.com'},
    });

    expect(log.action, 'login_success');
    expect(log.ipAddress, '127.0.0.1');
    expect(log.metadata?['email'], 'test@example.com');
  });

  test('PaginatedAuditLogs.fromJson parses envelope', () {
    final page = PaginatedAuditLogs.fromJson({
      'items': [
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'action': 'logout',
          'timestamp': '2026-06-08T10:00:00Z',
        },
      ],
      'total': 1,
      'skip': 0,
      'limit': 25,
    });

    expect(page.total, 1);
    expect(page.items.length, 1);
    expect(page.items.first.action, 'logout');
  });
}
