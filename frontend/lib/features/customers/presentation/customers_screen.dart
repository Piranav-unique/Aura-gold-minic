import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/filter_chip_bar.dart';
import 'package:ags_gold/core/widgets/premium_data_table.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/features/admin/domain/wallet_pagination.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_wallet_provider.dart';
import 'package:ags_gold/features/customers/domain/customer.dart';
import 'package:ags_gold/features/customers/presentation/providers/customers_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  int _selectedTab = 0; // 0: App Customers, 1: Wholesale B2B
  bool _isSyncingRazorpay = false;

  // Search controllers
  final _appSearchController = TextEditingController();
  Timer? _appDebounce;

  final _wholesaleSearchController = TextEditingController();
  Timer? _wholesaleDebounce;

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

  @override
  void dispose() {
    _appDebounce?.cancel();
    _appSearchController.dispose();
    _wholesaleDebounce?.cancel();
    _wholesaleSearchController.dispose();
    super.dispose();
  }

  void _onAppSearchChanged(String value) {
    _appDebounce?.cancel();
    _appDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(walletUserSearchQueryProvider.notifier).update(value);
      ref.read(walletUsersPageProvider.notifier).update(1);
    });
  }

  void _onWholesaleSearchChanged(String value) {
    _wholesaleDebounce?.cancel();
    _wholesaleDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(customersSearchProvider.notifier).update(value);
      ref.read(customersSkipProvider.notifier).update(0);
    });
  }

  void _onWholesaleSort(int columnIndex) {
    final field = customerTableSortFields[columnIndex];
    if (field == null) return;

    final current = ref.read(customersSortFieldProvider);
    if (current == field) {
      ref.read(customersSortAscProvider.notifier).toggle();
    } else {
      ref.read(customersSortFieldProvider.notifier).update(field);
    }
    ref.read(customersSkipProvider.notifier).update(0);
  }

  int? _wholesaleSortColumnIndex() {
    final field = ref.watch(customersSortFieldProvider);
    for (final entry in customerTableSortFields.entries) {
      if (entry.value == field) return entry.key;
    }
    return null;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'blacklisted':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  bool _canCreateWholesale(WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    if (profile == null) return false;
    return hasPermission(profile, 'customer.create');
  }

  bool _canUpdateWholesale(WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    if (profile == null) return false;
    return hasPermission(profile, 'customer.update');
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab Switcher between App Customers and Wholesale B2B
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppTheme.primaryGold.withValues(alpha: 0.18),
                  selectedForegroundColor: AppTheme.primaryGold,
                ),
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text(
                      'App Customers',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    icon: Icon(Icons.people_alt_outlined),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Wholesale (B2B)'),
                    icon: Icon(Icons.storefront_outlined),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (set) {
                  setState(() => _selectedTab = set.first);
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _selectedTab == 0
                  ? _buildAppCustomersTab(isDesktop, currency, dateFormat)
                  : _buildWholesaleTab(isDesktop, currency, dateFormat),
            ),
          ],
        ),
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
    final hasName = user.hasAssignedName;
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
                  if (!hasName)
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.18),
                        foregroundColor: AppTheme.primaryGold,
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text(
                        'Add Name',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showEditNameDialog(context, user),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Name',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showEditNameDialog(context, user),
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
                    const SizedBox(width: 6),
                    if (!u.hasAssignedName)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Name', style: TextStyle(fontSize: 11)),
                        onPressed: () => _showEditNameDialog(context, u),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        tooltip: 'Edit Name',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showEditNameDialog(context, u),
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
                cellBuilder: (u) => IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'View Wallet Details',
                  onPressed: () => context.push('/admin/user-wallets/${u.id}'),
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

  // ==========================================
  // ADD / EDIT CUSTOMER NAME DIALOG
  // ==========================================

  void _showEditNameDialog(BuildContext context, WalletUserSearchItem user) {
    final hasName = user.hasAssignedName;
    String initFirst = user.firstName ?? '';
    String initLast = user.lastName ?? '';
    if (initFirst.isEmpty && hasName) {
      final parts = user.fullName.trim().split(RegExp(r'\s+'));
      initFirst = parts.isNotEmpty ? parts.first : '';
      initLast = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    final firstController = TextEditingController(text: initFirst);
    final lastController = TextEditingController(text: initLast);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(hasName ? 'Edit Customer Name' : 'Add Customer Name'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.mobileNumber != null
                          ? 'Customer Mobile: ${user.mobileNumber}'
                          : 'Customer: ${user.email}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: firstController,
                      decoration: const InputDecoration(
                        labelText: 'First Name *',
                        hintText: 'e.g. Rahul',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: lastController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        hintText: 'e.g. Sharma (optional)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: Colors.black,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        try {
                          final fn = firstController.text.trim();
                          final ln = lastController.text.trim();
                          await ref.read(updateCustomerNameProvider)(
                            userId: user.id,
                            firstName: fn,
                            lastName: ln.isNotEmpty ? ln : null,
                          );
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Customer name set to "$fn${ln.isNotEmpty ? ' $ln' : ''}".',
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update name: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Save Name',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
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

  // ==========================================
  // TAB 2: WHOLESALE (B2B) CUSTOMERS
  // ==========================================

  Widget _buildWholesaleTab(
    bool isDesktop,
    NumberFormat currency,
    DateFormat dateFormat,
  ) {
    final customersAsync = ref.watch(customersListProvider);
    final canCreate = _canCreateWholesale(ref);
    final canUpdate = _canUpdateWholesale(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _wholesaleSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search wholesale customers...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _onWholesaleSearchChanged,
                onSubmitted: _onWholesaleSearchChanged,
              ),
            ),
            if (canCreate) ...[
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => context.go('/customers/new'),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('New Wholesale Customer'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        FilterChipBar(
          options: customerTypeOptions,
          selected: ref.watch(customersTypeFilterProvider),
          onSelected: (v) {
            ref.read(customersTypeFilterProvider.notifier).update(v);
            ref.read(customersSkipProvider.notifier).update(0);
          },
        ),
        const SizedBox(height: 8),
        FilterChipBar(
          options: customerStatusOptions,
          selected: ref.watch(customersStatusFilterProvider),
          onSelected: (v) {
            ref.read(customersStatusFilterProvider.notifier).update(v);
            ref.read(customersSkipProvider.notifier).update(0);
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: customersAsync.when(
            data: (page) {
              if (page.items.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.storefront_outlined,
                  title: 'No wholesale customers found',
                  subtitle: 'Create a wholesale customer or switch to App Customers.',
                  actionLabel: canCreate ? 'New Wholesale Customer' : null,
                  onAction: canCreate ? () => context.go('/customers/new') : null,
                );
              }

              if (!isDesktop) {
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(customersListProvider.future),
                  child: ListView.builder(
                    itemCount: page.items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == page.items.length) {
                        return _buildWholesalePagination(page);
                      }
                      final customer = page.items[index];
                      return _buildWholesaleMobileCard(
                        customer,
                        currency,
                        dateFormat,
                        canUpdate,
                      );
                    },
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: PremiumDataTable<Customer>(
                      items: page.items,
                      sortColumnIndex: _wholesaleSortColumnIndex(),
                      sortAscending: ref.watch(customersSortAscProvider),
                      onSort: _onWholesaleSort,
                      columns: [
                        DataTableColumn(
                          label: 'Name',
                          valueGetter: (c) => c.fullName,
                          cellBuilder: (c) => _wholesaleNameCell(c),
                        ),
                        DataTableColumn(
                          label: 'Type',
                          valueGetter: (c) => c.customerType,
                          cellBuilder: (c) => Text(c.displayType),
                        ),
                        DataTableColumn(
                          label: 'Status',
                          valueGetter: (c) => c.status,
                          cellBuilder: (c) => _wholesaleStatusChip(c),
                        ),
                        DataTableColumn(
                          label: 'Mobile',
                          cellBuilder: (c) => Text(c.mobileNumber),
                        ),
                        DataTableColumn(
                          label: 'Revenue',
                          valueGetter: (c) => c.totalRevenue,
                          cellBuilder: (c) =>
                              Text(currency.format(c.totalRevenue)),
                        ),
                        DataTableColumn(
                          label: 'Purchases',
                          valueGetter: (c) => c.totalPurchases,
                          cellBuilder: (c) => Text('${c.totalPurchases}'),
                        ),
                        DataTableColumn(
                          label: 'Last Transaction',
                          valueGetter: (c) =>
                              c.lastTransactionDate ?? DateTime(1970),
                          cellBuilder: (c) => Text(
                            c.lastTransactionDate != null
                                ? dateFormat.format(c.lastTransactionDate!)
                                : '—',
                          ),
                        ),
                        DataTableColumn(
                          label: 'Actions',
                          cellBuilder: (c) =>
                              _wholesaleActionButtons(c, canUpdate: canUpdate),
                        ),
                      ],
                    ),
                  ),
                  _buildWholesalePagination(page),
                ],
              );
            },
            loading: () => const PremiumSkeletonList(itemCount: 8),
            error: (e, _) => EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Unable to load wholesale customers',
              subtitle: e.toString(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _wholesaleNameCell(Customer customer) {
    return InkWell(
      onTap: () => context.go('/customers/${customer.id}'),
      child: Text(
        customer.fullName,
        style: const TextStyle(
          color: AppTheme.primaryGold,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _wholesaleStatusChip(Customer customer) {
    return Chip(
      label: Text(
        customer.displayStatus,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: _statusColor(customer.status),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _wholesaleActionButtons(Customer customer, {required bool canUpdate}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 20),
          tooltip: 'View',
          onPressed: () => context.go('/customers/${customer.id}'),
        ),
        if (canUpdate)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit',
            onPressed: () => context.go('/customers/${customer.id}/edit'),
          ),
      ],
    );
  }

  Widget _buildWholesaleMobileCard(
    Customer customer,
    NumberFormat currency,
    DateFormat dateFormat,
    bool canUpdate,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.go('/customers/${customer.id}'),
        title: Text(
          customer.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${customer.displayType} • ${customer.mobileNumber}'),
            Text(
              '${currency.format(customer.totalRevenue)} • ${customer.totalPurchases} purchases',
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _wholesaleStatusChip(customer),
            if (canUpdate)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => context.go('/customers/${customer.id}/edit'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWholesalePagination(PaginatedCustomers page) {
    final skip = ref.watch(customersSkipProvider);
    final limit = ref.watch(customersLimitProvider);
    final canPrev = skip > 0;
    final canNext = skip + limit < page.total;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${skip + 1}-${skip + page.items.length} of ${page.total}',
          ),
          Row(
            children: [
              IconButton(
                onPressed: canPrev
                    ? () => ref
                        .read(customersSkipProvider.notifier)
                        .update(skip - limit)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: canNext
                    ? () => ref
                        .read(customersSkipProvider.notifier)
                        .update(skip + limit)
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
