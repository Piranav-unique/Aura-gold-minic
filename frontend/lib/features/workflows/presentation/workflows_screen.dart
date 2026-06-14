import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/filter_chip_bar.dart';
import 'package:ags_gold/core/widgets/premium_data_table.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/workflows/domain/workflow.dart';
import 'package:ags_gold/features/workflows/presentation/providers/workflows_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

class WorkflowsScreen extends ConsumerStatefulWidget {
  const WorkflowsScreen({super.key});

  @override
  ConsumerState<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends ConsumerState<WorkflowsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(workflowsSearchProvider.notifier).update(value);
      ref.read(workflowsSkipProvider.notifier).update(0);
    });
  }

  Color _stateColor(String state) {
    switch (state) {
      case 'draft':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      case 'approved':
        return AppTheme.emerald;
      case 'rejected':
        return AppTheme.rose;
      default:
        return Colors.grey;
    }
  }

  Widget _stateChip(String state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _stateColor(state).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        workflowStateLabel(state),
        style: TextStyle(
          color: _stateColor(state),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  bool _canCreate() {
    final profile = ref.watch(profileProvider).value;
    if (profile == null) return false;
    return hasPermission(profile, 'workflow.create');
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(workflowsListProvider);
    final pendingAsync = ref.watch(myPendingApprovalsProvider);
    final profile = ref.watch(profileProvider).value;
    final canApprove =
        profile != null && hasPermission(profile, 'workflow.approve');
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    return ResponsiveNavigationWrapper(
      title: 'Workflows & Approvals',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_canCreate())
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => context.push('/workflows/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New request'),
                ),
              ),
            if (_canCreate()) const SizedBox(height: 16),
            if (canApprove) ...[
              Text(
                'My pending approvals',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              pendingAsync.when(
                data: (pending) {
                  if (pending.items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('No pending approvals assigned to you.'),
                    );
                  }
                  return Card(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pending.items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = pending.items[index];
                        return ListTile(
                          title: Text(item.title),
                          subtitle: Text(item.requestNumber),
                          trailing: _stateChip(item.state),
                          onTap: () => context.push('/workflows/${item.id}'),
                        );
                      },
                    ),
                  );
                },
                loading: () => const PremiumSkeletonList(itemCount: 2),
                error: (e, _) => Text('Failed to load pending: $e'),
              ),
            ],
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search requests',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            FilterChipBar(
              options: const ['draft', 'pending', 'approved', 'rejected'],
              selected: ref.watch(workflowsStateFilterProvider),
              onSelected: (value) {
                ref.read(workflowsStateFilterProvider.notifier).update(value);
                ref.read(workflowsSkipProvider.notifier).update(0);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Only my requests'),
              value: ref.watch(workflowsMineOnlyProvider),
              onChanged: (v) {
                ref.read(workflowsMineOnlyProvider.notifier).update(v);
                ref.read(workflowsSkipProvider.notifier).update(0);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: listAsync.when(
                data: (page) {
                  if (page.items.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.approval_outlined,
                      title: 'No workflow requests',
                      subtitle: 'Create a request to start an approval flow.',
                      actionLabel: _canCreate() ? 'New request' : null,
                      onAction: _canCreate()
                          ? () => context.push('/workflows/new')
                          : null,
                    );
                  }

                  if (!isDesktop) {
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(workflowsListProvider.future),
                      child: ListView.builder(
                        itemCount: page.items.length,
                        itemBuilder: (context, index) {
                          final item = page.items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(item.title),
                              subtitle: Text(
                                '${item.requestNumber} • ${workflowTypeLabel(item.requestType)}',
                              ),
                              trailing: _stateChip(item.state),
                              onTap: () =>
                                  context.push('/workflows/${item.id}'),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  return PremiumDataTable<WorkflowRequest>(
                    items: page.items,
                    columns: [
                      DataTableColumn(
                        label: 'Number',
                        valueGetter: (item) => item.requestNumber,
                        cellBuilder: (item) => InkWell(
                          onTap: () => context.push('/workflows/${item.id}'),
                          child: Text(item.requestNumber),
                        ),
                      ),
                      DataTableColumn(
                        label: 'Title',
                        valueGetter: (item) => item.title,
                        cellBuilder: (item) => Text(item.title),
                      ),
                      DataTableColumn(
                        label: 'Type',
                        valueGetter: (item) => item.requestType,
                        cellBuilder: (item) =>
                            Text(workflowTypeLabel(item.requestType)),
                      ),
                      DataTableColumn(
                        label: 'State',
                        valueGetter: (item) => item.state,
                        cellBuilder: (item) => _stateChip(item.state),
                      ),
                      DataTableColumn(
                        label: 'Assignee',
                        valueGetter: (item) => item.assignee?.displayName ?? '',
                        cellBuilder: (item) =>
                            Text(item.assignee?.displayName ?? '—'),
                      ),
                      DataTableColumn(
                        label: 'Created',
                        valueGetter: (item) => item.createdAt,
                        cellBuilder: (item) =>
                            Text(dateFormat.format(item.createdAt)),
                      ),
                    ],
                  );
                },
                loading: () => const PremiumSkeletonList(itemCount: 8),
                error: (e, _) => EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Failed to load workflows',
                  subtitle: '$e',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(workflowsListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
