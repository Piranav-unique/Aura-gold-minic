import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/navigation/app_navigation_utils.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
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

    return ResponsiveNavigationWrapper(
      title: 'Transaction Detail',
      child: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeleton(height: 400),
        ),
        error: (e, _) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Failed to load transaction',
          subtitle: '$e',
          actionLabel: 'Back',
          onAction: () => handleAppBack(context, '/transactions/$transactionId'),
        ),
        data: (detail) => WalletTransactionDetailContent(detail: detail),
      ),
    );
  }
}
