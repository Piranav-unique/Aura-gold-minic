import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/presentation/providers/payment_settlements_provider.dart';

class PaymentSettlementsScreen extends ConsumerWidget {
  const PaymentSettlementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsAsync = ref.watch(paymentSettlementsProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return ResponsiveNavigationWrapper(
      title: 'Payment Settlements',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Settlements',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customer payments include 3% GST internally. Merchant settlement is after Razorpay fees.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: settlementsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.payments_outlined,
                      title: 'No paid purchases yet',
                      subtitle: 'Completed gold purchases will appear here.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(paymentSettlementsProvider);
                      await ref.read(paymentSettlementsProvider.future);
                    },
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final row = items[index];
                        final gross = _num(row['gross_amount_inr']);
                        final gst = _num(row['gst_amount_inr']);
                        final fee = _num(row['razorpay_fee_inr']);
                        final merchant = _num(row['merchant_settlement_inr']);
                        final grams = _num(row['grams']);
                        final paidAt = DateTime.tryParse(
                          row['paid_at'] as String? ?? '',
                        );

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (row['user_name'] as String?)
                                                        ?.isNotEmpty ==
                                                    true
                                                ? row['user_name'] as String
                                                : (row['user_email'] as String? ??
                                                    'Customer'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          if ((row['user_email'] as String?)
                                                  ?.isNotEmpty ==
                                              true)
                                            Text(
                                              row['user_email'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          if ((row['user_mobile'] as String?)
                                                  ?.isNotEmpty ==
                                              true)
                                            Text(
                                              row['user_mobile'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          if ((row['payment_method']
                                                      as String?)
                                                  ?.isNotEmpty ==
                                              true)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  top: 4),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE0E7FF),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                (row['payment_method']
                                                        as String)
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF3730A3),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      (row['metal'] as String? ?? '').toUpperCase(),
                                      style: TextStyle(
                                        color: AppTheme.primaryGold,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _line(
                                  'Customer paid',
                                  currency.format(gross),
                                  bold: true,
                                ),
                                _line('Gold credited', '${grams.toStringAsFixed(4)} g'),
                                _line('GST (3%, internal)', currency.format(gst)),
                                _line('Razorpay fee', currency.format(fee)),
                                const Divider(height: 20),
                                _line(
                                  'Merchant receives',
                                  currency.format(merchant),
                                  bold: true,
                                  color: AppTheme.emerald,
                                ),
                                if (paidAt != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    dateFormat.format(paidAt.toLocal()),
                                    style: TextStyle(
                                      fontSize: 12,
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
                        );
                      },
                    ),
                  );
                },
                loading: () => const PremiumSkeletonList(itemCount: 4),
                error: (error, _) => Center(child: Text('Failed to load: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _line(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
