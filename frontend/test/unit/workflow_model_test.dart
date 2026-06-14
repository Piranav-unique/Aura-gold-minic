import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/workflows/domain/workflow.dart';

void main() {
  group('WorkflowRequest', () {
    test('fromJson parses detail with history and comments', () {
      final json = {
        'id': 'req-1',
        'request_number': 'WR-20260608-0001',
        'title': 'Discount approval',
        'description': '10% off',
        'request_type': 'general',
        'state': 'pending',
        'requester_id': 'user-1',
        'requester': {
          'id': 'user-1',
          'email': 'creator@test.com',
          'first_name': 'Jane',
          'last_name': 'Doe',
        },
        'assignee_id': 'user-2',
        'assignee': {'id': 'user-2', 'email': 'approver@test.com'},
        'escalation_level': 0,
        'created_at': '2026-06-08T10:00:00Z',
        'updated_at': '2026-06-08T10:00:00Z',
        'history': [
          {
            'id': 'h1',
            'action': 'created',
            'escalation_level': 0,
            'created_at': '2026-06-08T10:00:00Z',
          },
          {
            'id': 'h2',
            'action': 'submitted',
            'from_state': 'draft',
            'to_state': 'pending',
            'escalation_level': 0,
            'created_at': '2026-06-08T10:05:00Z',
          },
        ],
        'comments': [
          {
            'id': 'c1',
            'body': 'Please review',
            'created_at': '2026-06-08T10:06:00Z',
            'author': {'id': 'user-1', 'email': 'creator@test.com'},
          },
        ],
      };

      final request = WorkflowRequest.fromJson(json);

      expect(request.requestNumber, 'WR-20260608-0001');
      expect(request.isPending, isTrue);
      expect(request.requester?.displayName, 'Jane Doe');
      expect(request.history, hasLength(2));
      expect(request.comments.single.body, 'Please review');
    });

    test('toCreateJson includes optional fields', () {
      final request = WorkflowRequest(
        id: '',
        requestNumber: '',
        title: 'New request',
        description: 'Details',
        requestType: 'transaction',
        state: 'draft',
        requesterId: '',
        entityType: 'Transaction',
        entityId: 'txn-1',
        escalationLevel: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = request.toCreateJson();
      expect(json['title'], 'New request');
      expect(json['request_type'], 'transaction');
      expect(json['entity_type'], 'Transaction');
      expect(json['entity_id'], 'txn-1');
    });
  });

  test('workflowStateLabel returns readable labels', () {
    expect(workflowStateLabel('pending'), 'Pending');
    expect(workflowActionLabel('escalated'), 'Escalated');
  });
}
