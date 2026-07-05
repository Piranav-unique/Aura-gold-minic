import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_metal_inventory_provider.dart';
import 'package:ags_gold/services/api_client.dart';

class MetalInventoryMovementsScreen extends ConsumerWidget {
  const MetalInventoryMovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metal = ref.watch(metalMovementsMetalProvider);
    final movementsAsync = ref.watch(digitalMetalMovementsProvider);
    final kgFormat = NumberFormat('#,##0.##');
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return ResponsiveNavigationWrapper(
      title: 'Stock history',
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Limit changes by admin and purchases by users.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'gold', label: Text('Gold')),
                ButtonSegment(value: 'silver', label: Text('Silver')),
              ],
              selected: {metal},
              onSelectionChanged: (s) {
                ref.read(metalMovementsMetalProvider.notifier).update(s.first);
                ref.read(metalMovementsPageProvider.notifier).update(1);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: movementsAsync.when(
                data: (page) {
                  if (page.items.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.history,
                      title: 'No history yet',
                      subtitle:
                          'When you update limits or users buy metal, entries appear here.',
                    );
                  }
                  return ListView.separated(
                    itemCount: page.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = page.items[index];
                      final isPurchase = m.movementType == 'purchase_debit';
                      final deltaKg = m.gramsDelta.abs() / 1000;
                      final availableKg = m.availableWeightAfter / 1000;
                      return ListTile(
                        leading: Icon(
                          isPurchase
                              ? Icons.shopping_cart_outlined
                              : Icons.edit_outlined,
                        ),
                        title: Text(
                          isPurchase ? 'User purchase' : 'Admin updated limit',
                        ),
                        subtitle: Text(
                          '${isPurchase ? 'Bought' : 'Changed'} '
                          '${kgFormat.format(deltaKg)} KG • '
                          '${kgFormat.format(availableKg)} KG left after',
                        ),
                        trailing: Text(
                          dateFormat.format(m.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  );
                },
                loading: () => const PremiumSkeleton(height: 120),
                error: (e, _) => EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Could not load history',
                  subtitle: e is ApiException ? e.message : e.toString(),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(digitalMetalMovementsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
