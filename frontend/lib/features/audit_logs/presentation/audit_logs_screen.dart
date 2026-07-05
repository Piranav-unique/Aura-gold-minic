import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/utils/file_download.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/premium_timeline.dart';
import 'package:ags_gold/core/widgets/premium_data_table.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/filter_chip_bar.dart';
import 'package:ags_gold/features/audit_logs/domain/audit_log.dart';
import 'package:ags_gold/features/audit_logs/presentation/providers/audit_logs_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
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
      ref.read(auditLogsSearchProvider.notifier).update(value);
      ref.read(auditLogsSkipProvider.notifier).update(0);
    });
  }

  Future<void> _pickDateRange() async {
    final current = ref.read(auditLogsDateRangeProvider);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: current != null
          ? DateTimeRange(start: current.start, end: current.end)
          : null,
    );
    if (picked != null) {
      ref
          .read(auditLogsDateRangeProvider.notifier)
          .update(AuditDateRange(picked.start, picked.end));
      ref.read(auditLogsSkipProvider.notifier).update(0);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final search = ref.read(auditLogsSearchProvider);
      final action = ref.read(auditLogsActionFilterProvider);
      final entityType = ref.read(auditLogsEntityFilterProvider);
      final dateRange = ref.read(auditLogsDateRangeProvider);

      final params = <String, dynamic>{};
      if (search.isNotEmpty) params['search'] = search;
      if (action != null) params['action'] = action;
      if (entityType != null) params['entity_type'] = entityType;
      if (dateRange != null) {
        params['start_date'] = dateRange.start.toUtc().toIso8601String();
        params['end_date'] = dateRange.end.toUtc().toIso8601String();
      }

      final response = await apiClient.get(
        '/audit-logs/export',
        queryParameters: params,
        options: Options(responseType: ResponseType.plain),
      );
      final csv = response.data as String;
      await downloadTextFile(
        filename: 'audit_logs.csv',
        content: csv,
        mimeType: 'text/csv',
      );
      if (!mounted) return;
      final rowCount = csv.split('\n').length - 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded audit_logs.csv ($rowCount rows)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  List<AuditLog> _sortedItems(List<AuditLog> items) {
    final sortIndex = ref.read(auditLogsSortProvider);
    final ascending = ref.read(auditLogsSortAscProvider);
    final sorted = List<AuditLog>.from(items);
    int compare<T extends Comparable>(T a, T b) =>
        ascending ? a.compareTo(b) : b.compareTo(a);

    sorted.sort((a, b) {
      switch (sortIndex) {
        case 1:
          return compare(a.action, b.action);
        case 2:
          return compare(a.entityType ?? '', b.entityType ?? '');
        default:
          return compare(a.timestamp, b.timestamp);
      }
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsListProvider);
    final isTimeline = ref.watch(auditLogsTimelineViewProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    return ResponsiveNavigationWrapper(
      title: 'Audit Logs',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search audit logs...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  tooltip: 'Filter by date range',
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Export CSV',
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () =>
                      ref.read(auditLogsTimelineViewProvider.notifier).toggle(),
                  icon: Icon(isTimeline ? Icons.table_rows : Icons.timeline),
                  tooltip: isTimeline ? 'Table view' : 'Timeline view',
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilterChipBar(
              options: auditActionOptions,
              selected: ref.watch(auditLogsActionFilterProvider),
              onSelected: (v) {
                ref.read(auditLogsActionFilterProvider.notifier).update(v);
                ref.read(auditLogsSkipProvider.notifier).update(0);
              },
            ),
            const SizedBox(height: 8),
            FilterChipBar(
              options: auditEntityOptions,
              selected: ref.watch(auditLogsEntityFilterProvider),
              onSelected: (v) {
                ref.read(auditLogsEntityFilterProvider.notifier).update(v);
                ref.read(auditLogsSkipProvider.notifier).update(0);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: logsAsync.when(
                data: (page) {
                  if (page.items.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.history_toggle_off,
                      title: 'No audit events yet',
                      subtitle:
                          'Activity will appear here as users interact with the system.',
                    );
                  }

                  final items = _sortedItems(page.items);

                  if (isTimeline || !isDesktop) {
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(auditLogsListProvider.future),
                      child: ListView(
                        children: [
                          PremiumTimeline(
                            entries: items
                                .map(
                                  (log) => TimelineEntry(
                                    title: log.action
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    subtitle:
                                        '${log.entityType ?? 'System'} • ${log.entityId ?? '—'}',
                                    timestamp: log.timestamp,
                                    icon: Icons.fingerprint,
                                  ),
                                )
                                .toList(),
                          ),
                          _buildPagination(page),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: PremiumDataTable<AuditLog>(
                          items: items,
                          sortColumnIndex: ref.watch(auditLogsSortProvider),
                          sortAscending: ref.watch(auditLogsSortAscProvider),
                          onSort: (index) {
                            final current = ref.read(auditLogsSortProvider);
                            if (current == index) {
                              ref
                                  .read(auditLogsSortAscProvider.notifier)
                                  .toggle();
                            } else {
                              ref
                                  .read(auditLogsSortProvider.notifier)
                                  .update(index);
                            }
                          },
                          columns: [
                            DataTableColumn(
                              label: 'Timestamp',
                              valueGetter: (l) => l.timestamp,
                              cellBuilder: (l) =>
                                  Text(dateFormat.format(l.timestamp)),
                            ),
                            DataTableColumn(
                              label: 'Action',
                              valueGetter: (l) => l.action,
                              cellBuilder: (l) => Text(l.action),
                            ),
                            DataTableColumn(
                              label: 'Entity',
                              valueGetter: (l) => l.entityType ?? '',
                              cellBuilder: (l) => Text(
                                '${l.entityType ?? ''} ${l.entityId ?? ''}',
                              ),
                            ),
                            DataTableColumn(
                              label: 'User',
                              cellBuilder: (l) => Text(l.userId ?? '—'),
                            ),
                          ],
                        ),
                      ),
                      _buildPagination(page),
                    ],
                  );
                },
                loading: () => ListView(
                  children: const [PremiumSkeletonList(itemCount: 8)],
                ),
                error: (e, _) => EmptyStateWidget(
                  icon: Icons.lock_outline,
                  title: 'Unable to load audit logs',
                  subtitle: e.toString(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(PaginatedAuditLogs page) {
    final skip = ref.watch(auditLogsSkipProvider);
    final limit = ref.watch(auditLogsLimitProvider);
    final canPrev = skip > 0;
    final canNext = skip + limit < page.total;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${skip + 1}-${skip + page.items.length} of ${page.total}',
          ),
          Row(
            children: [
              IconButton(
                onPressed: canPrev
                    ? () => ref
                          .read(auditLogsSkipProvider.notifier)
                          .update(skip - limit)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: canNext
                    ? () => ref
                          .read(auditLogsSkipProvider.notifier)
                          .update(skip + limit)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
