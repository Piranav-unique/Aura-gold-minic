import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/features/settings/presentation/providers/settings_provider.dart';
import 'package:ags_gold/features/profile/presentation/profile_dialogs.dart';
import 'package:ags_gold/l10n/app_languages.dart';
import 'package:ags_gold/l10n/locale_preference_provider.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/widgets/theme_mode_picker.dart';
import 'package:ags_gold/features/app_update/services/app_update_coordinator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settingsAsync = ref.watch(userSettingsProvider);
    final theme = Theme.of(context);

    return ResponsiveNavigationWrapper(
      title: l10n.settings,
      child: settingsAsync.when(
        data: (settings) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCard(
                theme,
                l10n.themeSettings,
                Icons.palette_outlined,
                const ThemeModePicker(),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                theme,
                l10n.securitySettings,
                Icons.security,
                Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.password),
                      title: Text(l10n.changePassword),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showChangePasswordDialog(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                theme,
                l10n.languageSettings,
                Icons.language,
                DropdownButtonFormField<String>(
                  initialValue: settings.locale,
                  decoration: InputDecoration(labelText: l10n.languageLabel),
                  items: [
                    for (final option in kAppLanguageOptions)
                      DropdownMenuItem(
                        value: option.code,
                        child: Text(option.nativeLabel),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      _saveSettings(ref, settings.copyWith(locale: v));
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (!kIsWeb && Platform.isAndroid)
                _sectionCard(
                  theme,
                  l10n.appVersionLabel,
                  Icons.system_update_alt_outlined,
                  const _AppUpdateSection(),
                ),
              if (!kIsWeb && Platform.isAndroid) const SizedBox(height: 16),
              _sectionCard(
                theme,
                l10n.accountSettings,
                Icons.manage_accounts,
                Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(l10n.editProfile),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/profile'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.accountStatus),
                      subtitle: Text(l10n.accountStatusHint),
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
        error: (e, _) => Center(child: Text(l10n.failedToLoadSettings('$e'))),
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
    final locale = settings.locale;
    if (locale != null && locale.isNotEmpty) {
      await ref.read(localePreferenceProvider.notifier).setLocale(locale);
    }
  }
}

class _AppUpdateSection extends ConsumerStatefulWidget {
  const _AppUpdateSection();

  @override
  ConsumerState<_AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends ConsumerState<_AppUpdateSection> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        final versionLabel = snapshot.hasData
            ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
            : '…';

        return Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.appVersionLabel),
              subtitle: Text(versionLabel),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => ref
                    .read(appUpdateCoordinatorProvider)
                    .checkAndPrompt(context, manual: true),
                icon: const Icon(Icons.download_rounded),
                label: Text(l10n.checkForUpdates),
              ),
            ),
          ],
        );
      },
    );
  }
}
