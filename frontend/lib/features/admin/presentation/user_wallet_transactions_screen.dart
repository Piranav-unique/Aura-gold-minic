import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/filter_chip_bar.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/features/admin/domain/wallet_pagination.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_wallet_provider.dart';
import 'package:ags_gold/features/admin/presentation/wallet_transaction_detail_sheet.dart';

class UserWalletTransactionsScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserWalletTransactionsScreen({super.key, required this.userId});

  @override
  ConsumerState<UserWalletTransactionsScreen> createState() =>
      _UserWalletTransactionsScreenState();
}

class _UserWalletTransactionsScreenState
    extends ConsumerState<UserWalletTransactionsScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(walletUserDetailProvider(widget.userId));
    final typeFilter = ref.watch(walletTxnTypeFilterProvider);
    final metalFilter = ref.watch(walletTxnMetalFilterProvider);
    final statusFilter = ref.watch(walletTxnStatusFilterProvider);
    final txnQuery = (
      userId: widget.userId,
      page: _page,
      type: typeFilter,
      metal: metalFilter,
      status: statusFilter,
    );
    final txnsAsync = ref.watch(walletUserTransactionsFilteredProvider(txnQuery));
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return ResponsiveNavigationWrapper(
      title: 'Wallet activity',
      child: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeleton(height: 300),
        ),
        error: (e, _) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Failed to load user',
          subtitle: '$e',
          actionLabel: 'Back',
          onAction: () => context.go('/admin/user-wallets'),
        ),
        data: (detail) => Padding(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        context.go('/admin/user-wallets/${widget.userId}'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      detail.fullName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              Text(
                'All buy, sell, referral, and savings activity for this user.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 16),
              FilterChipBar(
                options: const ['BUY', 'SELL', 'REFERRAL', 'SAVINGS'],
                selected: typeFilter,
                onSelected: (value) {
                  ref.read(walletTxnTypeFilterProvider.notifier).update(value);
                  setState(() => _page = 1);
                },
              ),
              const SizedBox(height: 8),
              FilterChipBar(
                options: const ['gold', 'silver'],
                selected: metalFilter,
                onSelected: (value) {
                  ref.read(walletTxnMetalFilterProvider.notifier).update(value);
                  setState(() => _page = 1);
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
                selected: statusFilter,
                onSelected: (value) {
                  ref.read(walletTxnStatusFilterProvider.notifier).update(value);
                  setState(() => _page = 1);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: txnsAsync.when(
                  loading: () => const PremiumSkeleton(height: 200),
                  error: (e, _) => EmptyStateWidget(
                    icon: Icons.error_outline,
                    title: 'Failed to load transactions',
                    subtitle: '$e',
                    onAction: () => ref.invalidate(
                      walletUserTransactionsFilteredProvider(txnQuery),
                    ),
                    actionLabel: 'Retry',
                  ),
                  data: (page) {
                    if (page.items.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: 'No matching activity',
                        subtitle: 'Try changing the filters above.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(
                          walletUserTransactionsFilteredProvider(txnQuery),
                        );
                        await ref.read(
                          walletUserTransactionsFilteredProvider(txnQuery).future,
                        );
                      },
                      child: ListView.separated(
                        itemCount: page.items.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == page.items.length) {
                            return _pager(page);
                          }
                          final txn = page.items[index];
                          return _txnCard(txn, currency, dateFormat);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _txnCard(
    WalletTransactionItem txn,
    NumberFormat currency,
    DateFormat dateFormat,
  ) {
    return Card(
      child: InkWell(
        onTap: () => _openTxn(txn),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      txn.transactionType,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      txn.status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(dateFormat.format(txn.occurredAt.toLocal())),
              if (txn.metal != null) Text('Metal: ${txn.metal}'),
              if (txn.quantityGrams != null)
                Text('Quantity: ${txn.quantityGrams!.toStringAsFixed(4)} g'),
              if (txn.amountInr != null)
                Text(
                  currency.format(txn.amountInr),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTxn(WalletTransactionItem txn) {
    openWalletTransactionDetail(context, txn.id);
  }

  Widget _pager(PaginatedWalletTransactions page) {
    final totalPages = (page.total / page.limit).ceil().clamp(1, 9999);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: _page > 1 ? () => setState(() => _page -= 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('$_page / $totalPages'),
        IconButton(
          onPressed: _page < totalPages ? () => setState(() => _page += 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
