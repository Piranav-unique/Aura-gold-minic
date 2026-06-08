import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/features/settings/presentation/providers/settings_provider.dart';
import 'package:ags_gold/features/profile/presentation/profile_dialogs.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(userSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return ResponsiveNavigationWrapper(
      title: 'Settings',
      child: settingsAsync.when(
        data: (settings) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCard(
                theme,
                'Theme Settings',
                Icons.palette_outlined,
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) {
                    ref.read(themeModeProvider.notifier).setThemeMode(s.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                theme,
                'Notification Settings',
                Icons.notifications_active_outlined,
                Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Email notifications'),
                      value: settings.notificationEmailEnabled,
                      onChanged: (v) => _saveSettings(
                        ref,
                        settings.copyWith(notificationEmailEnabled: v),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Push notifications'),
                      value: settings.notificationPushEnabled,
                      onChanged: (v) => _saveSettings(
                        ref,
                        settings.copyWith(notificationPushEnabled: v),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Security alerts'),
                      value: settings.notificationSecurityAlerts,
                      onChanged: (v) => _saveSettings(
                        ref,
                        settings.copyWith(notificationSecurityAlerts: v),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('System updates'),
                      value: settings.notificationSystemUpdates,
                      onChanged: (v) => _saveSettings(
                        ref,
                        settings.copyWith(notificationSystemUpdates: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                theme,
                'Security Settings',
                Icons.security,
                Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.password),
                      title: const Text('Change password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showChangePasswordDialog(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                theme,
                'Language Settings',
                Icons.language,
                DropdownButtonFormField<String>(
                  initialValue: settings.locale,
                  decoration: const InputDecoration(labelText: 'Language'),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'fr', child: Text('Français')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      _saveSettings(ref, settings.copyWith(locale: v));
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                theme,
                'Account Settings',
                Icons.manage_accounts,
                Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Edit profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/profile'),
                    ),
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Account status'),
                      subtitle: Text(
                        'Contact an administrator to deactivate your account.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeletonCard(),
        ),
        error: (e, _) => Center(child: Text('Failed to load settings: $e')),
      ),
    );
  }

  Widget _sectionCard(
    ThemeData theme,
    String title,
    IconData icon,
    Widget child,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings(WidgetRef ref, settings) async {
    await ref.read(updateUserSettingsProvider)(settings);
  }
}
