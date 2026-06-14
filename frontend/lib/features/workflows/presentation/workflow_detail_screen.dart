import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/premium_timeline.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/workflows/domain/workflow.dart';
import 'package:ags_gold/features/workflows/presentation/providers/workflows_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

class WorkflowDetailScreen extends ConsumerWidget {
  final String requestId;

  const WorkflowDetailScreen({super.key, required this.requestId});

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    WorkflowRequest request, {
    required bool approve,
  }) async {
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve request' : 'Reject request'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(labelText: 'Comment (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (approve) {
        await ref.read(approveWorkflowProvider)(
          requestId,
          comment: commentController.text.trim().isEmpty
              ? null
              : commentController.text.trim(),
        );
      } else {
        await ref.read(rejectWorkflowProvider)(
          requestId,
          comment: commentController.text.trim().isEmpty
              ? null
              : commentController.text.trim(),
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Request approved' : 'Request rejected'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    }
  }

  Future<void> _addComment(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add comment'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Comment'),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (confirmed != true || controller.text.trim().isEmpty) return;

    try {
      await ref.read(addWorkflowCommentProvider)(
        requestId,
        controller.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comment added')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add comment: $e')));
      }
    }
  }

  Future<void> _submitDraft(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(submitWorkflowProvider)(requestId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted for approval')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
      }
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'escalated':
        return Icons.trending_up;
      case 'assigned':
        return Icons.person_outline;
      case 'submitted':
        return Icons.send_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'approved':
        return AppTheme.emerald;
      case 'rejected':
        return AppTheme.rose;
      case 'escalated':
        return Colors.orange;
      default:
        return AppTheme.sapphireBlue;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(workflowDetailProvider(requestId));
    final profile = ref.watch(profileProvider).value;
    final dateFormat = DateFormat('MMM d, yyyy • HH:mm');

    return ResponsiveNavigationWrapper(
      title: 'Workflow request',
      child: detailAsync.when(
        data: (request) {
          final canApprove =
              profile != null &&
              hasPermission(profile, 'workflow.approve') &&
              request.isPending &&
              request.assigneeId == profile.id;
          final canSubmit =
              profile != null &&
              hasPermission(profile, 'workflow.create') &&
              request.isDraft &&
              request.requesterId == profile.id;
          final canEdit = canSubmit;
          final canComment =
              profile != null && hasPermission(profile, 'workflow.view');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                request.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                request.requestNumber,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(workflowStateLabel(request.state))),
                  Chip(label: Text(workflowTypeLabel(request.requestType))),
                  if (request.escalationLevel > 0)
                    Chip(label: Text('Escalation L${request.escalationLevel}')),
                ],
              ),
              if (request.description != null) ...[
                const SizedBox(height: 16),
                Text(request.description!),
              ],
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requester'),
                subtitle: Text(request.requester?.displayName ?? '—'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Assignee'),
                subtitle: Text(request.assignee?.displayName ?? 'Unassigned'),
              ),
              if (request.submittedAt != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Submitted'),
                  subtitle: Text(dateFormat.format(request.submittedAt!)),
                ),
              const SizedBox(height: 16),
              if (canEdit)
                OutlinedButton.icon(
                  onPressed: () => context.push('/workflows/$requestId/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit draft'),
                ),
              if (canSubmit) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _submitDraft(context, ref),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Submit for approval'),
                ),
              ],
              if (canApprove) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _decide(context, ref, request, approve: true),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _decide(context, ref, request, approve: false),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 32),
              Text(
                'Approval history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              PremiumTimeline(
                entries: request.history
                    .map(
                      (h) => TimelineEntry(
                        title: workflowActionLabel(h.action),
                        subtitle: [
                          if (h.actor != null) h.actor!.displayName,
                          if (h.assignee != null)
                            '→ ${h.assignee!.displayName}',
                          if (h.comment != null && h.comment!.isNotEmpty)
                            h.comment!,
                        ].join(' • '),
                        timestamp: h.createdAt,
                        icon: _actionIcon(h.action),
                        color: _actionColor(h.action),
                      ),
                    )
                    .toList(),
              ),
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comments',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (canComment && !request.isTerminal)
                    TextButton.icon(
                      onPressed: () => _addComment(context, ref),
                      icon: const Icon(Icons.add_comment_outlined),
                      label: const Text('Add'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (request.comments.isEmpty)
                const Text('No comments yet.')
              else
                ...request.comments.map(
                  (c) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(c.body),
                      subtitle: Text(
                        '${c.author?.displayName ?? 'User'} • ${dateFormat.format(c.createdAt)}',
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const PremiumSkeleton(height: 400),
        error: (e, _) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Failed to load request',
          subtitle: '$e',
          actionLabel: 'Back',
          onAction: () => context.go('/workflows'),
        ),
      ),
    );
  }
}
