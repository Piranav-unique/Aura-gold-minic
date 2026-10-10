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
      if (s == 'paid' || s == 'success' || s == 'completed') {
        return const Color(0xFF10B981).withValues(alpha: 0.2);
      }
      if (s == 'pending') return const Color(0xFFD4AF37).withValues(alpha: 0.2);
      if (s == 'approved') return const Color(0xFF3B82F6).withValues(alpha: 0.2);
      if (s == 'rejected' || s == 'failed') {
        return const Color(0xFFF43F5E).withValues(alpha: 0.2);
      }
      return const Color(0xFF94A3B8).withValues(alpha: 0.2);
    }
    if (s == 'paid' || s == 'success' || s == 'completed') return const Color(0xFFDCFCE7);
    if (s == 'pending') return const Color(0xFFFEF3C7);
    if (s == 'approved') return const Color(0xFFDBEAFE);
    if (s == 'rejected' || s == 'failed') return const Color(0xFFFEE2E2);
    return const Color(0xFFF1F5F9);
  }

  Color _statusTextColor(String status, bool isDark) {
    final s = status.toLowerCase();
    if (isDark) {
      if (s == 'paid' || s == 'success' || s == 'completed') return const Color(0xFF34D399);
      if (s == 'pending') return const Color(0xFFFDE68A);
      if (s == 'approved') return const Color(0xFF93C5FD);
      if (s == 'rejected' || s == 'failed') return const Color(0xFFFDA4AF);
      return const Color(0xFFCBD5E1);
    }
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
    final outerTheme = Theme.of(context);
    final isDark = outerTheme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? outerTheme.cardColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final sheetIsDark = theme.brightness == Brightness.dark;
            final textPrimary = sheetIsDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18);
            final textMuted = sheetIsDark
                ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
                : const Color(0xFF64748B);

            return SafeArea(
              top: false,
              child: Padding(
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
                          color: sheetIsDark ? theme.dividerColor : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Wallet Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
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
                    Text(
                      'Activity Type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip(context, 'All', null, tempType, (v) => setModalState(() => tempType = v)),
                        _choiceChip(context, 'Buy', 'BUY', tempType, (v) => setModalState(() => tempType = v)),
                        _choiceChip(context, 'Sell', 'SELL', tempType, (v) => setModalState(() => tempType = v)),
                        _choiceChip(context, 'Referral', 'REFERRAL', tempType, (v) => setModalState(() => tempType = v)),
                        _choiceChip(context, 'Savings', 'SAVINGS', tempType, (v) => setModalState(() => tempType = v)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Metal
                    Text(
                      'Metal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip(context, 'All', null, tempMetal, (v) => setModalState(() => tempMetal = v)),
                        _choiceChip(context, 'Gold', 'gold', tempMetal, (v) => setModalState(() => tempMetal = v)),
                        _choiceChip(context, 'Silver', 'silver', tempMetal, (v) => setModalState(() => tempMetal = v)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Status
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip(context, 'All', null, tempStatus, (v) => setModalState(() => tempStatus = v)),
                        _choiceChip(context, 'Paid', 'paid', tempStatus, (v) => setModalState(() => tempStatus = v)),
                        _choiceChip(context, 'Pending', 'pending', tempStatus, (v) => setModalState(() => tempStatus = v)),
                        _choiceChip(context, 'Approved', 'approved', tempStatus, (v) => setModalState(() => tempStatus = v)),
                        _choiceChip(context, 'Rejected / Failed', 'rejected', tempStatus, (v) => setModalState(() => tempStatus = v)),
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
                              side: BorderSide(
                                color: sheetIsDark ? theme.dividerColor : const Color(0xFFCBD5E1),
                              ),
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _choiceChip(
    BuildContext context,
    String label,
    String? value,
    String? selectedValue,
    ValueChanged<String?> onSelected,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = (selectedValue == value) ||
        (value != null && selectedValue != null && selectedValue.toLowerCase() == value.toLowerCase());
    final selectedBg = isDark
        ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
        : const Color(0xFFFEF3C7);
    final unselectedBg = isDark ? const Color(0xFF1A2432) : const Color(0xFFF1EDE3);
    final selectedFg = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
    final unselectedFg = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF475569);
    final borderColor = isSelected
        ? (isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27))
        : (isDark ? theme.dividerColor : const Color(0xFFE2E8F0));

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: selectedBg,
      backgroundColor: unselectedBg,
      checkmarkColor: selectedFg,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? selectedFg : unselectedFg,
      ),
      side: BorderSide(color: borderColor),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
          color: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFFAF7F2),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Wallet Activity',
                  style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail.fullName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All buy, sell, referral and savings activity for this user.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                          color: isDark ? theme.cardColor : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? theme.dividerColor : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              typeFilter != null ? typeFilter.toUpperCase() : 'All Activity',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 20,
                              color: isDark
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
                                  : const Color(0xFF64748B),
                            ),
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
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A2432) : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${(typeFilter != null ? 1 : 0) + (metalFilter != null ? 1 : 0) + (statusFilter != null ? 1 : 0)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasActiveFilters
                            ? (isDark
                                ? const Color(0xFFD4AF37).withValues(alpha: 0.16)
                                : const Color(0xFFFFFBEB))
                            : (isDark ? theme.cardColor : Colors.white),
                        foregroundColor: hasActiveFilters
                            ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
                            : (isDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        side: BorderSide(
                          color: hasActiveFilters
                              ? (isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27))
                              : (isDark ? theme.dividerColor : const Color(0xFFE2E8F0)),
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
                          backgroundColor: isDark
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.18)
                              : const Color(0xFFFFFBEB),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                          side: BorderSide(
                            color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFF59E0B),
                          ),
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
                          backgroundColor: isDark
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.18)
                              : const Color(0xFFFEF3C7),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                          side: BorderSide(
                            color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFF59E0B),
                          ),
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
                          backgroundColor: isDark
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.18)
                              : const Color(0xFFFEF3C7),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                          side: BorderSide(
                            color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFF59E0B),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      TextButton(
                        onPressed: () {
                          ref.read(walletTxnTypeFilterProvider.notifier).update(null);
                          ref.read(walletTxnMetalFilterProvider.notifier).update(null);
                          ref.read(walletTxnStatusFilterProvider.notifier).update(null);
                          setState(() => _page = 1);
                        },
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27),
                          ),
                        ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18);
    final textMuted = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
        : const Color(0xFF64748B);
    final cardBorder = isDark ? theme.dividerColor : const Color(0xFFE2E8F0);
    final String displayId = (txn.referenceId != null && txn.referenceId!.isNotEmpty)
        ? txn.referenceId!
        : txn.id;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorder),
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
                      color: _typeBgColor(txn.transactionType, isDark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      txn.transactionType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _typeTextColor(txn.transactionType, isDark),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusBgColor(txn.status, isDark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      txn.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _statusTextColor(txn.status, isDark),
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormat.format(txn.occurredAt.toLocal()),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: textMuted,
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
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 11,
                          color: textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        txn.amountInr != null ? currency.format(txn.amountInr) : '—',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
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
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27),
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
