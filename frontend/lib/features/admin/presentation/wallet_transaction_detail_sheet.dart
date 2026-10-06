import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

  Color _typeBgColor(String type) {
    final t = type.toUpperCase();
    if (t == 'BUY') return const Color(0xFFEFF6FF);
    if (t == 'SELL') return const Color(0xFFFFF7ED);
    if (t == 'REFERRAL') return const Color(0xFFF3E8FF);
    if (t == 'SAVINGS') return const Color(0xFFECFDF5);
    return const Color(0xFFF1F5F9);
  }

  Color _typeTextColor(String type) {
    final t = type.toUpperCase();
    if (t == 'BUY') return const Color(0xFF1D4ED8);
    if (t == 'SELL') return const Color(0xFFC2410C);
    if (t == 'REFERRAL') return const Color(0xFF7E22CE);
    if (t == 'SAVINGS') return const Color(0xFF047857);
    return const Color(0xFF475569);
  }

  Color _statusBgColor(String status) {
    final s = status.toLowerCase();
    if (s == 'paid' || s == 'success' || s == 'completed') return const Color(0xFFDCFCE7);
    if (s == 'pending') return const Color(0xFFFEF3C7);
    if (s == 'approved') return const Color(0xFFDBEAFE);
    if (s == 'rejected' || s == 'failed') return const Color(0xFFFEE2E2);
    return const Color(0xFFF1F5F9);
  }

  Color _statusTextColor(String status) {
    final s = status.toLowerCase();
    if (s == 'paid' || s == 'success' || s == 'completed') return const Color(0xFF166534);
    if (s == 'pending') return const Color(0xFF92400E);
    if (s == 'approved') return const Color(0xFF1E40AF);
    if (s == 'rejected' || s == 'failed') return const Color(0xFF991B1B);
    return const Color(0xFF475569);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final theme = Theme.of(context);

    final String? paymentMode = detail.paymentDetails != null && detail.paymentDetails!['payment_method'] != null
        ? '${detail.paymentDetails!['payment_method']}'.toUpperCase()
        : null;

    final String displayId = (detail.referenceId != null && detail.referenceId!.isNotEmpty)
        ? detail.referenceId!
        : detail.id;

    return Material(
      color: const Color(0xFFFAF7F2),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (scrollController != null)
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

          // Top Header: Title & Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction Details',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1B18),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _typeBgColor(detail.transactionType),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      detail.transactionType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _typeTextColor(detail.transactionType),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusBgColor(detail.status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      detail.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _statusTextColor(detail.status),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Summary Card (White, rounded)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.metal != null || detail.quantityGrams != null) ...[
                  Text(
                    detail.metal != null ? detail.metal!.toUpperCase() : 'METAL',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail.quantityGrams != null ? '${detail.quantityGrams!.toStringAsFixed(4)} g' : '—',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1B18),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  (detail.status.toLowerCase() == 'pending' && detail.transactionType.toUpperCase() == 'SELL')
                      ? 'Requested Amount'
                      : 'Amount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail.amountInr != null
                      ? currency.format(detail.amountInr)
                      : (detail.totalAmountInr != null ? currency.format(detail.totalAmountInr) : '—'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Transaction Information Section
          _buildCard(
            title: 'Transaction information',
            children: [
              if (detail.metal != null)
                _row('Metal', detail.metal!.toUpperCase()),
              if (detail.quantityGrams != null)
                _row('Quantity', '${detail.quantityGrams!.toStringAsFixed(4)} g'),
              if (detail.ratePerGram != null && detail.ratePerGram! > 0)
                _row('Rate', '${currency.format(detail.ratePerGram)}/g'),
              _row('Date', dateFormat.format(detail.occurredAt.toLocal())),
              if (paymentMode != null)
                _row('Payment Mode', paymentMode),
              if (detail.gstAmountInr != null && detail.gstAmountInr! > 0)
                _row('GST Amount', currency.format(detail.gstAmountInr)),
              if (detail.platformFeeInr != null && detail.platformFeeInr! > 0)
                _row('Platform Fee', currency.format(detail.platformFeeInr)),
              _rowWithCopy(context, 'Transaction ID', displayId),
            ],
          ),

          // Customer Information Section
          const SizedBox(height: 14),
          _buildCard(
            title: 'Customer information',
            children: [
              _row('Customer Name', detail.userName),
              _row('Email', detail.userEmail, isEmail: true),
              if (detail.userMobile != null && detail.userMobile!.isNotEmpty)
                _row('Mobile', detail.userMobile!),
            ],
          ),

          // Payment / Razorpay Details
          if (detail.paymentDetails != null && detail.paymentDetails!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCard(
              title: 'Payment Details',
              children: [
                if (detail.paymentDetails!['razorpay_payment_id'] != null)
                  _rowWithCopy(
                    context,
                    'Payment ID',
                    '${detail.paymentDetails!['razorpay_payment_id']}',
                  ),
                if (detail.paymentDetails!['razorpay_order_id'] != null)
                  _rowWithCopy(
                    context,
                    'Order ID',
                    '${detail.paymentDetails!['razorpay_order_id']}',
                  ),
                if (detail.paymentDetails!['merchant_settlement_inr'] != null)
                  _row(
                    'Merchant Receives',
                    currency.format(
                      double.tryParse(
                            '${detail.paymentDetails!['merchant_settlement_inr']}',
                          ) ??
                          0,
                    ),
                    bold: true,
                    valueColor: const Color(0xFF16A34A),
                  ),
              ],
            ),
          ],

          // Sell Inquiry Details
          if (detail.sellDetails != null && detail.sellDetails!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCard(
              title: 'Sell Inquiry Information',
              children: [
                if (detail.sellDetails!['message'] != null)
                  _row('User Note', '${detail.sellDetails!['message']}'),
                if (detail.adminNotes != null && detail.adminNotes!.isNotEmpty)
                  _row('Admin Response', detail.adminNotes!),
              ],
            ),
          ],

          // Referral Details
          if (detail.referralDetails != null && detail.referralDetails!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCard(
              title: 'Referral Details',
              children: [
                if (detail.referralDetails!['scheme_grams'] != null)
                  _row(
                    'Scheme Grams',
                    '${detail.referralDetails!['scheme_grams']} g',
                  ),
                if (detail.referralDetails!['reward_inr'] != null)
                  _row(
                    'Reward',
                    currency.format(
                      double.tryParse('${detail.referralDetails!['reward_inr']}') ?? 0,
                    ),
                  ),
              ],
            ),
          ],

          // Savings Details
          if (detail.savingsDetails != null && detail.savingsDetails!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCard(
              title: 'Savings Scheme Information',
              children: [
                if (detail.savingsDetails!['target_grams'] != null)
                  _row(
                    'Target Grams',
                    '${detail.savingsDetails!['target_grams']} g',
                  ),
                if (detail.savingsDetails!['scheme_status'] != null)
                  _row('Status', '${detail.savingsDetails!['scheme_status']}'),
              ],
            ),
          ],

          // Status History Timeline
          if (detail.statusHistory.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCard(
              title: 'Status History',
              children: [
                ...detail.statusHistory.map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 8,
                          color: Color(0xFFC59A27),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.status.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFF1E1B18),
                                ),
                              ),
                              Text(
                                dateFormat.format(h.occurredAt.toLocal()),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (h.note != null && h.note!.isNotEmpty)
                                Text(
                                  h.note!,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFFC59A27),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
    bool isEmail = false,
  }) {
    final displayValue = isEmail
        ? value.replaceAll('@', '@\u200B').replaceAll('.', '.\u200B')
        : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? const Color(0xFF1E1B18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowWithCopy(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction ID copied'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1B18),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: Color(0xFFC59A27),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
