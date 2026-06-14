import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/inventory/presentation/providers/inventory_provider.dart';

enum StockMovementMode { stockIn, stockOut, adjust }

Future<void> showStockMovementDialog(
  BuildContext context,
  WidgetRef ref, {
  required String itemId,
  required StockMovementMode mode,
  int? currentStock,
}) async {
  final quantityController = TextEditingController();
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  final reasonController = TextEditingController();
  var isLoading = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        String title;
        switch (mode) {
          case StockMovementMode.stockIn:
            title = 'Stock In';
          case StockMovementMode.stockOut:
            title = 'Stock Out';
          case StockMovementMode.adjust:
            title = 'Stock Adjustment';
        }

        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mode == StockMovementMode.adjust)
                  TextFormField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'New Quantity *',
                      helperText: currentStock != null
                          ? 'Current: $currentStock'
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                  )
                else
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity *'),
                    keyboardType: TextInputType.number,
                  ),
                if (mode == StockMovementMode.adjust) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Reason'),
                  ),
                ],
                if (mode != StockMovementMode.adjust) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: referenceController,
                    decoration: const InputDecoration(labelText: 'Reference'),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final qtyText = quantityController.text.trim();
                      final qty = int.tryParse(qtyText);
                      if (qty == null ||
                          (mode != StockMovementMode.adjust && qty <= 0)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a valid quantity'),
                          ),
                        );
                        return;
                      }
                      if (mode == StockMovementMode.adjust && qty < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quantity cannot be negative'),
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);
                      try {
                        switch (mode) {
                          case StockMovementMode.stockIn:
                            await ref.read(stockInProvider)(
                              itemId,
                              qty,
                              reference: referenceController.text.trim().isEmpty
                                  ? null
                                  : referenceController.text.trim(),
                              notes: notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                            );
                          case StockMovementMode.stockOut:
                            await ref.read(stockOutProvider)(
                              itemId,
                              qty,
                              reference: referenceController.text.trim().isEmpty
                                  ? null
                                  : referenceController.text.trim(),
                              notes: notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                            );
                          case StockMovementMode.adjust:
                            await ref.read(stockAdjustProvider)(
                              itemId,
                              qty,
                              reason: reasonController.text.trim().isEmpty
                                  ? null
                                  : reasonController.text.trim(),
                              notes: notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                            );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('$title recorded')),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        );
      },
    ),
  );

  quantityController.dispose();
  referenceController.dispose();
  notesController.dispose();
  reasonController.dispose();
}
