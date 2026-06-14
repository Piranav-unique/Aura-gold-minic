import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/inventory/presentation/inventory_permission_gate.dart';
import 'package:ags_gold/features/inventory/presentation/providers/inventory_provider.dart';

class StockMovementsScreen extends ConsumerWidget {
  const StockMovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(globalMovementsProvider);
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    return InventoryPermissionGate(
      requiredPermission: 'inventory.view',
      child: ResponsiveNavigationWrapper(
        title: 'Stock Movements',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Global movement history',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/inventory'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to inventory'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: movementsAsync.when(
                  data: (page) {
                    if (page.items.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.history,
                        title: 'No stock movements',
                        subtitle:
                            'Stock in, out, and adjustments will appear here.',
                      );
                    }
                    return ListView.separated(
                      itemCount: page.items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final movement = page.items[index];
                        return ListTile(
                          leading: Icon(_iconForType(movement.movementType)),
                          title: Text(
                            '${movement.displayType}${movement.itemName != null ? ' — ${movement.itemName}' : ''}',
                          ),
                          subtitle: Text(
                            '${movement.quantityBefore} → ${movement.quantityAfter} '
                            '(${movement.quantityChange >= 0 ? '+' : ''}${movement.quantityChange})',
                          ),
                          trailing: Text(dateFormat.format(movement.createdAt)),
                        );
                      },
                    );
                  },
                  loading: () => const PremiumSkeletonList(itemCount: 6),
                  error: (e, _) => EmptyStateWidget(
                    icon: Icons.error_outline,
                    title: 'Failed to load movements',
                    subtitle: e.toString(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
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
