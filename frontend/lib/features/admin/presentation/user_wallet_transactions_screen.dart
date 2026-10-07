import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/navigation/app_navigation_utils.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/features/admin/domain/wallet_pagination.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_wallet_provider.dart';
import 'package:ags_gold/features/admin/presentation/wallet_transaction_detail_sheet.dart';

class UserWalletTransactionsScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserWalletTransactionsScreen({super.key, required this.userId});

  @override
  ConsumerState<UserWalletTransactionsScreen> createState() =>
      _UserWalletTransactionsScreenState();
}

class _UserWalletTransactionsScreenState
    extends ConsumerState<UserWalletTransactionsScreen> {
  int _page = 1;

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

  void _openFilterBottomSheet(BuildContext context) {
    String? tempType = ref.read(walletTxnTypeFilterProvider);
    String? tempMetal = ref.read(walletTxnMetalFilterProvider);
    String? tempStatus = ref.read(walletTxnStatusFilterProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Wallet Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1B18),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Activity Type
                  const Text(
                    'Activity Type',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _choiceChip('All', null, tempType, (v) => setModalState(() => tempType = v)),
                      _choiceChip('Buy', 'BUY', tempType, (v) => setModalState(() => tempType = v)),
                      _choiceChip('Sell', 'SELL', tempType, (v) => setModalState(() => tempType = v)),
                      _choiceChip('Referral', 'REFERRAL', tempType, (v) => setModalState(() => tempType = v)),
                      _choiceChip('Savings', 'SAVINGS', tempType, (v) => setModalState(() => tempType = v)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metal
                  const Text(
                    'Metal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _choiceChip('All', null, tempMetal, (v) => setModalState(() => tempMetal = v)),
                      _choiceChip('Gold', 'gold', tempMetal, (v) => setModalState(() => tempMetal = v)),
                      _choiceChip('Silver', 'silver', tempMetal, (v) => setModalState(() => tempMetal = v)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _choiceChip('All', null, tempStatus, (v) => setModalState(() => tempStatus = v)),
                      _choiceChip('Paid', 'paid', tempStatus, (v) => setModalState(() => tempStatus = v)),
                      _choiceChip('Pending', 'pending', tempStatus, (v) => setModalState(() => tempStatus = v)),
                      _choiceChip('Approved', 'approved', tempStatus, (v) => setModalState(() => tempStatus = v)),
                      _choiceChip('Rejected / Failed', 'rejected', tempStatus, (v) => setModalState(() => tempStatus = v)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              tempType = null;
                              tempMetal = null;
                              tempStatus = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ref.read(walletTxnTypeFilterProvider.notifier).update(tempType);
                            ref.read(walletTxnMetalFilterProvider.notifier).update(tempMetal);
                            ref.read(walletTxnStatusFilterProvider.notifier).update(tempStatus);
                            setState(() => _page = 1);
                            Navigator.pop(modalCtx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC59A27),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _choiceChip(
    String label,
    String? value,
    String? selectedValue,
    ValueChanged<String?> onSelected,
  ) {
    final isSelected = (selectedValue == value) ||
        (value != null && selectedValue != null && selectedValue.toLowerCase() == value.toLowerCase());
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: const Color(0xFFFEF3C7),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? const Color(0xFF92400E) : const Color(0xFF475569),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFFC59A27) : const Color(0xFFE2E8F0),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(walletUserDetailProvider(widget.userId));
    final typeFilter = ref.watch(walletTxnTypeFilterProvider);
    final metalFilter = ref.watch(walletTxnMetalFilterProvider);
    final statusFilter = ref.watch(walletTxnStatusFilterProvider);
    final txnQuery = (
      userId: widget.userId,
      page: _page,
      type: typeFilter,
      metal: metalFilter,
      status: statusFilter,
    );
    final txnsAsync = ref.watch(walletUserTransactionsFilteredProvider(txnQuery));
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final hasActiveFilters = typeFilter != null || metalFilter != null || statusFilter != null;

    return ResponsiveNavigationWrapper(
      title: 'Wallet Activity',
      child: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeleton(height: 300),
        ),
        error: (e, _) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Failed to load user',
          subtitle: '$e',
          actionLabel: 'Back',
          onAction: () => handleAppBack(
            context,
            '/admin/user-wallets/${widget.userId}/transactions',
          ),
        ),
        data: (detail) => Container(
          color: const Color(0xFFFAF7F2),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Wallet Activity',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFC59A27),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All buy, sell, referral and savings activity for this user.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),

                // Compact Combined Filter Bar
                Row(
                  children: [
                    // Activity Type dropdown button
                    PopupMenuButton<String?>(
                      initialValue: typeFilter,
                      onSelected: (val) {
                        ref.read(walletTxnTypeFilterProvider.notifier).update(val);
                        setState(() => _page = 1);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: null, child: Text('All Activity')),
                        const PopupMenuItem(value: 'BUY', child: Text('Buy')),
                        const PopupMenuItem(value: 'SELL', child: Text('Sell')),
                        const PopupMenuItem(value: 'REFERRAL', child: Text('Referral')),
                        const PopupMenuItem(value: 'SAVINGS', child: Text('Savings')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              typeFilter != null ? typeFilter.toUpperCase() : 'All Activity',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E1B18),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Filter Button
                    ElevatedButton.icon(
                      onPressed: () => _openFilterBottomSheet(context),
                      icon: const Icon(Icons.tune, size: 16),
                      label: Row(
                        children: [
                          const Text('Filters'),
                          if (hasActiveFilters) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${(typeFilter != null ? 1 : 0) + (metalFilter != null ? 1 : 0) + (statusFilter != null ? 1 : 0)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFC59A27),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasActiveFilters ? const Color(0xFFFFFBEB) : Colors.white,
                        foregroundColor: hasActiveFilters ? const Color(0xFFB45309) : const Color(0xFF1E1B18),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        side: BorderSide(
                          color: hasActiveFilters ? const Color(0xFFC59A27) : const Color(0xFFE2E8F0),
                          width: hasActiveFilters ? 1.5 : 1,
                        ),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),

                // Removable Active Filter Chips Underneath
                if (hasActiveFilters) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (typeFilter != null)
                        InputChip(
                          label: Text(typeFilter.toUpperCase()),
                          onDeleted: () {
                            ref.read(walletTxnTypeFilterProvider.notifier).update(null);
                            setState(() => _page = 1);
                          },
                          deleteIcon: const Icon(Icons.close, size: 14),
                          backgroundColor: const Color(0xFFFFFBEB),
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (metalFilter != null)
                        InputChip(
                          label: Text(metalFilter.toUpperCase()),
                          onDeleted: () {
                            ref.read(walletTxnMetalFilterProvider.notifier).update(null);
                            setState(() => _page = 1);
                          },
                          deleteIcon: const Icon(Icons.close, size: 14),
                          backgroundColor: const Color(0xFFFEF3C7),
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (statusFilter != null)
                        InputChip(
                          label: Text(statusFilter.toUpperCase()),
                          onDeleted: () {
                            ref.read(walletTxnStatusFilterProvider.notifier).update(null);
                            setState(() => _page = 1);
                          },
                          deleteIcon: const Icon(Icons.close, size: 14),
                          backgroundColor: const Color(0xFFFEF3C7),
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          visualDensity: VisualDensity.compact,
                        ),
                      TextButton(
                        onPressed: () {
                          ref.read(walletTxnTypeFilterProvider.notifier).update(null);
                          ref.read(walletTxnMetalFilterProvider.notifier).update(null);
                          ref.read(walletTxnStatusFilterProvider.notifier).update(null);
                          setState(() => _page = 1);
                        },
                        child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Color(0xFFC59A27))),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Transactions List
                Expanded(
                  child: txnsAsync.when(
                    loading: () => const PremiumSkeleton(height: 200),
                    error: (e, _) => EmptyStateWidget(
                      icon: Icons.error_outline,
                      title: 'Failed to load transactions',
                      subtitle: '$e',
                      onAction: () => ref.invalidate(
                        walletUserTransactionsFilteredProvider(txnQuery),
                      ),
                      actionLabel: 'Retry',
                    ),
                    data: (page) {
                      if (page.items.isEmpty) {
                        return const EmptyStateWidget(
                          icon: Icons.receipt_long_outlined,
                          title: 'No matching activity',
                          subtitle: 'Try adjusting your filters.',
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(
                            walletUserTransactionsFilteredProvider(txnQuery),
                          );
                          await ref.read(
                            walletUserTransactionsFilteredProvider(txnQuery).future,
                          );
                        },
                        child: ListView.separated(
                          itemCount: page.items.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index == page.items.length) {
                              return _pager(page);
                            }
                            final txn = page.items[index];
                            return _txnCard(txn, currency, dateFormat);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _txnCard(
    WalletTransactionItem txn,
    NumberFormat currency,
    DateFormat dateFormat,
  ) {
    final String displayId = (txn.referenceId != null && txn.referenceId!.isNotEmpty)
        ? txn.referenceId!
        : txn.id;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => openWalletTransactionDetail(context, txn.id),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Type & Status Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeBgColor(txn.transactionType),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      txn.transactionType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _typeTextColor(txn.transactionType),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusBgColor(txn.status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      txn.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _statusTextColor(txn.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Middle Row: Metal & Quantity + Date/Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (txn.metal != null || txn.quantityGrams != null)
                        Text(
                          '${(txn.metal ?? 'Metal').toUpperCase()} • ${txn.quantityGrams != null ? '${txn.quantityGrams!.toStringAsFixed(4)} g' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E1B18),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormat.format(txn.occurredAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),

              // Bottom Row: Amount & Transaction ID with Copy
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        txn.amountInr != null ? currency.format(txn.amountInr) : '—',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E1B18),
                        ),
                      ),
                    ],
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
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ID: ${displayId.length > 12 ? '${displayId.substring(0, 8)}...' : displayId}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: Color(0xFFC59A27),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pager(PaginatedWalletTransactions page) {
    final totalPages = (page.total / page.limit).ceil().clamp(1, 9999);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: _page > 1 ? () => setState(() => _page -= 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$_page / $totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: _page < totalPages ? () => setState(() => _page += 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
