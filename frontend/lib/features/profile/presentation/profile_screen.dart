import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/core/widgets/premium_timeline.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/features/profile/presentation/profile_dialogs.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final activityAsync = ref.watch(profileActivityProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return ResponsiveNavigationWrapper(
      title: 'My Profile',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profileProvider);
          ref.invalidate(profileActivityProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: profileAsync.when(
            data: (user) {
              final permissions = user.effectivePermissions;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => pickAndUploadAvatar(context, ref),
                            child: Stack(
                              children: [
                                _AvatarWidget(user: user, theme: theme),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: theme.colorScheme.primary,
                                    child: Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Chip(
                                label: Text(user.isActive ? 'ACTIVE' : 'INACTIVE'),
                                backgroundColor: user.isActive
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        showEditProfileDialog(context, ref, user),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit profile',
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        showChangePasswordDialog(context, ref),
                                    icon: const Icon(Icons.lock_outline),
                                    tooltip: 'Change password',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildAccountDetails(theme, user),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 6,
                              child: _buildPermissionsCard(theme, permissions),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildAccountDetails(theme, user),
                            const SizedBox(height: 24),
                            _buildPermissionsCard(theme, permissions),
                          ],
                        ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activity Summary',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 24),
                          activityAsync.when(
                            data: (logs) => PremiumTimeline(
                              entries: logs
                                  .map(
                                    (log) => TimelineEntry(
                                      title: log.action
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                      subtitle:
                                          '${log.entityType ?? 'System'} activity',
                                      timestamp: log.timestamp,
                                      icon: Icons.history,
                                    ),
                                  )
                                  .toList(),
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, _) => Text('Failed to load activity: $e'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(64),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Card(
              color: Colors.redAccent.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Failed to load profile: $err',
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

  Widget _buildAccountDetails(ThemeData theme, UserProfile user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_border),
              title: const Text('Superuser Access'),
              subtitle: Text(
                user.isSuperuser
                    ? 'Bypass credentials checking'
                    : 'Subject to standard RBAC checks',
              ),
              trailing: Switch(value: user.isSuperuser, onChanged: null),
            ),
            const SizedBox(height: 16),
            Text(
              'Assigned Roles',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (user.roles.isEmpty)
              const Text('No roles assigned.', style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.roles
                    .map<Widget>(
                      (r) => Chip(
                        label: Text(r.name.toUpperCase()),
                        avatar: const Icon(Icons.admin_panel_settings, size: 16),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsCard(ThemeData theme, Set<String> permissions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Effective Permissions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            if (permissions.isEmpty)
              const Text('No permissions resolved.',
                  style: TextStyle(color: Colors.grey))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: permissions.length,
                separatorBuilder: (_, _) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final perm = permissions.elementAt(index);
                  return Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(perm, style: const TextStyle(fontWeight: FontWeight.w600)),
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

class _AvatarWidget extends ConsumerWidget {
  final UserProfile user;
  final ThemeData theme;

  const _AvatarWidget({required this.user, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!user.hasAvatar) {
      return _initialsAvatar();
    }

    final avatarAsync = ref.watch(avatarBytesProvider);
    return avatarAsync.when(
      data: (bytes) {
        if (bytes != null) {
          return CircleAvatar(
            radius: 36,
            backgroundImage: MemoryImage(bytes),
          );
        }
        return _initialsAvatar();
      },
      loading: () => CircleAvatar(
        radius: 36,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => _initialsAvatar(),
    );
  }

  Widget _initialsAvatar() {
    return CircleAvatar(
      radius: 36,
      backgroundColor: theme.colorScheme.primary,
      child: Text(
        user.initials,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
