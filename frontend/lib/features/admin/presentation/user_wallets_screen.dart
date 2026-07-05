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

class UserWalletsScreen extends ConsumerStatefulWidget {
  const UserWalletsScreen({super.key});

  @override
  ConsumerState<UserWalletsScreen> createState() => _UserWalletsScreenState();
}

class _UserWalletsScreenState extends ConsumerState<UserWalletsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
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
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return ResponsiveNavigationWrapper(
      title: 'User Wallets',
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search end-users by name, mobile, email, or masked KYC (last 4 digits).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Name, mobile, email, Aadhaar/PAN last 4…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildUserSearch(isDesktop, currency, dateFormat),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSearch(
    bool isDesktop,
    NumberFormat currency,
    DateFormat dateFormat,
  ) {
    final usersAsync = ref.watch(walletUsersListProvider);
    return usersAsync.when(
      loading: () => const PremiumSkeleton(height: 200),
      error: (e, _) => EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Failed to load users',
        subtitle: '$e',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(walletUsersListProvider),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No users found',
            subtitle: 'Try a different search term.',
          );
        }
        if (!isDesktop) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(walletUsersListProvider.future),
            child: ListView.builder(
              itemCount: page.items.length + 1,
              itemBuilder: (context, index) {
                if (index == page.items.length) {
                  return _userPagination(page);
                }
                return _userMobileCard(page.items[index], currency);
              },
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: PremiumDataTable<WalletUserSearchItem>(
                items: page.items,
                columns: [
                  DataTableColumn(
                    label: 'Name',
                    cellBuilder: (u) => Text(
                      u.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataTableColumn(
                    label: 'Mobile',
                    cellBuilder: (u) => Text(u.mobileNumber ?? '—'),
                  ),
                  DataTableColumn(
                    label: 'Email',
                    cellBuilder: (u) => Text(u.email),
                  ),
                  DataTableColumn(
                    label: 'KYC',
                    cellBuilder: (u) => Text(u.kycStatus),
                  ),
                  DataTableColumn(
                    label: 'Gold (g)',
                    cellBuilder: (u) =>
                        Text(u.goldBalanceGrams.toStringAsFixed(4)),
                  ),
                  DataTableColumn(
                    label: 'INR wallet',
                    cellBuilder: (u) => Text(currency.format(u.walletBalanceInr)),
                  ),
                  DataTableColumn(
                    label: 'Status',
                    cellBuilder: (u) => Text(u.isActive ? 'Active' : 'Inactive'),
                  ),
                  DataTableColumn(
                    label: '',
                    cellBuilder: (u) => IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () =>
                          context.push('/admin/user-wallets/${u.id}'),
                    ),
                  ),
                ],
                onSort: null,
              ),
            ),
            _userPagination(page),
          ],
        );
      },
    );
  }

  Widget _userMobileCard(WalletUserSearchItem user, NumberFormat currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/admin/user-wallets/${user.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(user.email),
              if (user.mobileNumber != null) Text(user.mobileNumber!),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _chip('KYC: ${user.kycStatus}'),
                  _chip('${user.goldBalanceGrams.toStringAsFixed(4)} g gold'),
                  _chip(currency.format(user.walletBalanceInr)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _userPagination(PaginatedWalletUsers page) {
    final currentPage = ref.watch(walletUsersPageProvider);
    final totalPages = (page.total / page.limit).ceil().clamp(1, 9999);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${page.total} users'),
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
}
