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
import 'package:ags_gold/features/transactions/domain/transaction.dart';
import 'package:ags_gold/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
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
      ref.read(transactionsSearchProvider.notifier).update(value);
      ref.read(transactionsSkipProvider.notifier).update(0);
    });
  }

  void _onSort(int columnIndex) {
    final field = transactionTableSortFields[columnIndex];
    if (field == null) return;
    final current = ref.read(transactionsSortFieldProvider);
    if (current == field) {
      ref.read(transactionsSortAscProvider.notifier).toggle();
    } else {
      ref.read(transactionsSortFieldProvider.notifier).update(field);
    }
    ref.read(transactionsSkipProvider.notifier).update(0);
  }

  int? _sortColumnIndex() {
    final field = ref.watch(transactionsSortFieldProvider);
    for (final entry in transactionTableSortFields.entries) {
      if (entry.value == field) return entry.key;
    }
    return null;
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'paid':
        return AppTheme.emerald;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return AppTheme.rose;
      case 'refunded':
        return AppTheme.sapphireBlue;
      default:
        return Colors.grey;
    }
  }

  bool _canCreate(WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    if (profile == null) return false;
    return hasPermission(profile, 'transaction.create');
  }

  Widget _paymentChip(Transaction txn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _paymentColor(txn.paymentStatus).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        paymentStatusLabel(txn.paymentStatus),
        style: TextStyle(
          color: _paymentColor(txn.paymentStatus),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPagination(PaginatedTransactions page) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${page.total} total'),
          Row(
            children: [
              IconButton(
                onPressed: page.skip > 0
                    ? () => ref
                          .read(transactionsSkipProvider.notifier)
                          .update((page.skip - page.limit).clamp(0, page.total))
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: page.skip + page.limit < page.total
                    ? () => ref
                          .read(transactionsSkipProvider.notifier)
                          .update(page.skip + page.limit)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsListProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');
    final canCreate = _canCreate(ref);

    return ResponsiveNavigationWrapper(
      title: 'Transactions',
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
                      hintText: 'Search by number, invoice, receipt...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                if (canCreate) ...[
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/transactions/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('New Transaction'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            FilterChipBar(
              options: transactionTypes,
              selected: ref.watch(transactionsTypeFilterProvider),
              onSelected: (value) {
                ref.read(transactionsTypeFilterProvider.notifier).update(value);
                ref.read(transactionsSkipProvider.notifier).update(0);
              },
            ),
            const SizedBox(height: 8),
            FilterChipBar(
              options: paymentStatuses,
              selected: ref.watch(transactionsPaymentFilterProvider),
              onSelected: (value) {
                ref
                    .read(transactionsPaymentFilterProvider.notifier)
                    .update(value);
                ref.read(transactionsSkipProvider.notifier).update(0);
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: transactionsAsync.when(
                data: (page) {
                  if (page.items.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions found',
                      subtitle: canCreate
                          ? 'Create your first transaction to get started.'
                          : null,
                      actionLabel: canCreate ? 'New Transaction' : null,
                      onAction: canCreate
                          ? () => context.go('/transactions/new')
                          : null,
                    );
                  }

                  if (!isDesktop) {
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(transactionsListProvider.future),
                      child: ListView.builder(
                        itemCount: page.items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == page.items.length) {
                            return _buildPagination(page);
                          }
                          final txn = page.items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(txn.transactionNumber),
                              subtitle: Text(
                                '${transactionTypeLabel(txn.transactionType)} • ${currency.format(txn.totalAmount)}',
                              ),
                              trailing: _paymentChip(txn),
                              onTap: () =>
                                  context.go('/transactions/${txn.id}'),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: PremiumDataTable<Transaction>(
                          items: page.items,
                          sortColumnIndex: _sortColumnIndex(),
                          sortAscending: ref.watch(transactionsSortAscProvider),
                          onSort: _onSort,
                          columns: [
                            DataTableColumn(
                              label: 'Number',
                              valueGetter: (t) => t.transactionNumber,
                              cellBuilder: (t) => InkWell(
                                onTap: () =>
                                    context.go('/transactions/${t.id}'),
                                child: Text(t.transactionNumber),
                              ),
                            ),
                            DataTableColumn(
                              label: 'Type',
                              valueGetter: (t) => t.transactionType,
                              cellBuilder: (t) =>
                                  Text(transactionTypeLabel(t.transactionType)),
                            ),
                            DataTableColumn(
                              label: 'Total',
                              valueGetter: (t) => t.totalAmount,
                              cellBuilder: (t) =>
                                  Text(currency.format(t.totalAmount)),
                            ),
                            DataTableColumn(
                              label: 'Payment',
                              valueGetter: (t) => t.paymentStatus,
                              cellBuilder: (t) => _paymentChip(t),
                            ),
                            DataTableColumn(
                              label: 'Status',
                              valueGetter: (t) => t.status,
                              cellBuilder: (t) => Text(
                                t.isCancelled ? 'Cancelled' : 'Active',
                                style: TextStyle(
                                  color: t.isCancelled
                                      ? AppTheme.rose
                                      : AppTheme.emerald,
                                ),
                              ),
                            ),
                            DataTableColumn(
                              label: 'Created',
                              valueGetter: (t) => t.createdAt,
                              cellBuilder: (t) =>
                                  Text(dateFormat.format(t.createdAt)),
                            ),
                          ],
                        ),
                      ),
                      _buildPagination(page),
                    ],
                  );
                },
                loading: () => const PremiumSkeletonList(itemCount: 8),
                error: (error, _) => EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Failed to load transactions',
                  subtitle: error.toString(),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(transactionsListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
