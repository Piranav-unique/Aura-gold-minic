import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/domain/account_deletion_request.dart';
import 'package:ags_gold/features/admin/presentation/providers/account_deletion_provider.dart';
import 'package:ags_gold/services/api_client.dart';

class AccountDeletionRequestsScreen extends ConsumerStatefulWidget {
  const AccountDeletionRequestsScreen({super.key});

  @override
  ConsumerState<AccountDeletionRequestsScreen> createState() =>
      _AccountDeletionRequestsScreenState();
}

class _AccountDeletionRequestsScreenState
    extends ConsumerState<AccountDeletionRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _tabs = const [
    Tab(text: 'Pending'),
    Tab(text: 'Approved'),
    Tab(text: 'Rejected'),
    Tab(text: 'All'),
  ];

  final _statuses = ['pending', 'approved', 'rejected', 'all'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return AppTheme.rose;
      case 'rejected':
        return Colors.blueGrey;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved & Purged';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled by User';
      default:
        return status;
    }
  }

  Future<void> _showApproveDialog(
    BuildContext context,
    AdminAccountDeletionRequest request,
  ) async {
    final commentController = TextEditingController();
    var submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.rose,
            size: 40,
          ),
          title: const Text('Approve Account Deletion?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.rose.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Permanent Action: Approving will immediately and irreversibly purge all personal data, KYC documents, bank links, and credentials for this customer from the database.',
                  style: TextStyle(
                    color: AppTheme.rose,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Requester: ${request.userName ?? 'Customer'}\n'
                'Email: ${request.userEmail ?? 'N/A'}\n'
                'Phone: ${request.userMobile ?? 'N/A'}',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Admin Note / Comment (Optional)',
                  hintText: 'e.g., Verified by admin, user confirmed',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.rose,
                foregroundColor: Colors.white,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      try {
                        final approve = ref.read(approveAccountDeletionProvider);
                        await approve(
                          requestId: request.id,
                          comment: commentController.text,
                        );
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        ref.invalidate(adminAccountDeletionsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Account deletion approved. User data permanently purged.',
                              ),
                              backgroundColor: AppTheme.emerald,
                            ),
                          );
                        }
                      } on ApiException catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                              backgroundColor: AppTheme.rose,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to approve request: $e'),
                              backgroundColor: AppTheme.rose,
                            ),
                          );
                        }
                      }
                    },
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(submitting ? 'Purging...' : 'Approve & Purge Data'),
            ),
          ],
        ),
      ),
    );
    commentController.dispose();
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    AdminAccountDeletionRequest request,
  ) async {
    final commentController = TextEditingController();
    var submitting = false;
    String? validationError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reject Deletion Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reject deletion request for ${request.userName ?? request.userEmail ?? 'Customer'}. The user account will remain active.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  labelText: 'Rejection Reason / Note *',
                  hintText: 'e.g., Active gold balance detected or pending KYC audit',
                  border: const OutlineInputBorder(),
                  errorText: validationError,
                ),
                maxLines: 3,
                onChanged: (_) {
                  if (validationError != null) {
                    setDialogState(() => validationError = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (commentController.text.trim().isEmpty) {
                        setDialogState(
                          () => validationError = 'Rejection reason is required',
                        );
                        return;
                      }

                      setDialogState(() => submitting = true);
                      try {
                        final reject = ref.read(rejectAccountDeletionProvider);
                        await reject(
                          requestId: request.id,
                          comment: commentController.text,
                        );
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        ref.invalidate(adminAccountDeletionsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account deletion request rejected.'),
                              backgroundColor: Colors.blueGrey,
                            ),
                          );
                        }
                      } on ApiException catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                              backgroundColor: AppTheme.rose,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to reject request: $e'),
                              backgroundColor: AppTheme.rose,
                            ),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Reject Request'),
            ),
          ],
        ),
      ),
    );
    commentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return ResponsiveNavigationWrapper(
      title: 'Account Deletions',
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review customer account deletion requests, verify wallet balance, and decide incoming purge requests.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              tabs: _tabs,
              labelColor: Theme.of(context).colorScheme.primary,
              indicatorColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _statuses.map((statusKey) {
                  return _AccountDeletionListTab(
                    status: statusKey,
                    statusColor: _statusColor,
                    statusLabel: _statusLabel,
                    onApprove: (req) => _showApproveDialog(context, req),
                    onReject: (req) => _showRejectDialog(context, req),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDeletionListTab extends ConsumerWidget {
  final String status;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final void Function(AdminAccountDeletionRequest) onApprove;
  final void Function(AdminAccountDeletionRequest) onReject;

  const _AccountDeletionListTab({
    required this.status,
    required this.statusColor,
    required this.statusLabel,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(adminAccountDeletionsProvider(status));
    final dateFormat = DateFormat('MMM d, yyyy · hh:mm a');

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error loading requests: $err'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(adminAccountDeletionsProvider(status)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.person_remove_outlined,
            title: 'No ${status == 'all' ? '' : status} requests',
            subtitle: status == 'pending'
                ? 'No pending account deletion requests requiring approval.'
                : 'Account deletion requests will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminAccountDeletionsProvider(status));
            await ref.read(adminAccountDeletionsProvider(status).future);
          },
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final isPending = item.status.toLowerCase() == 'pending';

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.15),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                statusColor(item.status).withValues(alpha: 0.15),
                            child: Icon(
                              Icons.person_outline,
                              color: statusColor(item.status),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.userName ?? 'Customer',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.userEmail ?? 'No email'} · ${item.userMobile ?? 'No phone'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor(item.status)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: statusColor(item.status)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              statusLabel(item.status),
                              style: TextStyle(
                                color: statusColor(item.status),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Requested date & balances
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.createdAt != null
                                ? 'Requested: ${dateFormat.format(item.createdAt!.toLocal())}'
                                : 'Requested recently',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Wallet: ${item.goldBalanceGrams.toStringAsFixed(4)} g Gold',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: item.goldBalanceGrams > 0
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      if (item.reason != null &&
                          item.reason!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Reason: "${item.reason}"',
                            style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],

                      if (item.adminComment != null &&
                          item.adminComment!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: item.status.toLowerCase() == 'approved'
                                ? AppTheme.rose.withValues(alpha: 0.08)
                                : Colors.blueGrey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: item.status.toLowerCase() == 'approved'
                                  ? AppTheme.rose.withValues(alpha: 0.2)
                                  : Colors.blueGrey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.status.toLowerCase() == 'approved'
                                    ? 'Admin Approval Note:'
                                    : 'Admin Rejection Reason:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: item.status.toLowerCase() == 'approved'
                                      ? AppTheme.rose
                                      : Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.adminComment!,
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (item.reviewedAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Decided: ${dateFormat.format(item.reviewedAt!.toLocal())}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      if (isPending) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blueGrey,
                                side: const BorderSide(color: Colors.blueGrey),
                              ),
                              onPressed: () => onReject(item),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Reject'),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.rose,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => onApprove(item),
                              icon: const Icon(Icons.delete_forever, size: 16),
                              label: const Text('Approve & Purge'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
