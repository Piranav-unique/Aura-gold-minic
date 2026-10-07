import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/theme_mode_picker.dart';
import 'package:ags_gold/features/app_update/services/app_update_coordinator.dart';
import 'package:ags_gold/features/settings/domain/user_settings.dart';
import 'package:ags_gold/features/settings/presentation/providers/settings_provider.dart';
import 'package:ags_gold/l10n/app_languages.dart';
import 'package:ags_gold/l10n/locale_preference_provider.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/services/biometric_auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settingsAsync = ref.watch(userSettingsProvider);

    return ResponsiveNavigationWrapper(
      title: l10n.settings,
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(userSettingsProvider.future),
        child: settingsAsync.when(
          data: (settings) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. THEME MODE
                _sectionCard(
                  context,
                  title: l10n.themeSettings,
                  icon: Icons.palette_outlined,
                  child: const ThemeModePicker(),
                ),
                const SizedBox(height: 16),

                // 2. LANGUAGE
                _sectionCard(
                  context,
                  title: l10n.languageSettings,
                  icon: Icons.translate_rounded,
                  child: _LanguageSelector(settings: settings),
                ),
                const SizedBox(height: 16),

                // 3. BIOMETRIC SECURITY
                _sectionCard(
                  context,
                  title: 'Security & App Lock',
                  icon: Icons.security_outlined,
                  child: const _BiometricSecuritySection(),
                ),
                const SizedBox(height: 16),

                // 4. APP VERSION & UPDATES
                if (!kIsWeb && Platform.isAndroid) ...[
                  _sectionCard(
                    context,
                    title: l10n.appVersionLabel,
                    icon: Icons.system_update_alt_outlined,
                    child: const _AppUpdateSection(),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: PremiumSkeletonCard(),
          ),
          error: (_, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionCard(
                  context,
                  title: l10n.themeSettings,
                  icon: Icons.palette_outlined,
                  child: const ThemeModePicker(),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: 'Security & App Lock',
                  icon: Icons.security_outlined,
                  child: const _BiometricSecuritySection(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: isDark ? 0.15 : 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.primaryGold, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _LanguageSelector extends ConsumerWidget {
  final UserSettings settings;

  const _LanguageSelector({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localePreferenceProvider)?.languageCode ??
        settings.locale;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        for (final option in kAppLanguageOptions)
          InkWell(
            onTap: () async {
              await ref
                  .read(localePreferenceProvider.notifier)
                  .setLocale(option.code);
              await ref.read(updateUserSettingsProvider)(
                settings.copyWith(locale: option.code),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: currentLocale == option.code
                    ? AppTheme.primaryGold.withValues(alpha: isDark ? 0.2 : 0.1)
                    : isDark
                        ? theme.colorScheme.surface
                        : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: currentLocale == option.code
                      ? AppTheme.primaryGold
                      : theme.dividerColor.withValues(alpha: 0.15),
                  width: currentLocale == option.code ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    option.nativeLabel,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: currentLocale == option.code
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: currentLocale == option.code
                          ? (isDark ? AppTheme.primaryGold : AppTheme.goldDeep)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF332A15)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      option.code.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.primaryGold
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (currentLocale == option.code)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
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

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appVersionLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    versionLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => ref
                  .read(appUpdateCoordinatorProvider)
                  .checkAndPrompt(context, manual: true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.ink,
                elevation: 0,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(
                l10n.checkForUpdates,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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

    return Material(
      type: MaterialType.transparency,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Biometric & Screen Lock',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Require fingerprint, face unlock, or device PIN to protect your wallet and account access.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: biometricEnabled,
            activeTrackColor: AppTheme.primaryGold,
            onChanged: (val) async {
              final success =
                  await ref.read(biometricLockEnabledProvider.notifier).toggle(val);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Biometric verification failed or was cancelled.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
