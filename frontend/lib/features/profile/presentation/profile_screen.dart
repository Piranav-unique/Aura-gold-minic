import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/services/service_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return ResponsiveNavigationWrapper(
      title: 'My Profile',
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(profileProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: profileAsync.when(
            data: (user) {
              final email = user['email'] ?? '';
              final firstName = user['first_name'] ?? '';
              final lastName = user['last_name'] ?? '';
              final isSuperuser = user['is_superuser'] ?? false;
              final isActive = user['is_active'] ?? false;
              final roles = user['roles'] as List<dynamic>? ?? [];

              // Aggregate all permissions from roles
              final permissions = <String>{};
              if (isSuperuser) {
                permissions.add('* (Full System Bypass)');
              } else {
                for (var r in roles) {
                  final perms = r['permissions'] as List<dynamic>? ?? [];
                  for (var p in perms) {
                    permissions.add(p['name'] as String);
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$firstName $lastName',
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(isActive ? 'ACTIVE' : 'INACTIVE'),
                            backgroundColor: isActive
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            labelStyle: TextStyle(
                              color: isActive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Responsiveness block
                  isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildAccountDetails(theme, isSuperuser, roles)),
                            const SizedBox(width: 24),
                            Expanded(flex: 6, child: _buildPermissionsCard(theme, permissions)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildAccountDetails(theme, isSuperuser, roles),
                            const SizedBox(height: 24),
                            _buildPermissionsCard(theme, permissions),
                          ],
                        ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(64.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, stack) => Card(
              color: Colors.redAccent.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'Failed to load profile details: $err',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDetails(ThemeData theme, bool isSuperuser, List<dynamic> roles) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_border),
              title: const Text('Superuser Access'),
              subtitle: Text(isSuperuser ? 'Bypass credentials checking' : 'Subject to standard RBAC checks'),
              trailing: Switch(
                value: isSuperuser,
                onChanged: null, // Read-only
              ),
            ),
            const SizedBox(height: 16),
            Text('Assigned Roles', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (roles.isEmpty)
              const Text('No roles explicitly assigned.', style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: roles.map((r) {
                  final name = r['name'] as String? ?? '';
                  return Chip(
                    label: Text(name.toUpperCase()),
                    avatar: const Icon(Icons.admin_panel_settings, size: 16),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsCard(ThemeData theme, Set<String> permissions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Effective Permissions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            if (permissions.isEmpty)
              const Text('No permissions resolved.', style: TextStyle(color: Colors.grey))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: permissions.length,
                separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final perm = permissions.elementAt(index);
                  return Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        perm,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
