import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/customers/domain/customer.dart';
import 'package:ags_gold/features/customers/presentation/providers/customers_provider.dart';
import 'package:ags_gold/features/inventory/domain/inventory_item.dart';
import 'package:ags_gold/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ags_gold/features/transactions/domain/transaction.dart';
import 'package:ags_gold/features/transactions/presentation/providers/transactions_provider.dart';

class _LineDraft {
  String? inventoryItemId;
  String itemName = '';
  int quantity = 1;
  double unitPrice = 0;
  String stockDirection = 'out';

  TransactionLine toLine() => TransactionLine(
    id: '',
    inventoryItemId: inventoryItemId ?? '',
    itemName: itemName,
    quantity: quantity,
    unitPrice: unitPrice,
    lineTotal: quantity * unitPrice,
    stockDirection: stockDirection,
  );
}

class TransactionFormScreen extends ConsumerStatefulWidget {
  final String? transactionId;

  const TransactionFormScreen({super.key, this.transactionId});

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _taxController = TextEditingController(text: '0');

  String _transactionType = 'sale';
  String _paymentStatus = 'pending';
  String? _customerId;
  final List<_LineDraft> _lines = [_LineDraft()];
  bool _saving = false;
  bool _loaded = false;

  bool get isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
  }

  void _loadExistingTransaction(Transaction txn) {
    if (_loaded) return;
    _loaded = true;
    _transactionType = txn.transactionType;
    _paymentStatus = txn.paymentStatus;
    _customerId = txn.customerId;
    _notesController.text = txn.notes ?? '';
    _taxController.text = txn.taxAmount.toStringAsFixed(2);
    _lines
      ..clear()
      ..addAll(
        txn.lines.map(
          (line) => _LineDraft()
            ..inventoryItemId = line.inventoryItemId
            ..itemName = line.itemName
            ..quantity = line.quantity
            ..unitPrice = line.unitPrice
            ..stockDirection = line.stockDirection,
        ),
      );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  bool get _requiresCustomer =>
      _transactionType == 'sale' ||
      _transactionType == 'return' ||
      _transactionType == 'exchange';

  double get _subtotal =>
      _lines.fold(0.0, (sum, line) => sum + line.quantity * line.unitPrice);

  double get _taxAmount => double.tryParse(_taxController.text) ?? 0;

  double get _total => _subtotal + _taxAmount;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiresCustomer && (_customerId == null || _customerId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer is required for this transaction type'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final txn = Transaction(
        id: widget.transactionId ?? '',
        transactionNumber: '',
        transactionType: _transactionType,
        customerId: _customerId,
        status: 'active',
        paymentStatus: _paymentStatus,
        subtotal: _subtotal,
        taxAmount: _taxAmount,
        totalAmount: _total,
        stockApplied: false,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        lines: _lines.map((l) => l.toLine()).toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEditing) {
        await ref.read(updateTransactionProvider)(txn);
      } else {
        await ref.read(createTransactionProvider)(txn);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Transaction updated' : 'Transaction created',
            ),
          ),
        );
        context.go('/transactions');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEditing && !_loaded) {
      final existingAsync = ref.watch(
        transactionDetailProvider(widget.transactionId!),
      );
      return existingAsync.when(
        data: (txn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _loaded) return;
            setState(() => _loadExistingTransaction(txn));
          });
          return const ResponsiveNavigationWrapper(
            title: 'Edit Transaction',
            child: Center(child: CircularProgressIndicator()),
          );
        },
        loading: () => const ResponsiveNavigationWrapper(
          title: 'Edit Transaction',
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => ResponsiveNavigationWrapper(
          title: 'Edit Transaction',
          child: Center(child: Text('Failed to load: $error')),
        ),
      );
    }

    final customersAsync = ref.watch(customersListProvider);
    final inventoryAsync = ref.watch(inventoryListProvider);

    return ResponsiveNavigationWrapper(
      title: isEditing ? 'Edit Transaction' : 'New Transaction',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isEditing)
                DropdownButtonFormField<String>(
                  initialValue: _transactionType,
                  decoration: const InputDecoration(
                    labelText: 'Transaction type',
                  ),
                  items: transactionTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(transactionTypeLabel(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _transactionType = value);
                  },
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _paymentStatus,
                decoration: const InputDecoration(labelText: 'Payment status'),
                items: paymentStatuses
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(paymentStatusLabel(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _paymentStatus = value);
                },
              ),
              const SizedBox(height: 16),
              if (_requiresCustomer)
                customersAsync.when(
                  data: (page) => DropdownButtonFormField<String>(
                    initialValue: _customerId,
                    decoration: const InputDecoration(labelText: 'Customer'),
                    items: page.items
                        .map(
                          (Customer c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _customerId = value),
                    validator: (value) =>
                        value == null ? 'Select a customer' : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Failed to load customers'),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _taxController,
                decoration: const InputDecoration(labelText: 'Tax amount'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Line items',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_LineDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add line'),
                  ),
                ],
              ),
              inventoryAsync.when(
                data: (inventoryPage) => Column(
                  children: _lines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: line.inventoryItemId,
                              decoration: const InputDecoration(
                                labelText: 'Inventory item',
                              ),
                              items: inventoryPage.items
                                  .where(
                                    (InventoryItem i) => i.status == 'active',
                                  )
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.id,
                                      child: Text(
                                        '${item.itemName} (stock: ${item.stockQuantity})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                InventoryItem? item;
                                for (final candidate in inventoryPage.items) {
                                  if (candidate.id == value) {
                                    item = candidate;
                                    break;
                                  }
                                }
                                setState(() {
                                  line.inventoryItemId = value;
                                  if (item != null) {
                                    line.itemName = item.itemName;
                                    line.unitPrice = item.currentValue;
                                  }
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Select an item' : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: '${line.quantity}',
                                    decoration: const InputDecoration(
                                      labelText: 'Quantity',
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      line.quantity = int.tryParse(value) ?? 1;
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: line.unitPrice
                                        .toStringAsFixed(2),
                                    decoration: const InputDecoration(
                                      labelText: 'Unit price',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (value) {
                                      line.unitPrice =
                                          double.tryParse(value) ?? 0;
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_transactionType == 'exchange') ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: line.stockDirection,
                                decoration: const InputDecoration(
                                  labelText: 'Stock direction',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'in',
                                    child: Text('Stock In'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'out',
                                    child: Text('Stock Out'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => line.stockDirection = value);
                                },
                              ),
                            ],
                            if (_lines.length > 1)
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  onPressed: () =>
                                      setState(() => _lines.removeAt(index)),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Failed to load inventory'),
              ),
              const SizedBox(height: 16),
              Text(
                'Subtotal: ₹${_subtotal.toStringAsFixed(2)} • Total: ₹${_total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => context.go('/transactions'),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEditing ? 'Save changes' : 'Create transaction',
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
}
