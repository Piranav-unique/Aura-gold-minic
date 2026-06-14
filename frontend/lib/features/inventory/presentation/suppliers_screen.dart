import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/inventory/domain/supplier.dart';
import 'package:ags_gold/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isActive = true;
  String? _editingId;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _contactController.clear();
    _mobileController.clear();
    _emailController.clear();
    _addressController.clear();
    _isActive = true;
    _editingId = null;
  }

  void _loadSupplier(Supplier supplier) {
    _editingId = supplier.id;
    _nameController.text = supplier.name;
    _contactController.text = supplier.contactPerson ?? '';
    _mobileController.text = supplier.mobileNumber ?? '';
    _emailController.text = supplier.email ?? '';
    _addressController.text = supplier.address ?? '';
    _isActive = supplier.isActive;
  }

  Future<void> _saveSupplier() async {
    if (_nameController.text.trim().isEmpty) return;

    final supplier = Supplier(
      id: _editingId ?? '',
      name: _nameController.text.trim(),
      contactPerson: _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
      mobileNumber: _mobileController.text.trim().isEmpty
          ? null
          : _mobileController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      isActive: _isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_editingId != null) {
      await ref.read(updateSupplierProvider)(supplier);
    } else {
      await ref.read(createSupplierProvider)(supplier);
    }
    _resetForm();
    setState(() {});
  }

  Future<void> _deleteSupplier(String id) async {
    await ref.read(deleteSupplierProvider)(id);
  }

  bool _canCreate(WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    return profile != null && hasPermission(profile, 'inventory.create');
  }

  bool _canUpdate(WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    return profile != null && hasPermission(profile, 'inventory.update');
  }

  bool _canDelete(WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    return profile != null && hasPermission(profile, 'inventory.delete');
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersListProvider);
    final canCreate = _canCreate(ref);
    final canUpdate = _canUpdate(ref);
    final canDelete = _canDelete(ref);
    final canEdit = _editingId != null ? canUpdate : canCreate;

    return ResponsiveNavigationWrapper(
      title: 'Suppliers',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search suppliers...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      ref.read(suppliersSearchProvider.notifier).update(value);
                      ref.read(suppliersSkipProvider.notifier).update(0);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: suppliersAsync.when(
                      data: (page) {
                        if (page.items.isEmpty) {
                          return const EmptyStateWidget(
                            icon: Icons.local_shipping_outlined,
                            title: 'No suppliers',
                            subtitle:
                                'Add suppliers for inventory procurement.',
                          );
                        }
                        return ListView.separated(
                          itemCount: page.items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final supplier = page.items[index];
                            return ListTile(
                              title: Text(supplier.name),
                              subtitle: Text(
                                [
                                  if (supplier.contactPerson != null)
                                    supplier.contactPerson,
                                  if (supplier.mobileNumber != null)
                                    supplier.mobileNumber,
                                ].whereType<String>().join(' • '),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!supplier.isActive)
                                    const Chip(label: Text('Inactive')),
                                  if (canUpdate)
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () {
                                        _loadSupplier(supplier);
                                        setState(() {});
                                      },
                                    ),
                                  if (canDelete)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          _deleteSupplier(supplier.id),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const PremiumSkeletonList(itemCount: 5),
                      error: (e, _) => EmptyStateWidget(
                        icon: Icons.error_outline,
                        title: 'Failed to load suppliers',
                        subtitle: e.toString(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            if (canCreate || canUpdate)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingId != null ? 'Edit Supplier' : 'New Supplier',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name *',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Person',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _mobileController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: canEdit ? _saveSupplier : null,
                              child: Text(
                                _editingId != null ? 'Update' : 'Create',
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                _resetForm();
                                setState(() {});
                              },
                              child: const Text('Clear'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.go('/inventory'),
                              child: const Text('Back to Inventory'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
