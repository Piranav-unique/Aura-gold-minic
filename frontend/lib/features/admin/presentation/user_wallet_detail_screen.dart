import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/navigation/app_navigation_utils.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_data_table.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/features/admin/domain/wallet_pagination.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_wallet_provider.dart';
import 'package:ags_gold/features/admin/presentation/wallet_transaction_detail_sheet.dart';
import 'package:ags_gold/services/service_providers.dart';

class UserWalletDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserWalletDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<UserWalletDetailScreen> createState() =>
      _UserWalletDetailScreenState();
}

class _UserWalletDetailScreenState extends ConsumerState<UserWalletDetailScreen> {
  int _txnPage = 1;

  Future<void> _confirmDeleteUserWallet(
    WalletUserDetail detail,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer Wallet?'),
        content: Text(
          'Are you sure you want to delete ${detail.fullName}\'s wallet (${detail.mobileNumber ?? detail.email})? This user will be removed from the admin dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Wallet'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final api = ref.read(apiClientProvider);
        await api.delete('/admin/wallets/users/${detail.id}');
        ref.invalidate(walletUsersListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${detail.fullName} wallet deleted successfully.'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete user wallet: $e'),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(walletUserDetailProvider(widget.userId));
    final txnQuery = (userId: widget.userId, page: _txnPage);
    final txnsAsync = ref.watch(walletUserTransactionsProvider(txnQuery));
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isWide = ResponsiveLayout.isTablet(context) || isDesktop;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return ResponsiveNavigationWrapper(
      title: 'User Wallet',
      child: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeleton(height: 400),
        ),
        error: (e, _) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Failed to load wallet',
          subtitle: '$e',
          actionLabel: 'Back',
          onAction: () => handleAppBack(context, '/admin/user-wallets/${widget.userId}'),
        ),
        data: (detail) => Padding(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      detail.fullName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDeleteUserWallet(detail),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    label: const Text('Delete Wallet', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/admin/payment-settlements?mobile=${Uri.encodeComponent(detail.mobileNumber ?? '')}',
                    ),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Customer Payments'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _userInfoCard(detail, dateFormat),
                                  const SizedBox(height: 16),
                                  _walletSummaryCard(detail, currency),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: _transactionsSection(
                              detail.fullName,
                              txnsAsync,
                              currency,
                              dateFormat,
                              isDesktop,
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          _userInfoCard(detail, dateFormat),
                          const SizedBox(height: 16),
                          _walletSummaryCard(detail, currency),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 480,
                            child: _transactionsSection(
                              detail.fullName,
                              txnsAsync,
                              currency,
                              dateFormat,
                              isDesktop,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userInfoCard(WalletUserDetail detail, DateFormat dateFormat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User details',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('Full name', detail.fullName),
            _infoRow('Mobile', detail.mobileNumber ?? '—'),
            _infoRow('Email', detail.email, isEmail: true),
            _infoRow('KYC status', detail.kycStatus == 'not_started' ? 'Not Started' : detail.kycStatus),
            _infoRow(
              'Aadhaar',
              detail.kycAadhaarLast4 != null
                  ? '****${detail.kycAadhaarLast4}'
                  : '—',
            ),
            _infoRow(
              'PAN',
              detail.kycPanLast4 != null ? '****${detail.kycPanLast4}' : '—',
            ),
            _infoRow('Created', dateFormat.format(detail.createdAt.toLocal())),
            _infoRow(
              'Account',
              detail.isActive ? 'Active' : 'Inactive',
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletSummaryCard(WalletUserDetail detail, NumberFormat currency) {
    final w = detail.wallet;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wallet summary',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('Gold balance', '${w.goldBalanceGrams.toStringAsFixed(4)} g'),
            _infoRow('Gold valuation', currency.format(w.walletBalanceInr)),
            _infoRow(
              'Silver balance',
              '${w.silverBalanceGrams.toStringAsFixed(4)} g',
            ),
            _infoRow('Total INR invested', currency.format(w.totalInrInvested)),
            _infoRow(
              'Total bought',
              '${w.totalBoughtGrams.toStringAsFixed(4)} g',
            ),
            _infoRow(
              'Total sold',
              '${w.totalSoldGrams.toStringAsFixed(4)} g',
            ),
            _infoRow(
              'Pending sell inquiries',
              '${w.pendingSellInquiries}',
            ),
            _infoRow(
              'Referral cash reward',
              '${currency.format(w.referralRewardInr)} (${w.referralRewardGrams.toStringAsFixed(0)} g scheme)',
            ),
            if (w.savingsSchemeTargetGrams != null)
              _infoRow(
                'Savings scheme',
                '${w.savingsSchemeTargetGrams!.toStringAsFixed(0)} g • ${w.savingsSchemeStatus}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isEmail = false}) {
    final displayValue = isEmail
        ? value.replaceAll('@', '@\u200B').replaceAll('.', '.\u200B')
        : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionsSection(
    String userFullName,
    AsyncValue<PaginatedWalletTransactions> txnsAsync,
    NumberFormat currency,
    DateFormat dateFormat,
    bool isDesktop,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Transactions',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push(
                    '/admin/user-wallets/${widget.userId}/transactions',
                  ),
                  child: const Text('View in Transactions'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: txnsAsync.when(
                loading: () => const PremiumSkeleton(height: 160),
                error: (e, _) => Text('Error: $e'),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions',
                      subtitle: 'This user has no wallet activity yet.',
                    );
                  }
                  if (!isDesktop) {
                    return ListView.builder(
                      itemCount: page.items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == page.items.length) {
                          return _txnPager(page);
                        }
                        final txn = page.items[index];
                        final displayId = (txn.referenceId != null && txn.referenceId!.isNotEmpty) ? txn.referenceId! : txn.id;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: InkWell(
                            onTap: () => openWalletTransactionDetail(context, txn.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${txn.transactionType.toUpperCase()} ${txn.metal != null ? '• ${txn.metal!.toUpperCase()}' : ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: Color(0xFF1E1B18),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          txn.status.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormat.format(txn.occurredAt.toLocal()),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        txn.amountInr != null ? currency.format(txn.amountInr) : '—',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1E1B18),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: displayId));
                                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Transaction ID copied'),
                                              duration: Duration(seconds: 2),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'ID: ${displayId.length > 10 ? '${displayId.substring(0, 8)}...' : displayId}',
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.copy_rounded, size: 12, color: Color(0xFFC59A27)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: PremiumDataTable<WalletTransactionItem>(
                          items: page.items,
                          columns: [
                            DataTableColumn(
                              label: 'Date',
                              cellBuilder: (t) => Text(
                                dateFormat.format(t.occurredAt.toLocal()),
                              ),
                            ),
                            DataTableColumn(
                              label: 'Type',
                              cellBuilder: (t) => Text(t.transactionType),
                            ),
                            DataTableColumn(
                              label: 'Metal',
                              cellBuilder: (t) => Text(t.metal ?? '—'),
                            ),
                            DataTableColumn(
                              label: 'Grams',
                              cellBuilder: (t) => Text(
                                t.quantityGrams?.toStringAsFixed(4) ?? '—',
                              ),
                            ),
                            DataTableColumn(
                              label: 'Amount',
                              cellBuilder: (t) => Text(
                                t.amountInr != null
                                    ? currency.format(t.amountInr)
                                    : '—',
                              ),
                            ),
                            DataTableColumn(
                              label: 'Status',
                              cellBuilder: (t) => Text(t.status),
                            ),
                            DataTableColumn(
                              label: '',
                              cellBuilder: (t) => IconButton(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                onPressed: () =>
                                    openWalletTransactionDetail(context, t.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _txnPager(page),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _txnPager(PaginatedWalletTransactions page) {
    final totalPages = (page.total / page.limit).ceil().clamp(1, 9999);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: _txnPage > 1
              ? () => setState(() => _txnPage -= 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('$_txnPage / $totalPages'),
        IconButton(
          onPressed: _txnPage < totalPages
              ? () => setState(() => _txnPage += 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
