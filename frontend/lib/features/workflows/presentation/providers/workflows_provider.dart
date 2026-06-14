import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/workflows/domain/workflow.dart';
import 'package:ags_gold/services/service_providers.dart';

class WorkflowsSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final workflowsSearchProvider =
    NotifierProvider<WorkflowsSearchNotifier, String>(
      WorkflowsSearchNotifier.new,
    );

class WorkflowsStateFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final workflowsStateFilterProvider =
    NotifierProvider<WorkflowsStateFilterNotifier, String?>(
      WorkflowsStateFilterNotifier.new,
    );

class WorkflowsTypeFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final workflowsTypeFilterProvider =
    NotifierProvider<WorkflowsTypeFilterNotifier, String?>(
      WorkflowsTypeFilterNotifier.new,
    );

class WorkflowsMineOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void update(bool value) => state = value;
}

final workflowsMineOnlyProvider =
    NotifierProvider<WorkflowsMineOnlyNotifier, bool>(
      WorkflowsMineOnlyNotifier.new,
    );

class WorkflowsSkipNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void update(int value) => state = value;
}

final workflowsSkipProvider = NotifierProvider<WorkflowsSkipNotifier, int>(
  WorkflowsSkipNotifier.new,
);

class WorkflowsLimitNotifier extends Notifier<int> {
  @override
  int build() => 25;
  void update(int value) => state = value;
}

final workflowsLimitProvider = NotifierProvider<WorkflowsLimitNotifier, int>(
  WorkflowsLimitNotifier.new,
);

final workflowsListProvider =
    FutureProvider.autoDispose<PaginatedWorkflowRequests>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      final search = ref.watch(workflowsSearchProvider);
      final state = ref.watch(workflowsStateFilterProvider);
      final requestType = ref.watch(workflowsTypeFilterProvider);
      final mineOnly = ref.watch(workflowsMineOnlyProvider);
      final skip = ref.watch(workflowsSkipProvider);
      final limit = ref.watch(workflowsLimitProvider);

      final params = <String, dynamic>{
        'skip': skip,
        'limit': limit,
        'sort_by': 'created_at',
        'sort_order': 'desc',
        if (mineOnly) 'mine_only': true,
      };
      if (search.isNotEmpty) params['search'] = search;
      if (state != null) params['state'] = state;
      if (requestType != null) params['request_type'] = requestType;

      final response = await apiClient.get(
        '/workflows/',
        queryParameters: params,
      );
      return PaginatedWorkflowRequests.fromJson(
        response.data as Map<String, dynamic>,
      );
    });

final myPendingApprovalsProvider =
    FutureProvider.autoDispose<PaginatedWorkflowRequests>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get('/workflows/pending/my');
      return PaginatedWorkflowRequests.fromJson(
        response.data as Map<String, dynamic>,
      );
    });

final workflowDetailProvider = FutureProvider.autoDispose
    .family<WorkflowRequest, String>((ref, id) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get('/workflows/$id');
      return WorkflowRequest.fromJson(response.data as Map<String, dynamic>);
    });

void _invalidateWorkflowLists(Ref ref, String? id) {
  ref.invalidate(workflowsListProvider);
  ref.invalidate(myPendingApprovalsProvider);
  if (id != null) ref.invalidate(workflowDetailProvider(id));
}

final createWorkflowProvider =
    Provider<Future<WorkflowRequest> Function(WorkflowRequest)>((ref) {
      return (WorkflowRequest request) async {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.post(
          '/workflows/',
          data: request.toCreateJson(),
        );
        _invalidateWorkflowLists(ref, null);
        return WorkflowRequest.fromJson(response.data as Map<String, dynamic>);
      };
    });

final updateWorkflowProvider =
    Provider<Future<WorkflowRequest> Function(WorkflowRequest)>((ref) {
      return (WorkflowRequest request) async {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.put(
          '/workflows/${request.id}',
          data: request.toUpdateJson(),
        );
        _invalidateWorkflowLists(ref, request.id);
        return WorkflowRequest.fromJson(response.data as Map<String, dynamic>);
      };
    });

final submitWorkflowProvider =
    Provider<Future<WorkflowRequest> Function(String, {String? comment})>((
      ref,
    ) {
      return (String id, {String? comment}) async {
        final apiClient = ref.read(apiClientProvider);
        final payload = <String, dynamic>{};
        if (comment != null) {
          payload['comment'] = comment;
        }
        final response = await apiClient.post(
          '/workflows/$id/submit',
          data: payload,
        );
        _invalidateWorkflowLists(ref, id);
        return WorkflowRequest.fromJson(response.data as Map<String, dynamic>);
      };
    });

final approveWorkflowProvider =
    Provider<Future<WorkflowRequest> Function(String, {String? comment})>((
      ref,
    ) {
      return (String id, {String? comment}) async {
        final apiClient = ref.read(apiClientProvider);
        final payload = <String, dynamic>{};
        if (comment != null) {
          payload['comment'] = comment;
        }
        final response = await apiClient.post(
          '/workflows/$id/approve',
          data: payload,
        );
        _invalidateWorkflowLists(ref, id);
        return WorkflowRequest.fromJson(response.data as Map<String, dynamic>);
      };
    });

final rejectWorkflowProvider =
    Provider<Future<WorkflowRequest> Function(String, {String? comment})>((
      ref,
    ) {
      return (String id, {String? comment}) async {
        final apiClient = ref.read(apiClientProvider);
        final payload = <String, dynamic>{};
        if (comment != null) {
          payload['comment'] = comment;
        }
        final response = await apiClient.post(
          '/workflows/$id/reject',
          data: payload,
        );
        _invalidateWorkflowLists(ref, id);
        return WorkflowRequest.fromJson(response.data as Map<String, dynamic>);
      };
    });

final addWorkflowCommentProvider =
    Provider<Future<WorkflowRequest> Function(String, String)>((ref) {
      return (String id, String body) async {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.post(
          '/workflows/$id/comments',
          data: {'body': body},
        );
        _invalidateWorkflowLists(ref, id);
        return WorkflowRequest.fromJson(response.data as Map<String, dynamic>);
      };
    });
