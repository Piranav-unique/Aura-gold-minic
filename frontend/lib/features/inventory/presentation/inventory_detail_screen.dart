import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/premium_timeline.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/inventory/domain/inventory_item.dart';
import 'package:ags_gold/features/inventory/domain/stock_movement.dart';
import 'package:ags_gold/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ags_gold/features/inventory/presentation/stock_movement_dialog.dart';
import 'package:ags_gold/services/service_providers.dart';

class InventoryDetailScreen extends ConsumerWidget {
  final String itemId;

  const InventoryDetailScreen({super.key, required this.itemId});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${item.itemName}" from inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(deleteInventoryProvider)(item.id);
    if (!context.mounted) return;
    context.go('/inventory');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(inventoryDetailProvider(itemId));
    final movementsAsync = ref.watch(inventoryMovementsProvider(itemId));
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    return ResponsiveNavigationWrapper(
      title: 'Inventory Details',
      child: itemAsync.when(
        data: (item) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ref, item),
              const SizedBox(height: 24),
              _buildDetailsGrid(item, currency),
              const SizedBox(height: 24),
              _buildStockSection(context, ref, item),
              const SizedBox(height: 24),
              Text(
                'Movement History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              movementsAsync.when(
                data: (page) => _buildMovements(page.items, dateFormat),
                loading: () => const PremiumSkeletonList(itemCount: 3),
                error: (e, _) => Text('Failed to load movements: $e'),
              ),
            ],
          ),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeletonList(itemCount: 6),
        ),
        error: (e, _) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Item not found',
          subtitle: e.toString(),
          actionLabel: 'Back',
          onAction: () => context.go('/inventory'),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, InventoryItem item) {
    final profile = ref.watch(profileProvider).value;
    final canUpdate =
        profile != null && hasPermission(profile, 'inventory.update');
    final canDelete =
        profile != null && hasPermission(profile, 'inventory.delete');

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.15),
          child: const Icon(Icons.inventory_2, color: AppTheme.primaryGold),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('${item.displayCategory} • ${item.displayStatus}'),
              if (item.isLowStock)
                const Text(
                  'Low stock',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        if (canUpdate)
          FilledButton.icon(
            onPressed: () => context.go('/inventory/${item.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        if (canDelete) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _confirmDelete(context, ref, item),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailsGrid(InventoryItem item, NumberFormat currency) {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _detailTile('Weight', '${item.weight} g'),
        _detailTile('Purity', '${item.purity}%'),
        _detailTile('Purchase Price', currency.format(item.purchasePrice)),
        _detailTile('Current Value', currency.format(item.currentValue)),
        _detailTile('Stock', '${item.stockQuantity}'),
        _detailTile('Reorder Level', '${item.reorderLevel}'),
        _detailTile('Supplier', item.supplierName ?? '—'),
        if (item.notes != null) _detailTile('Notes', item.notes!),
      ],
    );
  }

  Widget _detailTile(String label, String value) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStockSection(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) {
    final profile = ref.watch(profileProvider).value;
    final canUpdate =
        profile != null && hasPermission(profile, 'inventory.update');
    if (!canUpdate) return const SizedBox.shrink();

    return Row(
      children: [
        FilledButton.icon(
          onPressed: () => showStockMovementDialog(
            context,
            ref,
            itemId: item.id,
            mode: StockMovementMode.stockIn,
          ),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Stock In'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => showStockMovementDialog(
            context,
            ref,
            itemId: item.id,
            mode: StockMovementMode.stockOut,
          ),
          icon: const Icon(Icons.remove_circle_outline),
          label: const Text('Stock Out'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => showStockMovementDialog(
            context,
            ref,
            itemId: item.id,
            mode: StockMovementMode.adjust,
            currentStock: item.stockQuantity,
          ),
          icon: const Icon(Icons.tune),
          label: const Text('Adjust'),
        ),
      ],
    );
  }

  Widget _buildMovements(List<StockMovement> movements, DateFormat dateFormat) {
    if (movements.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history,
        title: 'No movements yet',
        subtitle: 'Stock in, out, and adjustments will appear here.',
      );
    }

    return PremiumTimeline(
      entries: movements
          .map(
            (m) => TimelineEntry(
              title: m.displayType,
              subtitle:
                  '${m.quantityBefore} → ${m.quantityAfter} (${m.quantityChange >= 0 ? '+' : ''}${m.quantityChange})',
              timestamp: m.createdAt,
              icon: _movementIcon(m.movementType),
            ),
          )
          .toList(),
    );
  }

  IconData _movementIcon(String type) {
    switch (type) {
      case 'stock_in':
        return Icons.arrow_downward;
      case 'stock_out':
        return Icons.arrow_upward;
      default:
        return Icons.sync_alt;
    }
  }
}
