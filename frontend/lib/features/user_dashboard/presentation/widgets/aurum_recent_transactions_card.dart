import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/user_statements_provider.dart';

class AurumRecentTransactionsCard extends ConsumerWidget {
  final VoidCallback onViewAll;

  const AurumRecentTransactionsCard({
    super.key,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statementsAsync = ref.watch(userStatementsProvider);
    final isDark = AurumConsumerTheme.isDark(context);
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurumConsumerTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AurumConsumerTheme.borderOf(context),
        ),
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
          // Header: Recent Transactions + View All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.primaryGold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1A14),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onViewAll,
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGold,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 15,
                      color: AppTheme.primaryGold,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          statementsAsync.when(
            data: (page) {
              if (page.items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.savings_outlined,
                          color: AppTheme.primaryGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start your savings journey',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E1A14),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your transactions will show up here',
                              style: TextStyle(
                                fontSize: 11,
                                color: AurumConsumerTheme.muted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Show up to the 5 most recent transactions
              final recentList = page.items.take(5).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentList.length,
                separatorBuilder: (_, _) => Divider(
                  height: 16,
                  color: AurumConsumerTheme.borderOf(context).withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  final item = recentList[index];
                  final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(item.occurredAt);
                  final isBuy = item.transactionType.toUpperCase() == 'BUY';
                  final isSell = item.transactionType.toUpperCase() == 'SELL';
                  final isCredit = item.transactionType.toLowerCase().contains('credit') ||
                      item.transactionType.toLowerCase().contains('deposit') ||
                      isBuy;
                  final title = isBuy
                      ? 'Buy ${item.metal ?? 'Gold'}'
                      : isSell
                          ? 'Sell Gold'
                          : item.transactionType.replaceAll('_', ' ').toUpperCase();
                  final amountStr = item.amountInr != null
                      ? currencyFormatter.format(item.amountInr!)
                      : (item.quantityGrams != null
                          ? '${item.quantityGrams!.toStringAsFixed(4)} g'
                          : '—');
                  final statusLower = item.status.toLowerCase();
                  final isPaid = statusLower == 'paid' || statusLower == 'completed' || statusLower == 'success';
                  final isFailed = statusLower == 'failed' || statusLower == 'cancelled';
                  final statusColor = isPaid
                      ? const Color(0xFF10B981)
                      : isFailed
                          ? Colors.redAccent
                          : const Color(0xFFB45309);
                  final statusLabel = isPaid
                      ? 'Successful'
                      : isFailed
                          ? 'Failed'
                          : 'Pending';

                  return Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: (isBuy ? AppTheme.primaryGold : const Color(0xFFB45309)).withValues(alpha: 0.15),
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
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E1A14),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: AurumConsumerTheme.muted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            amountStr,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: isCredit
                                  ? const Color(0xFF10B981)
                                  : (isDark ? Colors.white : const Color(0xFF1E1A14)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
