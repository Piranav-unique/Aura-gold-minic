import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/aura_dialog_actions.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/features/admin/domain/metal_inventory_models.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_metal_inventory_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
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
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetalLimitCard(
                              metalType: _silverType,
                              item: silver,
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
                            ),
                            const SizedBox(height: 16),
                            _MetalLimitCard(
                              metalType: _silverType,
                              item: silver,
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
                  'How much GOLD and SILVER all users can buy in total. '
                  'Each purchase reduces what is still available.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                      ),
                ),
              ),
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

  static Future<void> _openAddStockDialog(
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
          content: Text('You need permission to add inventory stock.'),
        ),
      );
      return;
    }

    final addGrams = await showDialog<double>(
      context: context,
      builder: (ctx) => _AddStockDialog(
        metalType: metalType,
        metalLabel: metalLabel,
        item: item,
      ),
    );

    if (addGrams == null || addGrams <= 0 || !context.mounted) return;

    try {
      await ref.read(addDigitalMetalStockProvider)(
        metalType: metalType,
        addWeightGrams: addGrams,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added +${formatKg(addGrams / 1000)} to $metalLabel stock.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  static Future<void> _openAdjustReserveDialog(
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
          content: Text('You need permission to adjust inventory reserve.'),
        ),
      );
      return;
    }

    final reservedGrams = await showDialog<double>(
      context: context,
      builder: (ctx) => _AdjustReserveDialog(
        metalType: metalType,
        metalLabel: metalLabel,
        item: item,
      ),
    );

    if (reservedGrams == null || !context.mounted) return;

    try {
      await ref.read(adjustDigitalMetalReserveProvider)(
        metalType: metalType,
        reservedWeightGrams: reservedGrams,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$metalLabel reserve updated to ${formatKg(reservedGrams / 1000)}.')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

class _AddStockDialog extends StatefulWidget {
  final String metalType;
  final String metalLabel;
  final DigitalMetalInventory? item;

  const _AddStockDialog({
    required this.metalType,
    required this.metalLabel,
    required this.item,
  });

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  final _amountController = TextEditingController();
  bool _useKg = true;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGold = widget.metalType == 'gold';
    final currentTotalKg = (widget.item?.totalWeightGrams ?? 0) / 1000;
    final addKg = double.tryParse(_amountController.text.trim()) ?? 0;
    final finalAddGrams = _useKg ? addKg * 1000 : addKg;
    final newTotalKg = currentTotalKg + (finalAddGrams / 1000);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isGold ? Icons.monetization_on : Icons.circle_outlined,
            color: isGold ? Colors.amber.shade700 : Colors.blueGrey,
          ),
          const SizedBox(width: 8),
          Text('Add ${widget.metalLabel} Stock'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify quantity to ADD to existing stock.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Quantity to Add (${_useKg ? 'KG' : 'Grams'})',
                      hintText: _useKg ? 'e.g. 20' : 'e.g. 20000',
                      suffixText: _useKg ? 'KG' : 'g',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('KG')),
                    ButtonSegment(value: false, label: Text('g')),
                  ],
                  selected: {_useKg},
                  onSelectionChanged: (set) {
                    setState(() => _useKg = set.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Stock: ${MetalInventoryScreen.formatKg(currentTotalKg)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Restock Added: +${MetalInventoryScreen.formatKg(finalAddGrams / 1000)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A), fontSize: 13),
                  ),
                  const Divider(height: 12),
                  Text(
                    'New Total Stock: ${MetalInventoryScreen.formatKg(newTotalKg)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        AuraDialogActions.buttons(
          context: context,
          cancelLabel: 'Cancel',
          onCancel: () => Navigator.pop(context),
          confirmLabel: 'Add Stock',
          onConfirm: () {
            if (finalAddGrams <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid stock quantity.')),
              );
              return;
            }
            Navigator.pop(context, finalAddGrams);
          },
        ),
      ],
    );
  }
}

class _AdjustReserveDialog extends StatefulWidget {
  final String metalType;
  final String metalLabel;
  final DigitalMetalInventory? item;

  const _AdjustReserveDialog({
    required this.metalType,
    required this.metalLabel,
    required this.item,
  });

  @override
  State<_AdjustReserveDialog> createState() => _AdjustReserveDialogState();
}

class _AdjustReserveDialogState extends State<_AdjustReserveDialog> {
  late final TextEditingController _reserveController;
  bool _useKg = true;

  @override
  void initState() {
    super.initState();
    final reservedKg = (widget.item?.reservedWeightGrams ?? 0) / 1000;
    _reserveController = TextEditingController(
      text: reservedKg > 0 ? reservedKg.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : '0',
    );
  }

  @override
  void dispose() {
    _reserveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGold = widget.metalType == 'gold';
    final totalKg = (widget.item?.totalWeightGrams ?? 0) / 1000;
    final usedKg = (widget.item?.usedWeightGrams ?? 0) / 1000;
    final inputVal = double.tryParse(_reserveController.text.trim()) ?? 0;
    final reservedKg = _useKg ? inputVal : inputVal / 1000;
    final availableKg = (totalKg - usedKg - reservedKg).clamp(0.0, double.infinity);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isGold ? Icons.monetization_on : Icons.circle_outlined,
            color: isGold ? Colors.amber.shade700 : Colors.blueGrey,
          ),
          const SizedBox(width: 8),
          Text('Adjust ${widget.metalLabel} Reserve'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set reserve stock. Available to Sell = Total Stock - Reserved Stock - Sold Quantity.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _reserveController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Reserved Quantity (${_useKg ? 'KG' : 'Grams'})',
                      hintText: 'e.g. 1.0',
                      suffixText: _useKg ? 'KG' : 'g',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('KG')),
                    ButtonSegment(value: false, label: Text('g')),
                  ],
                  selected: {_useKg},
                  onSelectionChanged: (set) {
                    setState(() => _useKg = set.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Stock: ${MetalInventoryScreen.formatKg(totalKg)}'),
                  const SizedBox(height: 4),
                  Text('Sold Quantity: ${MetalInventoryScreen.formatKg(usedKg)}'),
                  const SizedBox(height: 4),
                  Text('Reserved Stock: ${MetalInventoryScreen.formatKg(reservedKg)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 12),
                  Text('Available to Sell: ${MetalInventoryScreen.formatKg(availableKg)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        AuraDialogActions.buttons(
          context: context,
          cancelLabel: 'Cancel',
          onCancel: () => Navigator.pop(context),
          confirmLabel: 'Save Reserve',
          onConfirm: () {
            if (reservedKg < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reserved quantity cannot be negative.')),
              );
              return;
            }
            Navigator.pop(context, reservedKg * 1000);
          },
        ),
      ],
    );
  }
}

class _MetalLimitCard extends ConsumerWidget {
  final String metalType;
  final DigitalMetalInventory? item;

  const _MetalLimitCard({
    required this.metalType,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final canEdit =
        profile != null && hasPermission(profile, 'inventory.update');
    final isGold = metalType == 'gold';
    final label = isGold ? 'GOLD' : 'SILVER';
    final accent = isGold ? Colors.amber.shade700 : Colors.blueGrey.shade300;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    final pricesAsync = ref.watch(metalPricesProvider);
    final livePrice = pricesAsync.when(
      data: (data) {
        final price = isGold ? data.gold.displayPrice : data.silver.displayPrice;
        return '${currency.format(price)}/gm';
      },
      loading: () => '…',
      error: (_, _) => 'Unavailable',
    );

    final availableGrams = item?.availableWeightGrams ?? 0;

    return AurumSurfaceCard(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: pricesAsync.hasValue
                                ? Colors.green
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Live: $livePrice',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (item == null)
                const Chip(label: Text('Not set'))
              else
                _StatusBadge(status: item!.stockStatus, availableGrams: availableGrams),
            ],
          ),
          const SizedBox(height: 20),
          if (item == null)
            Text(
              'Add physical stock to enable purchases.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else ...[
            _metricRow(
              context,
              icon: Icons.inventory_2_outlined,
              label: 'Total Stock',
              value: MetalInventoryScreen.formatKg(
                item!.totalWeightGrams / 1000,
              ),
            ),
            _metricRow(
              context,
              icon: Icons.check_circle_outline,
              label: 'Available to Sell',
              value: MetalInventoryScreen.formatKg(
                item!.availableWeightGrams / 1000,
              ),
              highlight: true,
            ),
            _metricRow(
              context,
              icon: Icons.lock_outline,
              label: 'Reserved Stock',
              value: MetalInventoryScreen.formatKg(
                item!.reservedWeightGrams / 1000,
              ),
            ),
            _metricRow(
              context,
              icon: Icons.people_outline,
              label: 'Sold Quantity',
              value: MetalInventoryScreen.formatKg(
                item!.usedWeightGrams / 1000,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canEdit
                      ? () => MetalInventoryScreen._openAddStockDialog(
                            context,
                            ref,
                            metalType: metalType,
                            metalLabel: label,
                            item: item,
                          )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    '+ Add Stock',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canEdit
                      ? () => MetalInventoryScreen._openAdjustReserveDialog(
                            context,
                            ref,
                            metalType: metalType,
                            metalLabel: label,
                            item: item,
                          )
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                      color: AppTheme.primaryGold.withValues(alpha: 0.5),
                    ),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'Adjust Reserve',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: highlight ? FontWeight.w700 : FontWeight.normal))),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              fontSize: highlight ? 16 : 14,
              color: highlight ? const Color(0xFF16A34A) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MetalStockStatus status;
  final double availableGrams;

  const _StatusBadge({required this.status, required this.availableGrams});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    if (availableGrams <= 0) {
      bg = AppTheme.rose.withValues(alpha: 0.14);
      fg = AppTheme.rose;
      label = 'Purchasing Paused';
    } else {
      switch (status) {
        case MetalStockStatus.outOfStock:
          bg = AppTheme.rose.withValues(alpha: 0.14);
          fg = AppTheme.rose;
          label = 'Purchasing Paused';
        case MetalStockStatus.lowStock:
          bg = AppTheme.amber.withValues(alpha: 0.16);
          fg = const Color(0xFFB45309);
          label = 'Low Stock';
        case MetalStockStatus.available:
          bg = AppTheme.emerald.withValues(alpha: 0.14);
          fg = const Color(0xFF0F7A44);
          label = 'In Stock';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final DigitalMetalInventoryAlert alert;

  const _AlertBanner({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isError = alert.stockStatus == MetalStockStatus.outOfStock || alert.availableWeightGrams <= 0;
    final color = isError ? AppTheme.rose : AppTheme.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (alert.message.isNotEmpty)
                  Text(
                    alert.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
