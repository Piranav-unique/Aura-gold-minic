import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/services/service_providers.dart';

class RolesScreen extends ConsumerStatefulWidget {
  const RolesScreen({super.key});

  @override
  ConsumerState<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends ConsumerState<RolesScreen> {
  Future<void> _refreshRoles() async {
    ref.invalidate(rolesListProvider);
  }

  void _showCreateRoleDialog() {
    showDialog(
      context: context,
      builder: (context) => const RoleFormDialog(),
    ).then((updated) {
      if (updated == true) _refreshRoles();
    });
  }

  void _showEditRoleDialog(Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (context) => RoleFormDialog(role: role),
    ).then((updated) {
      if (updated == true) _refreshRoles();
    });
  }

  Future<void> _deleteRole(Map<String, dynamic> role) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final apiClient = ref.read(apiClientProvider);
    final id = role['id'] as String;
    final name = role['name'] as String? ?? 'this role';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text(
          'Are you sure you want to delete the role "${name.toUpperCase()}"? This action is soft-delete and reversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await apiClient.delete('/rbac/roles/$id');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Role deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshRoles();
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete role: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesListProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return ResponsiveNavigationWrapper(
      title: 'Role Management',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Access Control Roles',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _showCreateRoleDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('New Role'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshRoles,
                child: rolesAsync.when(
                  data: (roles) {
                    if (roles.isEmpty) {
                      return ListView(
                        children: [
                          const SizedBox(height: 64),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 64,
                                  color: theme.colorScheme.secondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No roles exist in the database.',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return isDesktop
                        ? GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.3,
                                ),
                            itemCount: roles.length,
                            itemBuilder: (context, idx) => _buildRoleCard(
                              roles[idx] as Map<String, dynamic>,
                            ),
                          )
                        : ListView.separated(
                            itemCount: roles.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, idx) => _buildRoleCard(
                              roles[idx] as Map<String, dynamic>,
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
                          'Error loading roles list: $err',
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

  Widget _buildRoleCard(Map<String, dynamic> role) {
    final theme = Theme.of(context);
    final name = role['name'] as String? ?? '';
    final description = role['description'] as String? ?? '';
    final permissions = role['permissions'] as List<dynamic>? ?? [];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showEditRoleDialog(role),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showEditRoleDialog(role);
                      } else if (val == 'delete') {
                        _deleteRole(role);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Role'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 18,
                              color: theme.colorScheme.error,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete Role',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description.isNotEmpty
                    ? description
                    : 'No description provided.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              const Divider(height: 16),
              Row(
                children: [
                  Text(
                    '${permissions.length} Permissions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: -6,
                    children: permissions.take(3).map((p) {
                      return CircleAvatar(
                        radius: 10,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: const Icon(Icons.check, size: 10),
                      );
                    }).toList(),
                  ),
                  if (permissions.length > 3) ...[
                    const SizedBox(width: 4),
                    Text(
                      '+${permissions.length - 3}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? role;

  const RoleFormDialog({super.key, this.role});

  @override
  ConsumerState<RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends ConsumerState<RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _selectedPermissionIds = [];
  bool _loading = false;
  String? _errorMessage;

  bool get isEdit => widget.role != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final r = widget.role!;
      _nameController.text = r['name'] ?? '';
      _descriptionController.text = r['description'] ?? '';
      final permissions = r['permissions'] as List<dynamic>? ?? [];
      for (var p in permissions) {
        _selectedPermissionIds.add(p['id'] as String);
      }
    }
  }

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

      if (isEdit) {
        final id = widget.role!['id'] as String;
        // Update basic role details
        await apiClient.put(
          '/rbac/roles/$id',
          data: {'name': name, 'description': description},
        );

        // Sync permissions (Note: In the backend, we assign/remove individual mappings)
        final originalPermIds = (widget.role!['permissions'] as List<dynamic>)
            .map((p) => p['id'] as String)
            .toList();

        final toAdd = _selectedPermissionIds
            .where((id) => !originalPermIds.contains(id))
            .toList();
        final toRemove = originalPermIds
            .where((id) => !_selectedPermissionIds.contains(id))
            .toList();

        for (var permId in toAdd) {
          await apiClient.post(
            '/rbac/roles/$id/permissions',
            queryParameters: {'permission_id': permId},
          );
        }

        for (var permId in toRemove) {
          await apiClient.delete('/rbac/roles/$id/permissions/$permId');
        }
      } else {
        // Create role
        final response = await apiClient.post(
          '/rbac/roles',
          data: {'name': name, 'description': description},
        );
        final newRole = response.data as Map<String, dynamic>;
        final newRoleId = newRole['id'] as String;

        // Associate permissions
        for (var permId in _selectedPermissionIds) {
          await apiClient.post(
            '/rbac/roles/$newRoleId/permissions',
            queryParameters: {'permission_id': permId},
          );
        }
      }

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
    final permissionsAsync = ref.watch(permissionsListProvider);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(isEdit ? 'Edit Role Details' : 'Create Access Role'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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

                // Role Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Role Name',
                    helperText: 'Use lowercase, e.g. operator_level_1',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Role Name is required';
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
                    helperText: 'Explains permissions scope of this role',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Permissions Checklist
                Text(
                  'Map Permissions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 16),

                permissionsAsync.when(
                  data: (permissionsList) {
                    if (permissionsList.isEmpty) {
                      return const Text(
                        'No permissions in system database.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      );
                    }
                    return Column(
                      children: permissionsList.map((p) {
                        final id = p['id'] as String;
                        final name = p['name'] as String;
                        final isSelected = _selectedPermissionIds.contains(id);

                        return CheckboxListTile(
                          title: Text(name),
                          subtitle: Text(p['description'] ?? ''),
                          value: isSelected,
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedPermissionIds.add(id);
                              } else {
                                _selectedPermissionIds.remove(id);
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (err, stack) => Text(
                    'Failed to load permissions: $err',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
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
