import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/presentation/providers/app_audience_provider.dart';
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
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/services/biometric_auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settingsAsync = ref.watch(userSettingsProvider);
    final theme = Theme.of(context);
    final audience = ref.watch(appAudienceProvider);

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
                l10n.languageSettings,
                Icons.language,
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF8F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFC59A27).withValues(alpha: 0.3),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: DropdownButtonFormField<String>(
                    initialValue: settings.locale,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFFC59A27),
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.languageLabel,
                      labelStyle: const TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: const Icon(
                        Icons.translate_rounded,
                        color: Color(0xFFC59A27),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      for (final option in kAppLanguageOptions)
                        DropdownMenuItem(
                          value: option.code,
                          child: Row(
                            children: [
                              Text(
                                option.nativeLabel,
                                style: TextStyle(
                                  fontWeight: settings.locale == option.code
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: const Color(0xFF1E1B18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  option.code.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                              if (settings.locale == option.code) ...[
                                const Spacer(),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFFC59A27),
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _saveSettings(ref, settings.copyWith(locale: v));
                      }
                    },
                  ),
                ),
              ),
              _sectionCard(
                theme,
                'Security & App Lock',
                Icons.security_outlined,
                const _BiometricSecuritySection(),
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
                    if (audience == AppAudience.endUser)
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever_outlined,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(l10n.deleteAccount),
                        subtitle: Text(l10n.accountStatusHint),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showDeleteAccountDialog(context, ref),
                      )
                    else
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

class _BiometricSecuritySection extends ConsumerWidget {
  const _BiometricSecuritySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometricEnabled =
        ref.watch(biometricLockEnabledProvider).value ?? false;
    final theme = Theme.of(context);

    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Biometric & Screen Lock',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Require fingerprint, face unlock, or device PIN to protect your wallet and account access.',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
        ),
      ),
      secondary: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryGold),
      value: biometricEnabled,
      onChanged: (val) async {
        final success =
            await ref.read(biometricLockEnabledProvider.notifier).toggle(val);
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric verification failed or was cancelled.'),
            ),
          );
        }
      },
    );
  }
}
