import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/filter_chip_bar.dart';
import 'package:ags_gold/core/widgets/premium_data_table.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/features/admin/domain/wallet_pagination.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_wallet_provider.dart';
import 'package:ags_gold/features/admin/presentation/wallet_transaction_detail_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final String? initialUserSearch;

  const TransactionsScreen({super.key, this.initialUserSearch});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _userSearchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialUserSearch?.trim();
    if (initial != null && initial.isNotEmpty) {
      _userSearchController.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(walletActivityUserSearchProvider.notifier).update(initial);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _userSearchController.dispose();
    super.dispose();
  }

  void _onUserSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(walletActivityUserSearchProvider.notifier).update(value);
      ref.read(recentWalletTransactionsPageProvider.notifier).update(1);
    });
  }

  void _openWalletTransaction(WalletTransactionItem txn) {
    openWalletTransactionDetail(context, txn.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final timeRange = ref.watch(walletActivityTimeRangeProvider);
    final recentAsync = ref.watch(recentWalletTransactionsProvider);
    final pageNum = ref.watch(recentWalletTransactionsPageProvider);

    return ResponsiveNavigationWrapper(
      title: 'Transactions',
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transactions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buy, sell, referral, and savings activity across all users.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userSearchController,
              decoration: InputDecoration(
                hintText: 'Filter by user name, mobile, or email…',
                prefixIcon: const Icon(Icons.person_search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onUserSearchChanged,
            ),
            const SizedBox(height: 12),
            FilterChipBar(
              options: const ['All time', 'Today', '7 days', '30 days'],
              selected: _timeRangeLabel(timeRange),
              allowClear: false,
              onSelected: (value) {
                ref
                    .read(walletActivityTimeRangeProvider.notifier)
                    .update(_timeRangeFromLabel(value));
                ref.read(recentWalletTransactionsPageProvider.notifier).update(1);
              },
            ),
            const SizedBox(height: 8),
            FilterChipBar(
              options: const ['BUY', 'SELL', 'REFERRAL', 'SAVINGS'],
              selected: ref.watch(recentWalletTxnTypeFilterProvider),
              onSelected: (value) {
                ref.read(recentWalletTxnTypeFilterProvider.notifier).update(value);
                ref.read(recentWalletTransactionsPageProvider.notifier).update(1);
              },
            ),
            const SizedBox(height: 8),
            FilterChipBar(
              options: const ['gold', 'silver'],
              selected: ref.watch(walletTxnMetalFilterProvider),
              onSelected: (value) {
                ref.read(walletTxnMetalFilterProvider.notifier).update(value);
                ref.read(recentWalletTransactionsPageProvider.notifier).update(1);
              },
            ),
            const SizedBox(height: 8),
            FilterChipBar(
              options: const [
                'paid',
                'pending',
                'approved',
                'rejected',
                'failed',
              ],
              selected: ref.watch(walletTxnStatusFilterProvider),
              onSelected: (value) {
                ref.read(walletTxnStatusFilterProvider.notifier).update(value);
                ref.read(recentWalletTransactionsPageProvider.notifier).update(1);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: recentAsync.when(
                loading: () => const PremiumSkeleton(height: 200),
                error: (e, _) => EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Failed to load transactions',
                  subtitle: '$e',
                  onAction: () => ref.invalidate(recentWalletTransactionsProvider),
                  actionLabel: 'Retry',
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions found',
                      subtitle: 'Try a different user or time filter.',
                    );
                  }
                  if (!isDesktop) {
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(recentWalletTransactionsProvider.future),
                      child: ListView.builder(
                        itemCount: page.items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == page.items.length) {
                            return _txnPagination(page, pageNum);
                          }
                          return _txnMobileCard(
                            page.items[index],
                            currency,
                            dateFormat,
                          );
                        },
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: PremiumDataTable<WalletTransactionItem>(
                          items: page.items,
                          columns: _txnColumns(currency, dateFormat),
                        ),
                      ),
                      _txnPagination(page, pageNum),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _timeRangeLabel(WalletActivityTimeRange range) {
    switch (range) {
      case WalletActivityTimeRange.all:
        return 'All time';
      case WalletActivityTimeRange.today:
        return 'Today';
      case WalletActivityTimeRange.week:
        return '7 days';
      case WalletActivityTimeRange.month:
        return '30 days';
    }
  }

  WalletActivityTimeRange _timeRangeFromLabel(String? label) {
    switch (label) {
      case 'Today':
        return WalletActivityTimeRange.today;
      case '7 days':
        return WalletActivityTimeRange.week;
      case '30 days':
        return WalletActivityTimeRange.month;
      default:
        return WalletActivityTimeRange.all;
    }
  }

  List<DataTableColumn<WalletTransactionItem>> _txnColumns(
    NumberFormat currency,
    DateFormat dateFormat,
  ) {
    return [
      DataTableColumn(
        label: 'Date',
        cellBuilder: (t) => Text(dateFormat.format(t.occurredAt.toLocal())),
      ),
      DataTableColumn(
        label: 'User',
        cellBuilder: (t) => InkWell(
          onTap: () => context.go('/admin/user-wallets/${t.userId}'),
          child: Text(
            t.userName ?? t.userId,
            style: const TextStyle(
              color: AppTheme.sapphireBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      DataTableColumn(
        label: 'Mobile',
        cellBuilder: (t) => Text(t.userMobile ?? '—'),
      ),
      DataTableColumn(
        label: 'Type',
        cellBuilder: (t) => Text(t.transactionType),
      ),
      DataTableColumn(
        label: 'Metal',
        cellBuilder: (t) => Text(t.metal ?? '—'),
      ),
      DataTableColumn(
        label: 'Grams',
        cellBuilder: (t) => Text(
          t.quantityGrams != null
              ? t.quantityGrams!.toStringAsFixed(4)
              : '—',
        ),
      ),
      DataTableColumn(
        label: 'Amount',
        cellBuilder: (t) => Text(
          t.amountInr != null ? currency.format(t.amountInr) : '—',
        ),
      ),
      DataTableColumn(
        label: 'Status',
        cellBuilder: (t) => Text(t.status),
      ),
      DataTableColumn(
        label: '',
        cellBuilder: (t) => IconButton(
          icon: const Icon(Icons.open_in_new, size: 18),
          onPressed: () => _openWalletTransaction(t),
        ),
      ),
    ];
  }

  Widget _txnMobileCard(
    WalletTransactionItem txn,
    NumberFormat currency,
    DateFormat dateFormat,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openWalletTransaction(txn),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          context.go('/admin/user-wallets/${txn.userId}'),
                      child: Text(
                        txn.userName ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.sapphireBlue,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    txn.transactionType,
                    style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(dateFormat.format(txn.occurredAt.toLocal())),
              const SizedBox(height: 8),
              Text(
                [
                  if (txn.metal != null) txn.metal,
                  if (txn.quantityGrams != null)
                    '${txn.quantityGrams!.toStringAsFixed(4)} g',
                  if (txn.amountInr != null) currency.format(txn.amountInr),
                  txn.status,
                ].join(' • '),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _txnPagination(PaginatedWalletTransactions page, int currentPage) {
    final totalPages = (page.total / page.limit).ceil().clamp(1, 9999);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${page.total} transactions'),
          Row(
            children: [
              IconButton(
                onPressed: currentPage > 1
                    ? () => ref
                        .read(recentWalletTransactionsPageProvider.notifier)
                        .update(currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$currentPage / $totalPages'),
              IconButton(
                onPressed: currentPage < totalPages
                    ? () => ref
                        .read(recentWalletTransactionsPageProvider.notifier)
                        .update(currentPage + 1)
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
