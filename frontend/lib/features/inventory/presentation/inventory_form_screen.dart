import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/inventory/domain/inventory_item.dart';
import 'package:ags_gold/features/inventory/presentation/providers/inventory_provider.dart';

class InventoryFormScreen extends ConsumerStatefulWidget {
  final String? itemId;

  const InventoryFormScreen({super.key, this.itemId});

  bool get isEdit => itemId != null;

  @override
  ConsumerState<InventoryFormScreen> createState() =>
      _InventoryFormScreenState();
}

class _InventoryFormScreenState extends ConsumerState<InventoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _purityController = TextEditingController();
  final _purchaseController = TextEditingController();
  final _valueController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _reorderController = TextEditingController(text: '5');
  final _notesController = TextEditingController();

  String _category = 'gold_bar';
  String _status = 'active';
  String? _supplierId;
  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _purityController.dispose();
    _purchaseController.dispose();
    _valueController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateForm(InventoryItem item) {
    if (_initialized) return;
    _nameController.text = item.itemName;
    _weightController.text = item.weight.toString();
    _purityController.text = item.purity.toString();
    _purchaseController.text = item.purchasePrice.toString();
    _valueController.text = item.currentValue.toString();
    _reorderController.text = item.reorderLevel.toString();
    _notesController.text = item.notes ?? '';
    _category = item.itemCategory;
    _status = item.status;
    _supplierId = item.supplierId;
    _initialized = true;
  }

  double? _parseDouble(String value) => double.tryParse(value.trim());

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.isEdit) {
        final existing = await ref.read(
          inventoryDetailProvider(widget.itemId!).future,
        );
        final updated = existing.copyWith(
          itemName: _nameController.text.trim(),
          itemCategory: _category,
          weight: _parseDouble(_weightController.text)!,
          purity: _parseDouble(_purityController.text)!,
          purchasePrice: _parseDouble(_purchaseController.text)!,
          currentValue: _parseDouble(_valueController.text)!,
          reorderLevel: int.parse(_reorderController.text.trim()),
          supplierId: _supplierId,
          status: _status,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
        await ref.read(updateInventoryProvider)(updated);
        if (!mounted) return;
        context.go('/inventory/${widget.itemId}');
      } else {
        final item = InventoryItem(
          id: '',
          itemName: _nameController.text.trim(),
          itemCategory: _category,
          weight: _parseDouble(_weightController.text)!,
          purity: _parseDouble(_purityController.text)!,
          purchasePrice: _parseDouble(_purchaseController.text)!,
          currentValue: _parseDouble(_valueController.text)!,
          stockQuantity: int.parse(_stockController.text.trim()),
          reorderLevel: int.parse(_reorderController.text.trim()),
          supplierId: _supplierId,
          status: _status,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final created = await ref.read(createInventoryProvider)(item);
        if (!mounted) return;
        context.go('/inventory/${created.id}');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersListProvider);

    if (widget.isEdit) {
      ref
          .watch(inventoryDetailProvider(widget.itemId!))
          .whenData(_populateForm);
    }

    return ResponsiveNavigationWrapper(
      title: widget.isEdit ? 'Edit Inventory Item' : 'New Inventory Item',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category *'),
                items: inventoryCategoryOptions
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight (g) *',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => _parseDouble(v ?? '') == null
                          ? 'Invalid weight'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _purityController,
                      decoration: const InputDecoration(
                        labelText: 'Purity (%) *',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final p = _parseDouble(v ?? '');
                        if (p == null || p <= 0 || p > 100) {
                          return 'Invalid purity';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchaseController,
                      decoration: const InputDecoration(
                        labelText: 'Purchase Price *',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => _parseDouble(v ?? '') == null
                          ? 'Invalid price'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _valueController,
                      decoration: const InputDecoration(
                        labelText: 'Current Value *',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => _parseDouble(v ?? '') == null
                          ? 'Invalid value'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!widget.isEdit)
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(
                    labelText: 'Initial Stock *',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 0) return 'Invalid quantity';
                    return null;
                  },
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reorderController,
                decoration: const InputDecoration(labelText: 'Reorder Level *'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0) return 'Invalid reorder level';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              suppliersAsync.when(
                data: (page) => DropdownButtonFormField<String?>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...page.items.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status *'),
                items: inventoryStatusOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.isEdit ? 'Save Changes' : 'Create Item'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => context.go('/inventory'),
                    child: const Text('Cancel'),
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
