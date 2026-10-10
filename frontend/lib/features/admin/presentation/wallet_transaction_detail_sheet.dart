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

  Color _typeBgColor(String type, bool isDark) {
    final t = type.toUpperCase();
    if (isDark) {
      if (t == 'BUY') return const Color(0xFF3B82F6).withValues(alpha: 0.2);
      if (t == 'SELL') return const Color(0xFFF97316).withValues(alpha: 0.2);
      if (t == 'REFERRAL') return const Color(0xFFA855F7).withValues(alpha: 0.2);
      if (t == 'SAVINGS') return const Color(0xFF10B981).withValues(alpha: 0.2);
      return const Color(0xFF94A3B8).withValues(alpha: 0.2);
    }
    if (t == 'BUY') return const Color(0xFFEFF6FF);
    if (t == 'SELL') return const Color(0xFFFFF7ED);
    if (t == 'REFERRAL') return const Color(0xFFF3E8FF);
    if (t == 'SAVINGS') return const Color(0xFFECFDF5);
    return const Color(0xFFF1F5F9);
  }

  Color _typeTextColor(String type, bool isDark) {
    final t = type.toUpperCase();
    if (isDark) {
      if (t == 'BUY') return const Color(0xFF93C5FD);
      if (t == 'SELL') return const Color(0xFFFDBA74);
      if (t == 'REFERRAL') return const Color(0xFFD8B4FE);
      if (t == 'SAVINGS') return const Color(0xFF6EE7B7);
      return const Color(0xFFCBD5E1);
    }
    if (t == 'BUY') return const Color(0xFF1D4ED8);
    if (t == 'SELL') return const Color(0xFFC2410C);
    if (t == 'REFERRAL') return const Color(0xFF7E22CE);
    if (t == 'SAVINGS') return const Color(0xFF047857);
    return const Color(0xFF475569);
  }

  Color _statusBgColor(String status, bool isDark) {
    final s = status.toLowerCase();
    if (isDark) {
      if (s == 'paid' || s == 'success' || s == 'completed' || s == 'captured') {
        return const Color(0xFF10B981).withValues(alpha: 0.2);
      }
      if (s == 'pending' || s == 'created' || s == 'processing') {
        return const Color(0xFFD4AF37).withValues(alpha: 0.2);
      }
      if (s == 'approved') return const Color(0xFF3B82F6).withValues(alpha: 0.2);
      if (s == 'rejected' || s == 'failed' || s == 'cancelled' || s == 'canceled') {
        return const Color(0xFFF43F5E).withValues(alpha: 0.2);
      }
      return const Color(0xFF94A3B8).withValues(alpha: 0.2);
    }
    if (s == 'paid' || s == 'success' || s == 'completed' || s == 'captured') return const Color(0xFFDCFCE7);
    if (s == 'pending' || s == 'created' || s == 'processing') return const Color(0xFFFEF3C7);
    if (s == 'approved') return const Color(0xFFDBEAFE);
    if (s == 'rejected' || s == 'failed' || s == 'cancelled' || s == 'canceled') return const Color(0xFFFEE2E2);
    return const Color(0xFFF1F5F9);
  }

  Color _statusTextColor(String status, bool isDark) {
    final s = status.toLowerCase();
    if (isDark) {
      if (s == 'paid' || s == 'success' || s == 'completed' || s == 'captured') {
        return const Color(0xFF34D399);
      }
      if (s == 'pending' || s == 'created' || s == 'processing') {
        return const Color(0xFFFDE68A);
      }
      if (s == 'approved') return const Color(0xFF93C5FD);
      if (s == 'rejected' || s == 'failed' || s == 'cancelled' || s == 'canceled') {
        return const Color(0xFFFDA4AF);
      }
      return const Color(0xFFCBD5E1);
    }
    if (s == 'paid' || s == 'success' || s == 'completed' || s == 'captured') return const Color(0xFF166534);
    if (s == 'pending' || s == 'created' || s == 'processing') return const Color(0xFF92400E);
    if (s == 'approved') return const Color(0xFF1E40AF);
    if (s == 'rejected' || s == 'failed' || s == 'cancelled' || s == 'canceled') return const Color(0xFF991B1B);
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
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18);
    final textMuted = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
        : const Color(0xFF64748B);
    final cardBg = isDark ? theme.cardColor : Colors.white;
    final cardBorder = isDark ? theme.dividerColor : const Color(0xFFE2E8F0);
    final goldAccent = isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27);
    final emeraldColor = isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A);

    final String? paymentMode = detail.paymentDetails != null && detail.paymentDetails!['payment_method'] != null
        ? '${detail.paymentDetails!['payment_method']}'.toUpperCase()
        : null;

    final String displayId = (detail.referenceId != null && detail.referenceId!.isNotEmpty)
        ? detail.referenceId!
        : detail.id;

    return Material(
      color: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFFAF7F2),
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
                  color: textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _typeBgColor(detail.transactionType, isDark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      detail.transactionType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _typeTextColor(detail.transactionType, isDark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusBgColor(detail.status, isDark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      detail.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _statusTextColor(detail.status, isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.metal != null || detail.quantityGrams != null) ...[
                  Text(
                    detail.metal != null ? detail.metal!.toUpperCase() : 'METAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail.quantityGrams != null ? '${detail.quantityGrams!.toStringAsFixed(4)} g' : '—',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  (detail.status.toLowerCase() == 'pending' && detail.transactionType.toUpperCase() == 'SELL')
                      ? 'Requested Amount'
                      : 'Amount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail.amountInr != null
                      ? currency.format(detail.amountInr)
                      : (detail.totalAmountInr != null ? currency.format(detail.totalAmountInr) : '—'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: emeraldColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Transaction Information Section
          _buildCard(
            context,
            title: 'Transaction information',
            children: [
              if (detail.metal != null)
                _row(context, 'Metal', detail.metal!.toUpperCase()),
              if (detail.quantityGrams != null)
                _row(context, 'Quantity', '${detail.quantityGrams!.toStringAsFixed(4)} g'),
              if (detail.ratePerGram != null && detail.ratePerGram! > 0)
                _row(context, 'Rate', '${currency.format(detail.ratePerGram)}/g'),
              _row(context, 'Date', dateFormat.format(detail.occurredAt.toLocal())),
              if (paymentMode != null)
                _row(context, 'Payment Mode', paymentMode),
              if (detail.gstAmountInr != null && detail.gstAmountInr! > 0)
                _row(context, 'GST Amount', currency.format(detail.gstAmountInr)),
              if (detail.platformFeeInr != null && detail.platformFeeInr! > 0)
                _row(context, 'Platform Fee', currency.format(detail.platformFeeInr)),
              _rowWithCopy(context, 'Transaction ID', displayId),
            ],
          ),

          // Customer Information Section
          const SizedBox(height: 14),
          _buildCard(
            context,
            title: 'Customer information',
            children: [
              _row(context, 'Customer Name', detail.userName.isNotEmpty ? detail.userName : '—'),
              if (detail.userId.isNotEmpty)
                _rowWithCopy(context, 'Customer ID', detail.userId),
              _row(context, 'Email', detail.userEmail.isNotEmpty ? detail.userEmail : '—', isEmail: true),
              if (detail.userMobile != null && detail.userMobile!.isNotEmpty)
                _row(context, 'Mobile', detail.userMobile!),
            ],
          ),

          // Payment / Razorpay Details
          if (detail.paymentDetails != null && detail.paymentDetails!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCard(
              context,
              title: 'Payment Details',
              children: [
                if (paymentMode != null)
                  _row(context, 'Payment Mode', paymentMode),
                if (detail.paymentDetails!['status'] != null)
                  _row(context, 'Payment Status', '${detail.paymentDetails!['status']}'.toUpperCase()),
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
                if (detail.paymentDetails!['bank_rrn'] != null && '${detail.paymentDetails!['bank_rrn']}'.isNotEmpty)
                  _rowWithCopy(
                    context,
                    'Bank RRN',
                    '${detail.paymentDetails!['bank_rrn']}',
                  ),
                if (detail.paymentDetails!['merchant_settlement_inr'] != null)
                  _row(
                    context,
                    'Merchant Receives',
                    double.tryParse('${detail.paymentDetails!['merchant_settlement_inr']}') != null
                        ? currency.format(
                            double.parse('${detail.paymentDetails!['merchant_settlement_inr']}'),
                          )
                        : '—',
                    bold: true,
                    valueColor: emeraldColor,
                  ),
                if (detail.paymentDetails!['razorpay_fee_inr'] != null)
                  _row(
                    context,
                    'Razorpay Fee',
                    double.tryParse('${detail.paymentDetails!['razorpay_fee_inr']}') != null
                        ? currency.format(
                            double.parse('${detail.paymentDetails!['razorpay_fee_inr']}'),
                          )
                        : '—',
                  ),
              ],
            ),
          ],

          // Sell Inquiry Details
          if (detail.sellDetails != null && detail.sellDetails!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCard(
              context,
              title: 'Sell Inquiry Information',
              children: [
                if (detail.sellDetails!['message'] != null)
                  _row(context, 'User Note', '${detail.sellDetails!['message']}'),
                if (detail.adminNotes != null && detail.adminNotes!.isNotEmpty)
                  _row(context, 'Admin Response', detail.adminNotes!),
              ],
            ),
          ],

          // Referral Details
          if (detail.referralDetails != null && detail.referralDetails!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCard(
              context,
              title: 'Referral Details',
              children: [
                if (detail.referralDetails!['referee_name'] != null &&
                    '${detail.referralDetails!['referee_name']}'.isNotEmpty)
                  _row(
                    context,
                    'Referred Customer',
                    '${detail.referralDetails!['referee_name']}',
                    bold: true,
                  ),
                if (detail.referralDetails!['referee_mobile'] != null &&
                    '${detail.referralDetails!['referee_mobile']}'.isNotEmpty)
                  _row(
                    context,
                    'Customer Mobile',
                    '${detail.referralDetails!['referee_mobile']}',
                  ),
                if (detail.referralDetails!['referrer_name'] != null &&
                    '${detail.referralDetails!['referrer_name']}'.isNotEmpty)
                  _row(
                    context,
                    'Referred By',
                    '${detail.referralDetails!['referrer_name']}',
                  ),
                if (detail.referralDetails!['referrer_mobile'] != null &&
                    '${detail.referralDetails!['referrer_mobile']}'.isNotEmpty)
                  _row(
                    context,
                    'Referrer Mobile',
                    '${detail.referralDetails!['referrer_mobile']}',
                  ),
                if (detail.referralDetails!['scheme_grams'] != null)
                  _row(
                    context,
                    'Scheme Grams',
                    '${detail.referralDetails!['scheme_grams']} g',
                  ),
                if (detail.referralDetails!['reward_inr'] != null)
                  _row(
                    context,
                    'Reward',
                    double.tryParse('${detail.referralDetails!['reward_inr']}') != null
                        ? currency.format(
                            double.parse('${detail.referralDetails!['reward_inr']}'),
                          )
                        : '—',
                  ),
              ],
            ),
          ],

          // Savings Details
          if (detail.savingsDetails != null && detail.savingsDetails!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCard(
              context,
              title: 'Savings Scheme Information',
              children: [
                if (detail.savingsDetails!['target_grams'] != null)
                  _row(
                    context,
                    'Target Grams',
                    '${detail.savingsDetails!['target_grams']} g',
                  ),
                if (detail.savingsDetails!['scheme_status'] != null)
                  _row(context, 'Status', '${detail.savingsDetails!['scheme_status']}'),
              ],
            ),
          ],

          // Status History Timeline
          if (detail.statusHistory.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCard(
              context,
              title: 'Status History',
              children: [
                ...detail.statusHistory.map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: goldAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.status.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                dateFormat.format(h.occurredAt.toLocal()),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textMuted,
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

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? theme.dividerColor : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
    bool isEmail = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
        : const Color(0xFF64748B);
    final defaultValueColor = isDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18);
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
              style: TextStyle(
                color: labelColor,
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
                color: valueColor ?? defaultValueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowWithCopy(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
        : const Color(0xFF64748B);
    final valueColor = isDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18);
    final copyColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
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
                  SnackBar(
                    content: Text('$label copied to clipboard'),
                    duration: const Duration(seconds: 2),
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
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: valueColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: copyColor,
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
