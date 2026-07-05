import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/services/service_providers.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Synchronize controller with provider state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchController.text = ref.read(usersSearchQueryProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshUsers() async {
    ref.invalidate(usersListProvider);
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (context) => const UserFormDialog(),
    ).then((updated) {
      if (updated == true) _refreshUsers();
    });
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(user: user),
    ).then((updated) {
      if (updated == true) _refreshUsers();
    });
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final apiClient = ref.read(apiClientProvider);
    final id = user['id'] as String;
    final currentStatus = user['is_active'] as bool? ?? false;
    final newStatus = !currentStatus;

    try {
      await apiClient.put('/users/$id', data: {'is_active': newStatus});
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'User status updated to ${newStatus ? 'Active' : 'Inactive'}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _refreshUsers();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final apiClient = ref.read(apiClientProvider);
    final id = user['id'] as String;
    final email = user['email'] as String? ?? 'this user';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete $email? This action is soft-delete and reversible in DB.',
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
        await apiClient.delete('/users/$id');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshUsers();
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);
    final rolesAsync = ref.watch(rolesListProvider);
    final search = ref.watch(usersSearchQueryProvider);
    final isActive = ref.watch(usersIsActiveFilterProvider);
    final isSuperuser = ref.watch(usersIsSuperuserFilterProvider);
    final roleId = ref.watch(usersRoleIdFilterProvider);

    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return ResponsiveNavigationWrapper(
      title: 'User Management',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header actions row
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Manage Operators',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _showCreateUserDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('New User'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search and Filters Panel
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: isDesktop
                    ? _buildDesktopFilters(
                        search: search,
                        isActive: isActive,
                        isSuperuser: isSuperuser,
                        roleId: roleId,
                        rolesAsync: rolesAsync,
                      )
                    : _buildMobileFilters(
                        search: search,
                        isActive: isActive,
                        isSuperuser: isSuperuser,
                        roleId: roleId,
                        rolesAsync: rolesAsync,
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // User Listing Section
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshUsers,
                child: usersAsync.when(
                  data: (users) {
                    if (users.isEmpty) {
                      return ListView(
                        children: [
                          const SizedBox(height: 64),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: theme.colorScheme.secondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No users found matching current filters.',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return isDesktop
                        ? _buildUserTable(users)
                        : _buildUserCards(users);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => ListView(
                    children: [
                      const SizedBox(height: 64),
                      Center(
                        child: Text(
                          'Error loading users list: $err',
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

  Widget _buildSearchField(String search) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search Operators',
        hintText: 'Search email, first or last name...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: search.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  ref.read(usersSearchQueryProvider.notifier).state = '';
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onSubmitted: (val) {
        ref.read(usersSearchQueryProvider.notifier).state = val;
      },
    );
  }

  Widget _buildRoleFilter(
    AsyncValue<List<dynamic>> rolesAsync,
    String? roleId,
  ) {
    return rolesAsync.when(
      data: (rolesList) {
        return DropdownButtonFormField<String?>(
          initialValue: roleId,
          decoration: const InputDecoration(
            labelText: 'Role',
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Roles')),
            ...rolesList.map(
              (r) => DropdownMenuItem(
                value: r['id'] as String,
                child: Text((r['name'] as String).toUpperCase()),
              ),
            ),
          ],
          onChanged: (val) {
            ref.read(usersRoleIdFilterProvider.notifier).state = val;
          },
        );
      },
      loading: () => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildActiveFilter(bool? isActive) {
    return DropdownButtonFormField<bool?>(
      initialValue: isActive,
      decoration: const InputDecoration(
        labelText: 'Active Status',
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('All Statuses')),
        DropdownMenuItem(value: true, child: Text('Active Only')),
        DropdownMenuItem(value: false, child: Text('Inactive Only')),
      ],
      onChanged: (val) {
        ref.read(usersIsActiveFilterProvider.notifier).state = val;
      },
    );
  }

  Widget _buildSuperuserFilter(bool? isSuperuser) {
    return DropdownButtonFormField<bool?>(
      initialValue: isSuperuser,
      decoration: const InputDecoration(
        labelText: 'Account Level',
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('All Levels')),
        DropdownMenuItem(value: true, child: Text('Superusers Only')),
        DropdownMenuItem(value: false, child: Text('Standard Users Only')),
      ],
      onChanged: (val) {
        ref.read(usersIsSuperuserFilterProvider.notifier).state = val;
      },
    );
  }

  Widget _buildDesktopFilters({
    required String search,
    required bool? isActive,
    required bool? isSuperuser,
    required String? roleId,
    required AsyncValue<List<dynamic>> rolesAsync,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: _buildSearchField(search)),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildRoleFilter(rolesAsync, roleId),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildActiveFilter(isActive)),
            const SizedBox(width: 16),
            Expanded(child: _buildSuperuserFilter(isSuperuser)),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileFilters({
    required String search,
    required bool? isActive,
    required bool? isSuperuser,
    required String? roleId,
    required AsyncValue<List<dynamic>> rolesAsync,
  }) {
    return Column(
      children: [
        _buildSearchField(search),
        const SizedBox(height: 16),
        _buildRoleFilter(rolesAsync, roleId),
        const SizedBox(height: 16),
        _buildActiveFilter(isActive),
        const SizedBox(height: 16),
        _buildSuperuserFilter(isSuperuser),
      ],
    );
  }

  Widget _buildUserTable(List<dynamic> users) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Roles')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: users.map((u) {
            final userMap = u as Map<String, dynamic>;
            final firstName = userMap['first_name'] ?? '';
            final lastName = userMap['last_name'] ?? '';
            final email = userMap['email'] ?? '';
            final isSuper = userMap['is_superuser'] as bool? ?? false;
            final isActive = userMap['is_active'] as bool? ?? false;
            final roles = userMap['roles'] as List<dynamic>? ?? [];

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    '$firstName $lastName'.trim().isNotEmpty
                        ? '$firstName $lastName'
                        : '-',
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(email),
                      if (isSuper) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Superuser access',
                          child: Icon(
                            Icons.security,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                DataCell(
                  Wrap(
                    spacing: 4,
                    children: roles
                        .map(
                          (r) => Chip(
                            label: Text(
                              (r['name'] as String).toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ),
                DataCell(
                  Switch(
                    value: isActive,
                    onChanged: (val) => _toggleUserStatus(userMap),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditUserDialog(userMap),
                        tooltip: 'Edit Operator',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          size: 20,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => _deleteUser(userMap),
                        tooltip: 'Delete Operator',
                      ),
                    ],
                  ),
                ),
              ],
            );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserCards(List<dynamic> users) {
    final theme = Theme.of(context);

    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final userMap = users[index] as Map<String, dynamic>;
        final firstName = userMap['first_name'] ?? '';
        final lastName = userMap['last_name'] ?? '';
        final email = userMap['email'] ?? '';
        final isSuper = userMap['is_superuser'] as bool? ?? false;
        final isActive = userMap['is_active'] as bool? ?? false;
        final roles = userMap['roles'] as List<dynamic>? ?? [];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$firstName $lastName'.trim().isNotEmpty
                                ? '$firstName $lastName'
                                : 'Unnamed Operator',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(email, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    Switch(
                      value: isActive,
                      onChanged: (val) => _toggleUserStatus(userMap),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isSuper) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.security,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Superuser account',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Assigned Roles:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                if (roles.isEmpty)
                  const Text(
                    'No roles assigned',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  )
                else
                  Wrap(
                    spacing: 4,
                    children: roles
                        .map(
                          (r) => Chip(
                            label: Text(
                              (r['name'] as String).toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditUserDialog(userMap),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => _deleteUser(userMap),
                      icon: Icon(
                        Icons.delete,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class UserFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? user;

  const UserFormDialog({super.key, this.user});

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isActive = true;
  bool _isSuperuser = false;
  final List<String> _selectedRoleIds = [];
  bool _loading = false;
  String? _errorMessage;

  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final u = widget.user!;
      _emailController.text = u['email'] ?? '';
      _firstNameController.text = u['first_name'] ?? '';
      _lastNameController.text = u['last_name'] ?? '';
      _isActive = u['is_active'] as bool? ?? true;
      _isSuperuser = u['is_superuser'] as bool? ?? false;
      final roles = u['roles'] as List<dynamic>? ?? [];
      for (var r in roles) {
        _selectedRoleIds.add(r['id'] as String);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    final payload = <String, dynamic>{
      'email': _emailController.text.trim(),
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'is_active': _isActive,
      'is_superuser': _isSuperuser,
      'roles': _selectedRoleIds,
    };

    if (_passwordController.text.isNotEmpty || !isEdit) {
      payload['password'] = _passwordController.text;
    }

    try {
      if (isEdit) {
        final id = widget.user!['id'] as String;
        await apiClient.put('/users/$id', data: payload);
      } else {
        await apiClient.post('/users/', data: payload);
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
    final rolesAsync = ref.watch(rolesListProvider);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(isEdit ? 'Edit Operator Profile' : 'Create New Operator'),
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

                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!val.contains('@')) return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: isEdit
                        ? 'Change Password (Optional)'
                        : 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    helperText: isEdit
                        ? 'Leave empty to keep existing password'
                        : 'Minimum 8 characters',
                  ),
                  obscureText: true,
                  validator: (val) {
                    if (!isEdit && (val == null || val.isEmpty)) {
                      return 'Password is required';
                    }
                    if (val != null && val.isNotEmpty && val.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // First/Last Name
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Switches
                SwitchListTile(
                  title: const Text('Active Account'),
                  subtitle: const Text(
                    'Enable/disable user session authorization',
                  ),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Superuser Permissions'),
                  subtitle: const Text(
                    'Grants full database/action security bypasses',
                  ),
                  value: _isSuperuser,
                  onChanged: (val) => setState(() => _isSuperuser = val),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),

                // Roles check list
                Text(
                  'Assigned Roles',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 16),

                rolesAsync.when(
                  data: (rolesList) {
                    if (rolesList.isEmpty) {
                      return const Text(
                        'No roles found in system database.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      );
                    }
                    return Column(
                      children: rolesList.map((r) {
                        final id = r['id'] as String;
                        final name = r['name'] as String;
                        final isSelected = _selectedRoleIds.contains(id);

                        return CheckboxListTile(
                          title: Text(name.toUpperCase()),
                          subtitle: Text(r['description'] ?? ''),
                          value: isSelected,
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedRoleIds.add(id);
                              } else {
                                _selectedRoleIds.remove(id);
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
                    'Failed to load roles: $err',
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
