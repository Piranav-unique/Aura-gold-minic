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
import 'package:ags_gold/features/inventory/domain/inventory_item.dart';
import 'package:ags_gold/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
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
      ref.read(inventorySearchProvider.notifier).update(value);
      ref.read(inventorySkipProvider.notifier).update(0);
    });
  }

  void _onSort(int columnIndex) {
    final field = inventoryTableSortFields[columnIndex];
    if (field == null) return;
    final current = ref.read(inventorySortFieldProvider);
    if (current == field) {
      ref.read(inventorySortAscProvider.notifier).toggle();
    } else {
      ref.read(inventorySortFieldProvider.notifier).update(field);
    }
    ref.read(inventorySkipProvider.notifier).update(0);
  }

  int? _sortColumnIndex() {
    final field = ref.watch(inventorySortFieldProvider);
    for (final entry in inventoryTableSortFields.entries) {
      if (entry.value == field) return entry.key;
    }
    return null;
  }

  bool _canCreate(WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    return profile != null && hasPermission(profile, 'inventory.create');
  }

  bool _canUpdate(WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    return profile != null && hasPermission(profile, 'inventory.update');
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryListProvider);
    final metricsAsync = ref.watch(inventoryMetricsProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final canCreate = _canCreate(ref);
    final canUpdate = _canUpdate(ref);
    final theme = Theme.of(context);

    return ResponsiveNavigationWrapper(
      title: 'Inventory',
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 28 : 16,
              isDesktop ? 24 : 16,
              isDesktop ? 28 : 16,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Page header ──────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Physical Inventory',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Track physical gold & silver stock — items, quantities and values.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (canCreate)
                        FilledButton.icon(
                          onPressed: () => context.go('/inventory/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('New Item'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── KPI metric cards ──────────────────────────
                  metricsAsync.when(
                    data: (metrics) =>
                        _buildMetricsRow(metrics, currency, isDesktop),
                    loading: () => SizedBox(
                      height: 80,
                      child: Row(
                        children: List.generate(
                          3,
                          (i) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: i == 0 ? 0 : 8,
                              ),
                              child: const Card(
                                child: SizedBox(height: 80),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),
                  // ── Search + quick nav bar ────────────────────
                  isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search inventory…',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: _onSearchChanged,
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.go('/inventory/movements'),
                              icon: const Icon(Icons.history, size: 18),
                              label: const Text('Movements'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/suppliers'),
                              icon: const Icon(
                                Icons.local_shipping_outlined,
                                size: 18,
                              ),
                              label: const Text('Suppliers'),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search inventory…',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        context.go('/inventory/movements'),
                                    icon: const Icon(Icons.history, size: 18),
                                    label: const Text('Movements'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        context.go('/suppliers'),
                                    icon: const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Suppliers'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                  const SizedBox(height: 12),
                  // ── Filters ───────────────────────────────────
                  FilterChipBar(
                    options: inventoryCategoryOptions,
                    selected: ref.watch(inventoryCategoryFilterProvider),
                    onSelected: (v) {
                      ref
                          .read(inventoryCategoryFilterProvider.notifier)
                          .update(v);
                      ref.read(inventorySkipProvider.notifier).update(0);
                    },
                  ),
                  const SizedBox(height: 6),
                  FilterChipBar(
                    options: inventoryStatusOptions,
                    selected: ref.watch(inventoryStatusFilterProvider),
                    onSelected: (v) {
                      ref
                          .read(inventoryStatusFilterProvider.notifier)
                          .update(v);
                      ref.read(inventorySkipProvider.notifier).update(0);
                    },
                  ),
                  const SizedBox(height: 6),
                  FilterChip(
                    label: const Text('Low stock only'),
                    selected: ref.watch(inventoryLowStockFilterProvider),
                    onSelected: (selected) {
                      ref
                          .read(inventoryLowStockFilterProvider.notifier)
                          .update(selected);
                      ref.read(inventorySkipProvider.notifier).update(0);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // ── Items list / table ──────────────────────────────
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 16,
            ),
            sliver: inventoryAsync.when(
              data: (page) {
                if (page.items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: EmptyStateWidget(
                      icon: Icons.inventory_2_outlined,
                      title: 'No inventory items',
                      subtitle: 'Add gold inventory items to track stock.',
                      actionLabel: canCreate ? 'New Item' : null,
                      onAction: canCreate
                          ? () => context.go('/inventory/new')
                          : null,
                    ),
                  );
                }

                if (!isDesktop) {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == page.items.length) {
                          return _buildPagination(page);
                        }
                        return _buildMobileCard(
                          page.items[index],
                          currency,
                          canUpdate,
                        );
                      },
                      childCount: page.items.length + 1,
                    ),
                  );
                }

                return SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height - 380,
                        child: PremiumDataTable<InventoryItem>(
                          items: page.items,
                          sortColumnIndex: _sortColumnIndex(),
                          sortAscending:
                              ref.watch(inventorySortAscProvider),
                          onSort: _onSort,
                          columns: [
                            DataTableColumn(
                              label: 'Item',
                              valueGetter: (i) => i.itemName,
                              cellBuilder: (i) => _nameCell(i),
                            ),
                            DataTableColumn(
                              label: 'Category',
                              valueGetter: (i) => i.itemCategory,
                              cellBuilder: (i) =>
                                  Text(i.displayCategory),
                            ),
                            DataTableColumn(
                              label: 'Stock',
                              valueGetter: (i) => i.stockQuantity,
                              cellBuilder: (i) => _stockCell(i),
                            ),
                            DataTableColumn(
                              label: 'Value',
                              valueGetter: (i) => i.currentValue,
                              cellBuilder: (i) => Text(
                                currency.format(i.currentValue),
                              ),
                            ),
                            DataTableColumn(
                              label: 'Status',
                              valueGetter: (i) => i.status,
                              cellBuilder: (i) => _statusChip(i),
                            ),
                            DataTableColumn(
                              label: 'Actions',
                              cellBuilder: (i) =>
                                  _actionButtons(i, canUpdate),
                            ),
                          ],
                        ),
                      ),
                      _buildPagination(page),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: PremiumSkeletonList(itemCount: 8),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Unable to load inventory',
                  subtitle: e.toString(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(
    InventoryMetrics metrics,
    NumberFormat currency,
    bool isDesktop,
  ) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            'Total Stock',
            '${metrics.totalStock}',
            Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            'Inventory Value',
            currency.format(metrics.inventoryValue),
            Icons.account_balance_wallet_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            'Low Stock',
            '${metrics.lowStockCount}',
            Icons.warning_amber_outlined,
            highlight: metrics.lowStockCount > 0,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
    String label,
    String value,
    IconData icon, {
    bool highlight = false,
    Color? color,
  }) {
    return Card(
      color: highlight ? Colors.orange.withValues(alpha: 0.08) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppTheme.primaryGold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12)),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameCell(InventoryItem item) {
    return InkWell(
      onTap: () => context.go('/inventory/${item.id}'),
      child: Text(
        item.itemName,
        style: const TextStyle(
          color: AppTheme.primaryGold,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _stockCell(InventoryItem item) {
    final color = item.isLowStock ? Colors.orange : null;
    return Text(
      '${item.stockQuantity}',
      style: TextStyle(fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _statusChip(InventoryItem item) {
    return Chip(
      label: Text(
        item.displayStatus,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: item.status == 'active' ? Colors.green : Colors.orange,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _actionButtons(InventoryItem item, bool canUpdate) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 20),
          onPressed: () => context.go('/inventory/${item.id}'),
        ),
        if (canUpdate)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => context.go('/inventory/${item.id}/edit'),
          ),
      ],
    );
  }

  Widget _buildMobileCard(
    InventoryItem item,
    NumberFormat currency,
    bool canUpdate,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.go('/inventory/${item.id}'),
        title: Text(
          item.itemName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${item.displayCategory} • Stock: ${item.stockQuantity} • ${currency.format(item.currentValue)}',
        ),
        trailing: item.isLowStock
            ? const Icon(Icons.warning_amber, color: Colors.orange)
            : null,
      ),
    );
  }

  Widget _buildPagination(PaginatedInventoryItems page) {
    final skip = ref.watch(inventorySkipProvider);
    final limit = ref.watch(inventoryLimitProvider);
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
                          .read(inventorySkipProvider.notifier)
                          .update(skip - limit)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: canNext
                    ? () => ref
                          .read(inventorySkipProvider.notifier)
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
