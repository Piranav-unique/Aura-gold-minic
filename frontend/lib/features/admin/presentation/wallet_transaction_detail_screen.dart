import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/navigation/app_navigation_utils.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_wallet_provider.dart';
import 'package:ags_gold/features/admin/presentation/wallet_transaction_detail_sheet.dart';

class WalletTransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const WalletTransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(walletTransactionDetailProvider(transactionId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ResponsiveNavigationWrapper(
      title: 'Transaction Detail',
      child: detailAsync.when(
        loading: () => const _TransactionDetailLoadingSkeleton(),
        error: (e, _) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFF43F5E).withValues(alpha: 0.2)
                        : const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 32,
                    color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to Load Transaction',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
                        : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => handleAppBack(context, '/transactions'),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(walletTransactionDetailProvider(transactionId)),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC59A27),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        data: (detail) => WalletTransactionDetailContent(detail: detail),
      ),
    );
  }
}

class _TransactionDetailLoadingSkeleton extends StatelessWidget {
  const _TransactionDetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? theme.cardColor : Colors.white;
    final cardBorder = isDark ? theme.dividerColor : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PremiumSkeleton(width: 160, height: 24),
              PremiumSkeleton(width: 70, height: 24),
            ],
          ),
          const SizedBox(height: 16),

          // Main amount card shimmer
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSkeleton(width: 80, height: 14),
                SizedBox(height: 8),
                PremiumSkeleton(width: 140, height: 28),
                SizedBox(height: 14),
                PremiumSkeleton(width: 60, height: 12),
                SizedBox(height: 6),
                PremiumSkeleton(width: 120, height: 22),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Transaction Information Card shimmer
          _buildCardSkeleton(context, titleWidth: 150, rows: 4),
          const SizedBox(height: 14),

          // Customer Information Card shimmer
          _buildCardSkeleton(context, titleWidth: 140, rows: 3),
          const SizedBox(height: 14),

          // Payment Details Card shimmer
          _buildCardSkeleton(context, titleWidth: 120, rows: 3),
        ],
      ),
    );
  }

  static Widget _buildCardSkeleton(
    BuildContext context, {
    required double titleWidth,
    required int rows,
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
          PremiumSkeleton(width: titleWidth, height: 16),
          const SizedBox(height: 14),
          for (int i = 0; i < rows; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  PremiumSkeleton(width: 100, height: 14),
                  SizedBox(width: 16),
                  Expanded(
                    child: PremiumSkeleton(height: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
