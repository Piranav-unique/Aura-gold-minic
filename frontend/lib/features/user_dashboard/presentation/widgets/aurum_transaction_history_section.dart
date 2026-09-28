import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/user_statements_provider.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

enum TransactionFilter { all, buy, sell, successful, pending, failed }

class AurumTransactionHistorySection extends ConsumerStatefulWidget {
  const AurumTransactionHistorySection({super.key});

  @override
  ConsumerState<AurumTransactionHistorySection> createState() =>
      _AurumTransactionHistorySectionState();
}

class _AurumTransactionHistorySectionState
    extends ConsumerState<AurumTransactionHistorySection> {
  TransactionFilter _currentFilter = TransactionFilter.all;

  final List<TransactionFilter> _filterOptions = const [
    TransactionFilter.all,
    TransactionFilter.buy,
    TransactionFilter.sell,
    TransactionFilter.successful,
    TransactionFilter.pending,
    TransactionFilter.failed,
  ];

  String _filterLabel(TransactionFilter filter, BuildContext context) {
    switch (filter) {
      case TransactionFilter.all:
        return context.l10n.filterAll;
      case TransactionFilter.buy:
        return context.l10n.filterBuy;
      case TransactionFilter.sell:
        return context.l10n.filterSell;
      case TransactionFilter.successful:
        return context.l10n.filterSuccessful;
      case TransactionFilter.pending:
        return context.l10n.filterPending;
      case TransactionFilter.failed:
        return context.l10n.filterFailed;
    }
  }

  bool _matchesFilter(WalletTransactionItem item, TransactionFilter filter) {
    final typeUpper = item.transactionType.toUpperCase();
    final statusLower = item.status.toLowerCase();

    switch (filter) {
      case TransactionFilter.all:
        return true;
      case TransactionFilter.buy:
        return typeUpper == 'BUY';
      case TransactionFilter.sell:
        return typeUpper == 'SELL';
      case TransactionFilter.successful:
        return statusLower == 'paid' ||
            statusLower == 'completed' ||
            statusLower == 'success';
      case TransactionFilter.pending:
        return statusLower == 'pending' || statusLower == 'created';
      case TransactionFilter.failed:
        return statusLower == 'failed' || statusLower == 'cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statementsAsync = ref.watch(userStatementsProvider);
    final isDark = AurumConsumerTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurumConsumerTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurumConsumerTheme.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.transactionHistory,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1A14),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => ref.invalidate(userStatementsProvider),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AppTheme.primaryGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filter Chips Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((filter) {
                final isSelected = filter == _currentFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(filter, context)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _currentFilter = filter),
                    selectedColor: AppTheme.primaryGold.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primaryGold,
                    backgroundColor: AurumConsumerTheme.surfaceElevatedOf(context),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryGold
                          : AurumConsumerTheme.muted(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primaryGold
                            : AurumConsumerTheme.borderOf(context),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Transaction Items
          statementsAsync.when(
            data: (page) {
              final filtered = page.items
                  .where((item) => _matchesFilter(item, _currentFilter))
                  .toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: AurumConsumerTheme.muted(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.noTransactionsFound(_filterLabel(_currentFilter, context)),
                          style: TextStyle(
                            fontSize: 13,
                            color: AurumConsumerTheme.muted(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => Divider(
                  height: 16,
                  color: AurumConsumerTheme.borderOf(context).withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  return _TransactionItemTile(item: filtered[index]);
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Failed to load transactions: $err',
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionItemTile extends StatelessWidget {
  final WalletTransactionItem item;

  const _TransactionItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
    final isDark = AurumConsumerTheme.isDark(context);

    final typeUpper = item.transactionType.toUpperCase();
    final isBuy = typeUpper == 'BUY';
    final isSell = typeUpper == 'SELL';
    final isCredit = item.transactionType.toLowerCase().contains('credit') ||
        item.transactionType.toLowerCase().contains('deposit') ||
        isBuy;

    final statusLower = item.status.toLowerCase();
    final isPaid = statusLower == 'paid' ||
        statusLower == 'completed' ||
        statusLower == 'success';
    final isFailed = statusLower == 'failed' || statusLower == 'cancelled';

    final Color statusColor = isPaid
        ? const Color(0xFF10B981)
        : isFailed
            ? Colors.redAccent
            : const Color(0xFFB45309);

    final String statusText = isPaid
        ? context.l10n.filterSuccessful
        : isFailed
            ? context.l10n.filterFailed
            : context.l10n.filterPending;

    final title = isBuy
        ? (item.metal != null && item.metal!.toLowerCase().contains('silver')
            ? context.l10n.buySilver
            : context.l10n.buyGold)
        : isSell
            ? context.l10n.sellGold
            : item.transactionType.replaceAll('_', ' ').toUpperCase();

    final txRef = item.referenceId ?? item.id;
    final shortRef = txRef.length > 16 ? '${txRef.substring(0, 16)}...' : txRef;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Pill
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isBuy ? AppTheme.primaryGold : const Color(0xFFB45309))
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isBuy
                    ? Icons.add_shopping_cart_rounded
                    : isSell
                        ? Icons.sell_outlined
                        : Icons.receipt_long_outlined,
                color: isBuy ? AppTheme.primaryGold : const Color(0xFFB45309),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E1A14),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Amount and Quantity Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.amountInr != null
                          ? currencyFormatter.format(item.amountInr!)
                          : '—',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isCredit
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.white : const Color(0xFF1E1A14)),
                      ),
                    ),
                    if (item.quantityGrams != null)
                      Text(
                        '${item.quantityGrams!.toStringAsFixed(4)} g',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Date & Ref Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateFormatter.format(item.occurredAt.toLocal()),
                      style: TextStyle(
                        fontSize: 11,
                        color: AurumConsumerTheme.muted(context),
                      ),
                    ),
                    Text(
                      'ID: $shortRef',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: AurumConsumerTheme.muted(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
