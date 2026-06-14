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
import 'package:ags_gold/features/customers/domain/customer.dart';
import 'package:ags_gold/features/customers/presentation/providers/customers_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
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
      ref.read(customersSearchProvider.notifier).update(value);
      ref.read(customersSkipProvider.notifier).update(0);
    });
  }

  void _onSort(int columnIndex) {
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

  int? _sortColumnIndex() {
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

  bool _canCreate(WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    if (profile == null) return false;
    return hasPermission(profile, 'customer.create');
  }

  bool _canUpdate(WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    if (profile == null) return false;
    return hasPermission(profile, 'customer.update');
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');
    final canCreate = _canCreate(ref);
    final canUpdate = _canUpdate(ref);

    return ResponsiveNavigationWrapper(
      title: 'Customers',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: _onSearchChanged,
                  ),
                ),
                if (canCreate) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => context.go('/customers/new'),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('New Customer'),
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
                      icon: Icons.people_outline,
                      title: 'No customers found',
                      subtitle: 'Create your first customer to get started.',
                      actionLabel: canCreate ? 'New Customer' : null,
                      onAction: canCreate
                          ? () => context.go('/customers/new')
                          : null,
                    );
                  }

                  if (!isDesktop) {
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(customersListProvider.future),
                      child: ListView.builder(
                        itemCount: page.items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == page.items.length) {
                            return _buildPagination(page);
                          }
                          final customer = page.items[index];
                          return _buildMobileCard(
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
                          sortColumnIndex: _sortColumnIndex(),
                          sortAscending: ref.watch(customersSortAscProvider),
                          onSort: _onSort,
                          columns: [
                            DataTableColumn(
                              label: 'Name',
                              valueGetter: (c) => c.fullName,
                              cellBuilder: (c) => _nameCell(c),
                            ),
                            DataTableColumn(
                              label: 'Type',
                              valueGetter: (c) => c.customerType,
                              cellBuilder: (c) => Text(c.displayType),
                            ),
                            DataTableColumn(
                              label: 'Status',
                              valueGetter: (c) => c.status,
                              cellBuilder: (c) => _statusChip(c),
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
                                  _actionButtons(c, canUpdate: canUpdate),
                            ),
                          ],
                        ),
                      ),
                      _buildPagination(page),
                    ],
                  );
                },
                loading: () => const PremiumSkeletonList(itemCount: 8),
                error: (e, _) => EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Unable to load customers',
                  subtitle: e.toString(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameCell(Customer customer) {
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

  Widget _statusChip(Customer customer) {
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

  Widget _actionButtons(Customer customer, {required bool canUpdate}) {
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

  Widget _buildMobileCard(
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
            _statusChip(customer),
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

  Widget _buildPagination(PaginatedCustomers page) {
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
