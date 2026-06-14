import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/services/service_providers.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    ref.invalidate(permissionsListProvider);
  }

  void _showCreatePermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => const PermissionFormDialog(),
    ).then((updated) {
      if (updated == true) _refreshPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final permissionsAsync = ref.watch(permissionsListProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return ResponsiveNavigationWrapper(
      title: 'Permissions Reference',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'System Permission Scopes',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _showCreatePermissionDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Scope'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Permissions',
                    hintText: 'Search permission name or description...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Permissions list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshPermissions,
                child: permissionsAsync.when(
                  data: (permissions) {
                    final filtered = permissions.where((p) {
                      final name = (p['name'] as String? ?? '').toLowerCase();
                      final desc = (p['description'] as String? ?? '')
                          .toLowerCase();
                      return name.contains(_searchQuery) ||
                          desc.contains(_searchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return ListView(
                        children: [
                          const SizedBox(height: 64),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.vpn_key_outlined,
                                  size: 64,
                                  color: theme.colorScheme.secondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No permission scopes defined in the database.'
                                      : 'No matching permission scopes found.',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return isDesktop
                        ? Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, idx) =>
                                  _buildPermissionListTile(
                                    filtered[idx] as Map<String, dynamic>,
                                  ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, idx) => _buildPermissionCard(
                              filtered[idx] as Map<String, dynamic>,
                            ),
                          );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => ListView(
                    children: [
                      const SizedBox(height: 64),
                      Center(
                        child: Text(
                          'Failed to load permission scopes: $err',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
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

  Widget _buildPermissionListTile(Map<String, dynamic> perm) {
    final theme = Theme.of(context);
    final name = perm['name'] as String? ?? '';
    final description = perm['description'] as String? ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: const Icon(Icons.key, size: 18),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Courier',
        ),
      ),
      subtitle: Text(description),
      trailing: const Chip(
        label: Text('READ-ONLY REFERENCE'),
        labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPermissionCard(Map<String, dynamic> perm) {
    final theme = Theme.of(context);
    final name = perm['name'] as String? ?? '';
    final description = perm['description'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.key, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Courier',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class PermissionFormDialog extends ConsumerStatefulWidget {
  const PermissionFormDialog({super.key});

  @override
  ConsumerState<PermissionFormDialog> createState() =>
      _PermissionFormDialogState();
}

class _PermissionFormDialogState extends ConsumerState<PermissionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      await apiClient.post(
        '/rbac/permissions',
        data: {'name': name, 'description': description},
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Permission Scope'),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Permission Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Permission Name',
                  helperText: 'Use dot-separated scopes, e.g. domain.action',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Permission Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  helperText: 'Describe what operations this scope permits',
                ),
                maxLines: 2,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
