import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/navigation/app_navigation_utils.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/presentation/providers/deleted_users_provider.dart';
import 'package:ags_gold/features/admin/presentation/wallet_transaction_detail_sheet.dart';

class DeletedUserDetailScreen extends ConsumerWidget {
  final String userId;

  const DeletedUserDetailScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(deletedUserDetailProvider(userId));
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF1E1B18);
    final secondaryText = isDark ? Colors.white60 : const Color(0xFF64748B);

    return ResponsiveNavigationWrapper(
      title: 'Deleted User Details',
      child: detailAsync.when(
        loading: () => const _DeletedUserDetailSkeleton(),
        error: (err, _) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                const SizedBox(height: 16),
                Text(
                  'Failed to Load User Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$err',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: secondaryText),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => handleAppBack(context, '/admin/deleted-users'),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(deletedUserDetailProvider(userId)),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC59A27),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        data: (user) {
          final regDate = dateFormat.format(user.createdAt.toLocal());
          final delDate = user.deletedAt != null
              ? dateFormat.format(user.deletedAt!.toLocal())
              : 'Not recorded';
          final lastActivity = user.lastLoginAt != null
              ? dateFormat.format(user.lastLoginAt!.toLocal())
              : 'None recorded';
          final isKycVerified = user.kycStatus.toLowerCase() == 'verified';

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(deletedUserDetailProvider(userId));
              await ref.read(deletedUserDetailProvider(userId).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              children: [
                // Archived Notice Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFDC2626).withValues(alpha: 0.14)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFF87171).withValues(alpha: 0.35)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_clock_outlined,
                        size: 20,
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'READ-ONLY ARCHIVE: This user account has been soft-deleted. Historical records and transactions are preserved.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Account Information Card
                _buildCard(
                  context,
                  title: 'Customer Account Details',
                  children: [
                    _row(context, 'Full Name', user.fullName.isNotEmpty ? user.fullName : '—'),
                    _rowWithCopy(context, 'Customer ID', user.id),
                    _row(context, 'Email', user.email.isNotEmpty ? user.email : '—', isEmail: true),
                    if (user.mobileNumber != null && user.mobileNumber!.isNotEmpty)
                      _row(context, 'Mobile Number', user.mobileNumber!),
                    _rowWithBadge(
                      context,
                      'Account Status',
                      'DELETED',
                      isDark ? const Color(0xFFDC2626).withValues(alpha: 0.2) : const Color(0xFFFEE2E2),
                      isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                    ),
                    _rowWithBadge(
                      context,
                      'KYC Status',
                      user.kycStatus.toUpperCase(),
                      isKycVerified
                          ? (isDark
                              ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                              : const Color(0xFFDCFCE7))
                          : (isDark
                              ? const Color(0xFFD97706).withValues(alpha: 0.2)
                              : const Color(0xFFFEF3C7)),
                      isKycVerified
                          ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                          : (isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E)),
                    ),
                    _row(context, 'Registered On', regDate),
                    _row(context, 'Deleted On', delDate),
                    _row(context, 'Last Activity', lastActivity),
                  ],
                ),
                const SizedBox(height: 16),

                // Previous Wallet Holdings Card
                _buildCard(
                  context,
                  title: 'Previous Retained Wallet Balances',
                  children: [
                    _row(
                      context,
                      'Gold Balance',
                      '${user.wallet.goldBalanceGrams.toStringAsFixed(4)} g',
                      valueColor: const Color(0xFFC59A27),
                      bold: true,
                    ),
                    _row(
                      context,
                      'Silver Balance',
                      '${user.wallet.silverBalanceGrams.toStringAsFixed(4)} g',
                      bold: true,
                    ),
                    _row(
                      context,
                      'Total Invested',
                      currency.format(user.wallet.totalInrInvested),
                    ),
                    _row(
                      context,
                      'Wallet Cash Balance',
                      currency.format(user.wallet.walletBalanceInr),
                      valueColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                      bold: true,
                    ),
                    _row(
                      context,
                      'Savings Scheme',
                      user.wallet.savingsSchemeStatus.toUpperCase(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Historical Transactions & Payments Card
                _buildCard(
                  context,
                  title: 'Historical Transactions & Payments (${user.transactions.length})',
                  children: [
                    if (user.transactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No historical transactions found for this customer.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      )
                    else
                      ...user.transactions.map((txn) {
                        final txnDate = dateFormat.format(txn.occurredAt.toLocal());
                        final isBuy = txn.transactionType.toUpperCase() == 'BUY';
                        return InkWell(
                          onTap: () => openWalletTransactionDetail(context, txn.id),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBuy
                                        ? (isDark
                                            ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                                            : const Color(0xFFEFF6FF))
                                        : (isDark
                                            ? const Color(0xFFEA580C).withValues(alpha: 0.2)
                                            : const Color(0xFFFFF7ED)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    txn.transactionType.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: isBuy
                                          ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                                          : (isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        txn.quantityGrams != null
                                            ? '${txn.quantityGrams!.toStringAsFixed(4)} g ${txn.metal ?? ''}'
                                            : txn.id,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: primaryText,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        txnDate,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      txn.amountInr != null
                                          ? currency.format(txn.amountInr)
                                          : '—',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      txn.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2227) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: Color(0xFFC59A27),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  static Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
    bool isEmail = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? (isDark ? Colors.white : const Color(0xFF1E1B18)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _rowWithBadge(
    BuildContext context,
    String label,
    String badgeText,
    Color bgColor,
    Color textColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _rowWithCopy(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
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
                        color: isDark ? Colors.white : const Color(0xFF1E1B18),
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

class _DeletedUserDetailSkeleton extends StatelessWidget {
  const _DeletedUserDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2227) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumSkeleton(width: 140, height: 16),
                const SizedBox(height: 14),
                for (int i = 0; i < 4; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: const [
                        PremiumSkeleton(width: 100, height: 14),
                        SizedBox(width: 16),
                        Expanded(child: PremiumSkeleton(height: 14)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
