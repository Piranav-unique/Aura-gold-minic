import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:ags_gold/services/service_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  bool _isSyncingRazorpay = false;

  // Search controllers
  final _appSearchController = TextEditingController();
  Timer? _appDebounce;

  Future<void> _syncWithRazorpay() async {
    setState(() => _isSyncingRazorpay = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/payments/razorpay/sync-all');
      ref.invalidate(walletUsersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customers & payments synchronized from Razorpay!'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync note: $e'),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingRazorpay = false);
    }
  }

  Future<void> _confirmDeleteCustomer(WalletUserSearchItem user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer Wallet?'),
        content: Text(
          'Are you sure you want to remove ${user.fullName} (${user.mobileNumber ?? user.email})? This user wallet will be removed from the admin dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final api = ref.read(apiClientProvider);
        await api.delete('/admin/wallets/users/${user.id}');
        ref.invalidate(walletUsersListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.fullName} wallet removed successfully.'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete customer: $e'),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  @override
  void dispose() {
    _appDebounce?.cancel();
    _appSearchController.dispose();
    super.dispose();
  }

  void _onAppSearchChanged(String value) {
    _appDebounce?.cancel();
    _appDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(walletUserSearchQueryProvider.notifier).update(value);
      ref.read(walletUsersPageProvider.notifier).update(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, yyyy');

    return ResponsiveNavigationWrapper(
      title: 'Customers',
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: _buildAppCustomersTab(isDesktop, currency, dateFormat),
      ),
    );
  }

  // ==========================================
  // TAB 1: APP CUSTOMERS (RETAIL END-USERS)
  // ==========================================

  Widget _buildAppCustomersTab(
    bool isDesktop,
    NumberFormat currency,
    DateFormat dateFormat,
  ) {
    final usersAsync = ref.watch(walletUsersListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App Customer Search Bar + Sync with Razorpay Button
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _appSearchController,
                decoration: InputDecoration(
                  hintText: 'Search customers by name, mobile, email, KYC…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _appSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _appSearchController.clear();
                            ref.read(walletUserSearchQueryProvider.notifier).update('');
                            ref.read(walletUsersPageProvider.notifier).update(1);
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _onAppSearchChanged,
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16 : 12,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSyncingRazorpay
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(
                isDesktop ? 'Sync with Razorpay' : 'Sync',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _isSyncingRazorpay ? null : _syncWithRazorpay,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: usersAsync.when(
            loading: () => const PremiumSkeletonList(itemCount: 6),
            error: (e, _) => EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Unable to load app customers',
              subtitle: '$e',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(walletUsersListProvider),
            ),
            data: (page) {
              final cleanItems = page.items.where((u) {
                final email = u.email.toLowerCase();
                final name = u.fullName.toLowerCase();
                final mobile = u.mobileNumber ?? '';
                if (email.contains('superadmin') || email.contains('admin@agsgold')) return false;
                if (name.contains('super admin') || name.contains('superadmin')) return false;
                if (mobile.contains('9943795005')) return false;
                return true;
              }).toList();
              final filteredPage = PaginatedWalletUsers(
                items: cleanItems,
                total: page.total,
                skip: page.skip,
                limit: page.limit,
              );

              if (cleanItems.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'No app customers found',
                  subtitle: _appSearchController.text.isNotEmpty
                      ? 'No customers match your search criteria.'
                      : 'Customers who register or purchase gold in the app will appear here.',
                  actionLabel: _appSearchController.text.isNotEmpty ? 'Clear Search' : null,
                  onAction: _appSearchController.text.isNotEmpty
                      ? () {
                          _appSearchController.clear();
                          ref.read(walletUserSearchQueryProvider.notifier).update('');
                          ref.read(walletUsersPageProvider.notifier).update(1);
                        }
                      : null,
                );
              }

              if (!isDesktop) {
                return RefreshIndicator(
                  onRefresh: () async {
                    try {
                      final api = ref.read(apiClientProvider);
                      await api.post('/payments/razorpay/sync-all');
                    } catch (_) {}
                    return ref.refresh(walletUsersListProvider.future);
                  },
                  child: ListView.builder(
                    itemCount: cleanItems.length + 1,
                    itemBuilder: (context, index) {
                      if (index == cleanItems.length) {
                        return _buildAppPagination(filteredPage);
                      }
                      return _buildAppCustomerMobileCard(cleanItems[index], dateFormat);
                    },
                  ),
                );
              }

              return _buildAppCustomersDesktop(filteredPage, dateFormat);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppCustomerMobileCard(
    WalletUserSearchItem user,
    DateFormat dateFormat,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/admin/user-wallets/${user.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.15),
                    child: Text(
                      _avatarInitials(user),
                      style: const TextStyle(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (user.mobileNumber != null && user.mobileNumber!.isNotEmpty)
                              user.mobileNumber!,
                            if (user.email.isNotEmpty &&
                                !user.email.contains('@aurum.local') &&
                                !user.email.contains('.local'))
                              user.email,
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.65),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    tooltip: 'Delete Customer Wallet',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDeleteCustomer(user),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _kycBadge(user.kycStatus),
                  _goldBadge('${user.goldBalanceGrams.toStringAsFixed(4)} g gold'),
                  if (user.silverBalanceGrams > 0)
                    _silverBadge('${user.silverBalanceGrams.toStringAsFixed(4)} g silver'),
                  Text(
                    'Joined ${dateFormat.format(user.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
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

  Widget _buildAppCustomersDesktop(
    PaginatedWalletUsers page,
    DateFormat dateFormat,
  ) {
    return Column(
      children: [
        Expanded(
          child: PremiumDataTable<WalletUserSearchItem>(
            items: page.items,
            columns: [
              DataTableColumn(
                label: 'Customer Name',
                cellBuilder: (u) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.15),
                      child: Text(
                        _avatarInitials(u),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      u.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              DataTableColumn(
                label: 'Mobile',
                cellBuilder: (u) => Text(u.mobileNumber ?? '—'),
              ),
              DataTableColumn(
                label: 'Email',
                cellBuilder: (u) => Text(
                  u.email.contains('@aurum.local') ? '—' : u.email,
                ),
              ),
              DataTableColumn(
                label: 'KYC Status',
                cellBuilder: (u) => _kycBadge(u.kycStatus),
              ),
              DataTableColumn(
                label: 'Gold Bought (g)',
                cellBuilder: (u) => _goldBadge('${u.goldBalanceGrams.toStringAsFixed(4)} g'),
              ),
              DataTableColumn(
                label: 'Silver Bought (g)',
                cellBuilder: (u) => u.silverBalanceGrams > 0
                    ? _silverBadge('${u.silverBalanceGrams.toStringAsFixed(4)} g')
                    : const Text('—'),
              ),
              DataTableColumn(
                label: 'Joined',
                cellBuilder: (u) => Text(dateFormat.format(u.createdAt)),
              ),
              DataTableColumn(
                label: 'Actions',
                cellBuilder: (u) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      tooltip: 'Delete Customer Wallet',
                      onPressed: () => _confirmDeleteCustomer(u),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'View Wallet Details',
                      onPressed: () => context.push('/admin/user-wallets/${u.id}'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildAppPagination(page),
      ],
    );
  }

  Widget _buildAppPagination(PaginatedWalletUsers page) {
    final currentPage = ref.watch(walletUsersPageProvider);
    final totalPages = (page.total / page.limit).ceil().clamp(1, 9999);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${page.total} customers registered',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              IconButton(
                onPressed: currentPage > 1
                    ? () => ref
                        .read(walletUsersPageProvider.notifier)
                        .update(currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$currentPage / $totalPages'),
              IconButton(
                onPressed: currentPage < totalPages
                    ? () => ref
                        .read(walletUsersPageProvider.notifier)
                        .update(currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }



  String _avatarInitials(WalletUserSearchItem user) {
    if (user.hasAssignedName) {
      final parts = user.fullName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    }
    return 'C';
  }

  Widget _kycBadge(String kycStatus) {
    Color color;
    IconData icon;
    String text;
    switch (kycStatus.toLowerCase()) {
      case 'verified':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        text = 'KYC Verified';
        break;
      case 'pending':
      case 'submitted':
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        text = 'KYC Pending';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel_outlined;
        text = 'KYC Rejected';
        break;
      default:
        color = Colors.grey;
        icon = Icons.shield_outlined;
        text = 'KYC Not Done';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goldBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC59A27).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFC59A27).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, size: 12, color: Color(0xFFC59A27)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFC59A27),
            ),
          ),
        ],
      ),
    );
  }

  Widget _silverBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.blueGrey,
        ),
      ),
    );
  }
}
