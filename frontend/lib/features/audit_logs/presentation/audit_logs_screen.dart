import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/utils/file_download.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/features/audit_logs/domain/audit_log.dart';
import 'package:ags_gold/features/audit_logs/presentation/providers/audit_logs_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

class _SummaryCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color badgeBg;
  final Color badgeFg;

  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.badgeBg,
    required this.badgeFg,
  });
}

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
    _debounce = Timer(const Duration(milliseconds: 350), () {
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryGold,
            ),
          ),
          child: child!,
        );
      },
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
        SnackBar(
          content: Text('Downloaded audit_logs.csv ($rowCount rows)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static String _formatActionBadgeText(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('create') || lower.contains('signup') || lower.contains('register')) {
      return 'CREATE';
    }
    if (lower.contains('update') || lower.contains('edit') || lower.contains('change') || lower.contains('assign')) {
      return 'UPDATE';
    }
    if (lower.contains('delete') || lower.contains('remove') || lower.contains('cancel')) {
      return 'DELETE';
    }
    if (lower.contains('login') || lower.contains('auth')) {
      return 'LOGIN';
    }
    if (lower.contains('export') || lower.contains('view') || lower.contains('read') || lower.contains('get')) {
      return 'READ';
    }
    return action.split('_').first.toUpperCase();
  }

  static Color _actionBadgeBg(String badgeText, bool isDark) {
    switch (badgeText) {
      case 'CREATE':
        return isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE);
      case 'UPDATE':
        return isDark ? const Color(0xFF4C3608) : const Color(0xFFFEF3C7);
      case 'DELETE':
        return isDark ? const Color(0xFF4C1D24) : const Color(0xFFFEE2E2);
      case 'LOGIN':
        return isDark ? const Color(0xFF143E2C) : const Color(0xFFD1FAE5);
      default:
        return isDark ? const Color(0xFF262D3D) : const Color(0xFFF1F5F9);
    }
  }

  static Color _actionBadgeFg(String badgeText, bool isDark) {
    switch (badgeText) {
      case 'CREATE':
        return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
      case 'UPDATE':
        return isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
      case 'DELETE':
        return isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
      case 'LOGIN':
        return isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
      default:
        return isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    }
  }

  static bool _isSuccessAction(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('fail') || lower.contains('error') || lower.contains('denied') || lower.contains('blocked')) {
      return false;
    }
    return true;
  }

  static String _formatModule(AuditLog log) {
    if (log.entityType != null && log.entityType!.isNotEmpty) {
      final t = log.entityType!;
      if (t.toLowerCase() == 'user') return 'User Management';
      if (t.toLowerCase() == 'customer') return 'Customer Records';
      if (t.toLowerCase() == 'role') return 'Roles & Permissions';
      if (t.toLowerCase() == 'inventory') return 'Inventory';
      if (t.toLowerCase() == 'wallet' || t.toLowerCase() == 'transaction') return 'Wallets & Payments';
      return t;
    }
    final action = log.action.toLowerCase();
    if (action.contains('user')) return 'User Management';
    if (action.contains('customer')) return 'Customer Records';
    if (action.contains('role') || action.contains('permission')) return 'Roles & Permissions';
    if (action.contains('payment') || action.contains('settle')) return 'Payment Settlements';
    if (action.contains('inventory') || action.contains('stock')) return 'Inventory';
    if (action.contains('login') || action.contains('auth')) return 'Authentication';
    return 'System';
  }

  static String _formatDetails(AuditLog log) {
    if (log.metadata != null && log.metadata!.isNotEmpty) {
      if (log.metadata!['details'] != null) return log.metadata!['details'].toString();
      if (log.metadata!['description'] != null) return log.metadata!['description'].toString();
      if (log.metadata!['reason'] != null) return 'Reason: ${log.metadata!['reason']}';
    }
    final action = log.action.replaceAll('_', ' ');
    final entity = log.entityType ?? 'entity';
    final id = log.entityId != null ? ' (${log.entityId})' : '';
    return '$action on $entity$id';
  }

  static String _formatUserTitle(AuditLog log) {
    if (log.metadata != null && log.metadata!['email'] != null) {
      return log.metadata!['email'].toString();
    }
    if (log.userId != null && log.userId!.isNotEmpty) {
      if (log.userId!.length > 12) {
        return 'User #${log.userId!.substring(0, 8)}';
      }
      return 'User ${log.userId}';
    }
    return 'System Admin';
  }

  static String _formatUserSubtitle(AuditLog log) {
    if (log.metadata != null && log.metadata!['role'] != null) {
      return log.metadata!['role'].toString();
    }
    if (log.ipAddress != null && log.ipAddress!.isNotEmpty) {
      return log.ipAddress!;
    }
    return 'Staff / Admin';
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsListProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final selectedDateRange = ref.watch(auditLogsDateRangeProvider);
    final selectedAction = ref.watch(auditLogsActionFilterProvider);
    final selectedEntity = ref.watch(auditLogsEntityFilterProvider);

    return ResponsiveNavigationWrapper(
      title: 'System Audit Logs',
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(auditLogsListProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP ACTIVITY SUMMARY KPI CARDS
              logsAsync.when(
                data: (page) => _buildSummaryCards(page, isDark),
                loading: () => _buildSummaryCardsSkeleton(isDark),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              // 2. SEARCH & FILTER TOOLBAR
              _buildSearchAndFilters(
                context,
                isDesktop: isDesktop,
                isDark: isDark,
                selectedDateRange: selectedDateRange,
                selectedAction: selectedAction,
                selectedEntity: selectedEntity,
              ),
              const SizedBox(height: 16),

              // 3. AUDIT LOGS TABLE / CARD LIST
              logsAsync.when(
                data: (page) {
                  if (page.items.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: EmptyStateWidget(
                        icon: Icons.history_toggle_off,
                        title: 'No audit events found',
                        subtitle: _searchController.text.isNotEmpty ||
                                selectedAction != null ||
                                selectedEntity != null ||
                                selectedDateRange != null
                            ? 'No logs match your active filters. Try clearing search filters.'
                            : 'Activity events will appear here as users interact with the system.',
                        actionLabel: (_searchController.text.isNotEmpty ||
                                selectedAction != null ||
                                selectedEntity != null ||
                                selectedDateRange != null)
                            ? 'Reset All Filters'
                            : null,
                        onAction: () {
                          _searchController.clear();
                          ref.read(auditLogsSearchProvider.notifier).update('');
                          ref.read(auditLogsActionFilterProvider.notifier).update(null);
                          ref.read(auditLogsEntityFilterProvider.notifier).update(null);
                          ref.read(auditLogsDateRangeProvider.notifier).update(null);
                          ref.read(auditLogsSkipProvider.notifier).update(0);
                        },
                      ),
                    );
                  }

                  if (isDesktop) {
                    return _buildDesktopTable(page, dateFormat, isDark, theme);
                  }
                  return _buildMobileLogCards(page, dateFormat, isDark, theme);
                },
                loading: () => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const PremiumSkeletonList(itemCount: 8),
                ),
                error: (e, _) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: EmptyStateWidget(
                    icon: Icons.error_outline,
                    title: 'Unable to load audit logs',
                    subtitle: e.toString(),
                    actionLabel: 'Retry',
                    onAction: () => ref.refresh(auditLogsListProvider.future),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. SUMMARY KPI CARDS
  // ===========================================================================

  Widget _buildSummaryCards(PaginatedAuditLogs page, bool isDark) {
    final items = page.items;
    final total = page.total;
    final successCount = items.where((l) => _isSuccessAction(l.action)).length;
    final failedCount = items.length - successCount;
    final successRate = items.isEmpty
        ? 100
        : ((successCount / items.length) * 100).round();
    final uniqueUsers = items.map((l) => l.userId ?? 'system').toSet().length;

    final cards = [
      _SummaryCardData(
        title: 'Total Events',
        value: '$total',
        subtitle: 'Recorded in system',
        icon: Icons.article_outlined,
        badgeBg: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        badgeFg: isDark ? AppTheme.primaryGold : const Color(0xFF2563EB),
      ),
      _SummaryCardData(
        title: 'Successful',
        value: '$successCount',
        subtitle: '$successRate% success rate',
        icon: Icons.verified_user_outlined,
        badgeBg: isDark ? const Color(0xFF143E2C) : const Color(0xFFDCFCE7),
        badgeFg: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
      ),
      _SummaryCardData(
        title: 'Failed Actions',
        value: '$failedCount',
        subtitle: failedCount > 0 ? 'Requires review' : 'All systems clear',
        icon: Icons.warning_amber_rounded,
        badgeBg: isDark ? const Color(0xFF4C1D24) : const Color(0xFFFEE2E2),
        badgeFg: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      ),
      _SummaryCardData(
        title: 'Active Users',
        value: '$uniqueUsers',
        subtitle: 'Unique actors logged',
        icon: Icons.people_outline,
        badgeBg: isDark ? const Color(0xFF312E81) : const Color(0xFFF3E8FF),
        badgeFg: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 550
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 110,
          ),
          itemBuilder: (context, i) => _buildKpiCard(context, cards[i], isDark),
        );
      },
    );
  }

  Widget _buildSummaryCardsSkeleton(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 550
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 110,
          ),
          itemBuilder: (context, i) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(BuildContext context, _SummaryCardData data, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.badgeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.badgeFg, size: 22),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. SEARCH & FILTER TOOLBAR
  // ===========================================================================

  Widget _buildSearchAndFilters(
    BuildContext context, {
    required bool isDesktop,
    required bool isDark,
    required AuditDateRange? selectedDateRange,
    required String? selectedAction,
    required String? selectedEntity,
  }) {
    final theme = Theme.of(context);
    final dateRangeLabel = selectedDateRange != null
        ? '${DateFormat('MM/dd').format(selectedDateRange.start)} - ${DateFormat('MM/dd').format(selectedDateRange.end)}'
        : 'Date';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.12),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Input Box
          SizedBox(
            width: isDesktop ? 340 : double.infinity,
            height: 42,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Search by user, action, or details...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                filled: true,
                fillColor: isDark
                    ? theme.colorScheme.surface
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGold,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Action Filter Dropdown
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selectedAction != null
                    ? AppTheme.primaryGold
                    : theme.dividerColor.withValues(alpha: 0.15),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedAction,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                hint: const Text('All actions', style: TextStyle(fontSize: 13)),
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All actions'),
                  ),
                  for (final opt in auditActionOptions)
                    DropdownMenuItem<String?>(
                      value: opt,
                      child: Text(opt.replaceAll('_', ' ')),
                    ),
                ],
                onChanged: (v) {
                  ref.read(auditLogsActionFilterProvider.notifier).update(v);
                  ref.read(auditLogsSkipProvider.notifier).update(0);
                },
              ),
            ),
          ),

          // Module / Entity Filter Dropdown
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selectedEntity != null
                    ? AppTheme.primaryGold
                    : theme.dividerColor.withValues(alpha: 0.15),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedEntity,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                hint: const Text('All modules', style: TextStyle(fontSize: 13)),
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All modules'),
                  ),
                  for (final opt in auditEntityOptions)
                    DropdownMenuItem<String?>(
                      value: opt,
                      child: Text(opt),
                    ),
                ],
                onChanged: (v) {
                  ref.read(auditLogsEntityFilterProvider.notifier).update(v);
                  ref.read(auditLogsSkipProvider.notifier).update(0);
                },
              ),
            ),
          ),

          // Date Picker Button
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _pickDateRange,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(
                  color: selectedDateRange != null
                      ? AppTheme.primaryGold
                      : theme.dividerColor.withValues(alpha: 0.15),
                ),
                backgroundColor: isDark
                    ? theme.colorScheme.surface
                    : const Color(0xFFF8FAFC),
              ),
              icon: Icon(
                Icons.date_range_outlined,
                size: 16,
                color: selectedDateRange != null
                    ? AppTheme.primaryGold
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              label: Text(
                dateRangeLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selectedDateRange != null
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: selectedDateRange != null
                      ? AppTheme.primaryGold
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),

          // Clear Date filter if active
          if (selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Clear date filter',
              onPressed: () {
                ref.read(auditLogsDateRangeProvider.notifier).update(null);
                ref.read(auditLogsSkipProvider.notifier).update(0);
              },
            ),

          if (isDesktop) const Spacer(),

          // Export CSV Button
          SizedBox(
            width: isDesktop ? null : double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: _exportCsv,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.ink,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text(
                'Export CSV',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. DESKTOP DATA TABLE (MATCHING REFERENCE UI)
  // ===========================================================================

  Widget _buildDesktopTable(
    PaginatedAuditLogs page,
    DateFormat dateFormat,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surface
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              children: [
                _tableHeaderCell('TIMESTAMP', width: 170),
                _tableHeaderCell('USER', width: 160),
                _tableHeaderCell('ACTION', width: 110),
                _tableHeaderCell('MODULE', width: 160),
                Expanded(child: _tableHeaderCell('DETAILS')),
                _tableHeaderCell('STATUS', width: 100, align: TextAlign.right),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: page.items.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: 1,
              color: theme.dividerColor.withValues(alpha: 0.08),
            ),
            itemBuilder: (context, index) {
              final log = page.items[index];
              final actionBadgeText = _formatActionBadgeText(log.action);
              final isSuccess = _isSuccessAction(log.action);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // TIMESTAMP
                    SizedBox(
                      width: 170,
                      child: Text(
                        dateFormat.format(log.timestamp),
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.85,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // USER
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatUserTitle(log),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _formatUserSubtitle(log),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ACTION PILL BADGE
                    SizedBox(
                      width: 110,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _actionBadgeBg(actionBadgeText, isDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            actionBadgeText,
                            style: TextStyle(
                              color: _actionBadgeFg(actionBadgeText, isDark),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // MODULE
                    SizedBox(
                      width: 160,
                      child: Text(
                        _formatModule(log),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // DETAILS
                    Expanded(
                      child: Text(
                        _formatDetails(log),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                    ),

                    // STATUS BADGE
                    SizedBox(
                      width: 100,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSuccess
                                ? (isDark
                                    ? const Color(0xFF143E2C)
                                    : const Color(0xFFDCFCE7))
                                : (isDark
                                    ? const Color(0xFF4C1D24)
                                    : const Color(0xFFFEE2E2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isSuccess ? 'Success' : 'Failed',
                            style: TextStyle(
                              color: isSuccess
                                  ? (isDark
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF15803D))
                                  : (isDark
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFFB91C1C)),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Pagination Footer
          _buildPaginationFooter(page, theme),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(
    String label, {
    double? width,
    TextAlign align = TextAlign.left,
  }) {
    final widget = Text(
      label,
      textAlign: align,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: Color(0xFF64748B),
      ),
    );
    if (width != null) {
      return SizedBox(width: width, child: widget);
    }
    return widget;
  }

  // ===========================================================================
  // 4. MOBILE LOG CARDS
  // ===========================================================================

  Widget _buildMobileLogCards(
    PaginatedAuditLogs page,
    DateFormat dateFormat,
    bool isDark,
    ThemeData theme,
  ) {
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: page.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = page.items[index];
            final actionBadgeText = _formatActionBadgeText(log.action);
            final isSuccess = _isSuccessAction(log.action);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _actionBadgeBg(actionBadgeText, isDark),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          actionBadgeText,
                          style: TextStyle(
                            color: _actionBadgeFg(actionBadgeText, isDark),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isSuccess
                              ? (isDark
                                  ? const Color(0xFF143E2C)
                                  : const Color(0xFFDCFCE7))
                              : (isDark
                                  ? const Color(0xFF4C1D24)
                                  : const Color(0xFFFEE2E2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isSuccess ? 'Success' : 'Failed',
                          style: TextStyle(
                            color: isSuccess
                                ? (isDark
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF15803D))
                                : (isDark
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFFB91C1C)),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatDetails(log),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${_formatModule(log)} • ${_formatUserTitle(log)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(log.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        _buildPaginationFooter(page, theme),
      ],
    );
  }

  // ===========================================================================
  // 5. PAGINATION FOOTER
  // ===========================================================================

  Widget _buildPaginationFooter(PaginatedAuditLogs page, ThemeData theme) {
    final skip = ref.watch(auditLogsSkipProvider);
    final limit = ref.watch(auditLogsLimitProvider);
    final canPrev = skip > 0;
    final canNext = skip + limit < page.total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${skip + 1}-${skip + page.items.length} of ${page.total} events',
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              IconButton.outlined(
                onPressed: canPrev
                    ? () => ref
                        .read(auditLogsSkipProvider.notifier)
                        .update(skip - limit)
                    : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: canNext
                    ? () => ref
                        .read(auditLogsSkipProvider.notifier)
                        .update(skip + limit)
                    : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
