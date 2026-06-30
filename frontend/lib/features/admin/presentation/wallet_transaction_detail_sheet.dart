import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_wallet_provider.dart';

void openWalletTransactionDetail(BuildContext context, String transactionId) {
  context.push(
    '/transactions/wallet-transaction?id=${Uri.encodeComponent(transactionId)}',
  );
}

Future<void> showWalletTransactionDetailSheet(
  BuildContext context,
  WidgetRef ref,
  String transactionId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Consumer(
        builder: (context, ref, _) {
          final detailAsync = ref.watch(
            walletTransactionDetailProvider(transactionId),
          );
          return detailAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: PremiumSkeleton(height: 320),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load transaction: $e'),
            ),
            data: (detail) => WalletTransactionDetailContent(
              detail: detail,
              scrollController: scrollController,
            ),
          );
        },
      ),
    ),
  );
}

class WalletTransactionDetailContent extends StatelessWidget {
  final WalletTransactionDetail detail;
  final ScrollController? scrollController;

  const WalletTransactionDetailContent({
    super.key,
    required this.detail,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final theme = Theme.of(context);

    return Material(
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Transaction Detail',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail.id,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('User'),
          _row('Name', detail.userName),
          _row('Email', detail.userEmail),
          if (detail.userMobile != null) _row('Mobile', detail.userMobile!),
          const SizedBox(height: 16),
          _sectionTitle('Transaction'),
          _row('Date', dateFormat.format(detail.occurredAt.toLocal())),
          _row('Type', detail.transactionType),
          if (detail.metal != null) _row('Metal', detail.metal!),
          if (detail.quantityGrams != null)
            _row('Quantity', '${detail.quantityGrams!.toStringAsFixed(4)} g'),
          if (detail.ratePerGram != null)
            _row('Rate', '${currency.format(detail.ratePerGram)}/g'),
          if (detail.gstAmountInr != null)
            _row('GST', currency.format(detail.gstAmountInr)),
          if (detail.platformFeeInr != null)
            _row('Platform fee', currency.format(detail.platformFeeInr)),
          if (detail.totalAmountInr != null)
            _row('Total', currency.format(detail.totalAmountInr), bold: true),
          _row('Status', detail.status.toUpperCase()),
          if (detail.referenceId != null)
            _row('Reference', detail.referenceId!),
          if (detail.paymentDetails != null) ...[
            const SizedBox(height: 16),
            _sectionTitle('Razorpay'),
            if (detail.paymentDetails!['razorpay_order_id'] != null)
              _row('Order ID', '${detail.paymentDetails!['razorpay_order_id']}'),
            if (detail.paymentDetails!['razorpay_payment_id'] != null)
              _row(
                'Payment ID',
                '${detail.paymentDetails!['razorpay_payment_id']}',
              ),
            if (detail.paymentDetails!['merchant_settlement_inr'] != null)
              _row(
                'Merchant settlement',
                currency.format(
                  double.tryParse(
                        '${detail.paymentDetails!['merchant_settlement_inr']}',
                      ) ??
                      0,
                ),
              ),
          ],
          if (detail.sellDetails != null) ...[
            const SizedBox(height: 16),
            _sectionTitle('Sell inquiry'),
            if (detail.sellDetails!['message'] != null)
              _row('Message', '${detail.sellDetails!['message']}'),
            if (detail.adminNotes != null)
              _row('Admin response', detail.adminNotes!),
          ],
          if (detail.referralDetails != null) ...[
            const SizedBox(height: 16),
            _sectionTitle('Referral'),
            _row(
              'Scheme grams',
              '${detail.referralDetails!['scheme_grams']} g',
            ),
            _row(
              'Reward',
              currency.format(
                double.tryParse('${detail.referralDetails!['reward_inr']}') ??
                    0,
              ),
            ),
          ],
          if (detail.savingsDetails != null) ...[
            const SizedBox(height: 16),
            _sectionTitle('Savings scheme'),
            _row(
              'Target',
              '${detail.savingsDetails!['target_grams']} g',
            ),
            _row('Status', '${detail.savingsDetails!['scheme_status']}'),
          ],
          if (detail.statusHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Status history'),
            ...detail.statusHistory.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: AppTheme.primaryGold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.status.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            dateFormat.format(h.occurredAt.toLocal()),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (h.note != null && h.note!.isNotEmpty)
                            Text(h.note!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryGold,
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
