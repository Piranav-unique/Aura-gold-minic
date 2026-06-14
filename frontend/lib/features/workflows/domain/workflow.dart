class WorkflowUserSummary {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;

  const WorkflowUserSummary({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
  });

  String get displayName {
    final parts = [
      firstName,
      lastName,
    ].whereType<String>().where((p) => p.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(' ');
    return email;
  }

  factory WorkflowUserSummary.fromJson(Map<String, dynamic> json) {
    return WorkflowUserSummary(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
    );
  }
}

class WorkflowHistoryEntry {
  final String id;
  final String action;
  final String? comment;
  final String? fromState;
  final String? toState;
  final int escalationLevel;
  final DateTime createdAt;
  final WorkflowUserSummary? actor;
  final WorkflowUserSummary? assignee;

  const WorkflowHistoryEntry({
    required this.id,
    required this.action,
    this.comment,
    this.fromState,
    this.toState,
    required this.escalationLevel,
    required this.createdAt,
    this.actor,
    this.assignee,
  });

  factory WorkflowHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WorkflowHistoryEntry(
      id: json['id'] as String,
      action: json['action'] as String? ?? '',
      comment: json['comment'] as String?,
      fromState: json['from_state'] as String?,
      toState: json['to_state'] as String?,
      escalationLevel: json['escalation_level'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      actor: json['actor'] != null
          ? WorkflowUserSummary.fromJson(json['actor'] as Map<String, dynamic>)
          : null,
      assignee: json['assignee'] != null
          ? WorkflowUserSummary.fromJson(
              json['assignee'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class WorkflowComment {
  final String id;
  final String body;
  final DateTime createdAt;
  final WorkflowUserSummary? author;

  const WorkflowComment({
    required this.id,
    required this.body,
    required this.createdAt,
    this.author,
  });

  factory WorkflowComment.fromJson(Map<String, dynamic> json) {
    return WorkflowComment(
      id: json['id'] as String,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      author: json['author'] != null
          ? WorkflowUserSummary.fromJson(json['author'] as Map<String, dynamic>)
          : null,
    );
  }
}

class WorkflowRequest {
  final String id;
  final String requestNumber;
  final String title;
  final String? description;
  final String requestType;
  final String state;
  final String requesterId;
  final WorkflowUserSummary? requester;
  final String? assigneeId;
  final WorkflowUserSummary? assignee;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic>? payload;
  final int escalationLevel;
  final DateTime? pendingSince;
  final DateTime? submittedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WorkflowHistoryEntry> history;
  final List<WorkflowComment> comments;

  const WorkflowRequest({
    required this.id,
    required this.requestNumber,
    required this.title,
    this.description,
    required this.requestType,
    required this.state,
    required this.requesterId,
    this.requester,
    this.assigneeId,
    this.assignee,
    this.entityType,
    this.entityId,
    this.payload,
    required this.escalationLevel,
    this.pendingSince,
    this.submittedAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.history = const [],
    this.comments = const [],
  });

  bool get isDraft => state == 'draft';
  bool get isPending => state == 'pending';
  bool get isTerminal => state == 'approved' || state == 'rejected';

  factory WorkflowRequest.fromJson(Map<String, dynamic> json) {
    return WorkflowRequest(
      id: json['id'] as String,
      requestNumber: json['request_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      requestType: json['request_type'] as String? ?? 'general',
      state: json['state'] as String? ?? 'draft',
      requesterId: json['requester_id'] as String,
      requester: json['requester'] != null
          ? WorkflowUserSummary.fromJson(
              json['requester'] as Map<String, dynamic>,
            )
          : null,
      assigneeId: json['assignee_id'] as String?,
      assignee: json['assignee'] != null
          ? WorkflowUserSummary.fromJson(
              json['assignee'] as Map<String, dynamic>,
            )
          : null,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
      escalationLevel: json['escalation_level'] as int? ?? 0,
      pendingSince: json['pending_since'] != null
          ? DateTime.parse(json['pending_since'] as String)
          : null,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      history:
          (json['history'] as List<dynamic>?)
              ?.map(
                (e) => WorkflowHistoryEntry.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((e) => WorkflowComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'title': title,
    if (description != null) 'description': description,
    'request_type': requestType,
    if (entityType != null) 'entity_type': entityType,
    if (entityId != null) 'entity_id': entityId,
    if (payload != null) 'payload': payload,
    if (assigneeId != null) 'assignee_id': assigneeId,
  };

  Map<String, dynamic> toUpdateJson() => {
    'title': title,
    if (description != null) 'description': description,
    'request_type': requestType,
    if (entityType != null) 'entity_type': entityType,
    if (entityId != null) 'entity_id': entityId,
    if (payload != null) 'payload': payload,
  };
}

class PaginatedWorkflowRequests {
  final List<WorkflowRequest> items;
  final int total;
  final int skip;
  final int limit;

  const PaginatedWorkflowRequests({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory PaginatedWorkflowRequests.fromJson(Map<String, dynamic> json) {
    final items =
        (json['items'] as List<dynamic>?)
            ?.map((e) => WorkflowRequest.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return PaginatedWorkflowRequests(
      items: items,
      total: json['total'] as int? ?? items.length,
      skip: json['skip'] as int? ?? 0,
      limit: json['limit'] as int? ?? items.length,
    );
  }
}

String workflowStateLabel(String state) {
  switch (state) {
    case 'draft':
      return 'Draft';
    case 'pending':
      return 'Pending';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    default:
      return state;
  }
}

String workflowTypeLabel(String type) {
  switch (type) {
    case 'general':
      return 'General';
    case 'transaction':
      return 'Transaction';
    case 'inventory':
      return 'Inventory';
    case 'customer':
      return 'Customer';
    default:
      return type;
  }
}

String workflowActionLabel(String action) {
  switch (action) {
    case 'created':
      return 'Created';
    case 'submitted':
      return 'Submitted';
    case 'assigned':
      return 'Assigned';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'escalated':
      return 'Escalated';
    default:
      return action;
  }
}
