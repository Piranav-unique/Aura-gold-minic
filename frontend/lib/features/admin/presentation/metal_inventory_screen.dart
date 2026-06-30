import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/domain/metal_inventory_models.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_metal_inventory_provider.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/services/service_providers.dart';

/// Platform-wide GOLD / SILVER buy limits.
class MetalInventoryScreen extends ConsumerWidget {
  const MetalInventoryScreen({super.key});

  static const _goldType = 'gold';
  static const _silverType = 'silver';

  static String formatKg(double kg) {
    final fmt = NumberFormat('#,##0.##');
    return '${fmt.format(kg)} KG';
  }

  static String alertAtLabel(double thresholdGrams) {
    final kg = thresholdGrams / 1000;
    return 'Alert @ ${formatKg(kg)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(digitalMetalInventoryProvider);
    final alertsAsync = ref.watch(digitalMetalInventoryAlertsProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return ResponsiveNavigationWrapper(
      title: 'Inventory',
      child: inventoryAsync.when(
        loading: () => _buildScaffold(
          context,
          isDesktop: isDesktop,
          alertsAsync: alertsAsync,
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => _buildScaffold(
          context,
          isDesktop: isDesktop,
          alertsAsync: alertsAsync,
          body: EmptyStateWidget(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load inventory',
            subtitle: e is ApiException ? e.message : e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(digitalMetalInventoryProvider),
          ),
        ),
        data: (items) {
          final gold = _findMetal(items, _goldType);
          final silver = _findMetal(items, _silverType);
          return _buildScaffold(
            context,
            isDesktop: isDesktop,
            alertsAsync: alertsAsync,
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MetalLimitCard(
                              metalType: _goldType,
                              item: gold,
                              onSetLimit: () => _openLimitDialog(
                                context,
                                ref,
                                metalType: _goldType,
                                metalLabel: 'GOLD',
                                item: gold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetalLimitCard(
                              metalType: _silverType,
                              item: silver,
                              onSetLimit: () => _openLimitDialog(
                                context,
                                ref,
                                metalType: _silverType,
                                metalLabel: 'SILVER',
                                item: silver,
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _MetalLimitCard(
                              metalType: _goldType,
                              item: gold,
                              onSetLimit: () => _openLimitDialog(
                                context,
                                ref,
                                metalType: _goldType,
                                metalLabel: 'GOLD',
                                item: gold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _MetalLimitCard(
                              metalType: _silverType,
                              item: silver,
                              onSetLimit: () => _openLimitDialog(
                                context,
                                ref,
                                metalType: _silverType,
                                metalLabel: 'SILVER',
                                item: silver,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required bool isDesktop,
    required AsyncValue<List<DigitalMetalInventoryAlert>> alertsAsync,
    required Widget body,
  }) {
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Inventory',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.go('/inventory/movements'),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Stock history'),
              ),
              const SizedBox(width: 8),
              alertsAsync.when(
                data: (alerts) {
                  if (alerts.isEmpty) return const SizedBox.shrink();
                  return Badge(
                    label: Text('${alerts.length}'),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'How much GOLD and SILVER all users can buy in total. '
            'Each purchase reduces what is still available.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
                ),
          ),
          const SizedBox(height: 16),
          alertsAsync.when(
            data: (alerts) => alerts.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      ...alerts.map((a) => _AlertBanner(alert: a)),
                      const SizedBox(height: 16),
                    ],
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  DigitalMetalInventory? _findMetal(
    List<DigitalMetalInventory> items,
    String metalType,
  ) {
    for (final item in items) {
      if (item.metalType == metalType) return item;
    }
    return null;
  }

  Future<void> _openLimitDialog(
    BuildContext context,
    WidgetRef ref, {
    required String metalType,
    required String metalLabel,
    required DigitalMetalInventory? item,
  }) async {
    final profile = ref.read(profileProvider).value;
    if (profile == null || !hasPermission(profile, 'inventory.update')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need permission to update inventory limits.'),
        ),
      );
      return;
    }

    final totalKg = (item?.totalWeightGrams ?? 0) / 1000;
    final alertKg = (item?.lowStockThresholdGrams ?? 0) / 1000;
    final totalController = TextEditingController(
      text: totalKg > 0 ? _formatKgInput(totalKg) : '',
    );
    final alertController = TextEditingController(
      text: alertKg > 0 ? _formatKgInput(alertKg) : '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              metalType == _goldType
                  ? Icons.monetization_on
                  : Icons.circle_outlined,
              color: metalType == _goldType
                  ? Colors.amber.shade700
                  : Colors.blueGrey,
            ),
            const SizedBox(width: 8),
            Text('Set $metalLabel limit'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: totalController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Total buy limit (KG)',
                  hintText: 'e.g. 15',
                  helperText: 'Maximum KG all users can buy together.',
                  suffixText: 'KG',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: alertController,
                decoration: InputDecoration(
                  labelText: 'Alert @ (KG)',
                  hintText: 'e.g. 1',
                  helperText:
                      'Notify you when available stock drops to this KG or below.',
                  suffixText: 'KG',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.notifications_outlined,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
                ],
              ),
              if (item != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Now: ${formatKg(item.usedWeightGrams / 1000)} bought • '
                    '${formatKg(item.availableWeightGrams / 1000)} still available',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) {
      totalController.dispose();
      alertController.dispose();
      return;
    }

    try {
      final totalKgValue = double.parse(totalController.text.trim());
      final alertKgValue = double.parse(alertController.text.trim());
      await ref.read(updateDigitalMetalInventoryProvider)(
        metalType: metalType,
        totalWeightGrams: totalKgValue * 1000,
        lowStockThresholdGrams: alertKgValue * 1000,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$metalLabel limit saved.')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid KG values.')),
        );
      }
    } finally {
      totalController.dispose();
      alertController.dispose();
    }
  }

  static String _formatKgInput(double kg) {
    if (kg == kg.roundToDouble()) return kg.toStringAsFixed(0);
    return kg
        .toStringAsFixed(4)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}

class _MetalLimitCard extends ConsumerWidget {
  final String metalType;
  final DigitalMetalInventory? item;
  final VoidCallback onSetLimit;

  const _MetalLimitCard({
    required this.metalType,
    required this.item,
    required this.onSetLimit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final canEdit =
        profile != null && hasPermission(profile, 'inventory.update');
    final isGold = metalType == 'gold';
    final label = isGold ? 'GOLD' : 'SILVER';
    final accent = isGold ? Colors.amber.shade700 : Colors.blueGrey.shade300;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Icon(
                    isGold ? Icons.monetization_on : Icons.circle_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (item != null)
                  _StatusBadge(status: item!.stockStatus)
                else
                  const Chip(label: Text('Not set')),
              ],
            ),
            const SizedBox(height: 20),
            if (item == null)
              Text(
                'Set how many KG users can buy in total.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              _metricRow(
                context,
                icon: Icons.inventory_2_outlined,
                label: 'Total limit',
                value: MetalInventoryScreen.formatKg(
                  item!.totalWeightGrams / 1000,
                ),
              ),
              _metricRow(
                context,
                icon: Icons.people_outline,
                label: 'Bought by users',
                value: MetalInventoryScreen.formatKg(
                  item!.usedWeightGrams / 1000,
                ),
              ),
              _metricRow(
                context,
                icon: Icons.check_circle_outline,
                label: 'Still available',
                value: MetalInventoryScreen.formatKg(
                  item!.availableWeightGrams / 1000,
                ),
                highlight: true,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MetalInventoryScreen.alertAtLabel(
                            item!.lowStockThresholdGrams,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'when available stock reaches this level or below',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canEdit ? onSetLimit : null,
                icon: const Icon(Icons.tune),
                label: Text(canEdit ? 'Set $label limit' : 'View only'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final DigitalMetalInventoryAlert alert;

  const _AlertBanner({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isUrgent = alert.stockStatus == MetalStockStatus.outOfStock;
    final color = isUrgent
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.tertiaryContainer;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.error_outline : Icons.warning_amber_outlined,
            color: isUrgent
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(alert.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MetalStockStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case MetalStockStatus.outOfStock:
        bg = Theme.of(context).colorScheme.errorContainer;
        fg = Theme.of(context).colorScheme.error;
        label = 'Out of stock';
      case MetalStockStatus.lowStock:
        bg = Theme.of(context).colorScheme.tertiaryContainer;
        fg = Theme.of(context).colorScheme.tertiary;
        label = 'Low stock';
      case MetalStockStatus.available:
        bg = Theme.of(context).colorScheme.primaryContainer;
        fg = Theme.of(context).colorScheme.primary;
        label = 'In stock';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
