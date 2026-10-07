import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/settings/domain/user_settings.dart';
import 'package:ags_gold/l10n/locale_preference_provider.dart';

final userSettingsProvider = FutureProvider.autoDispose<UserSettings>((
  ref,
) async {
  final auth = await ref.watch(authNotifierProvider.future);
  if (auth != AuthStatus.authenticated) {
    return const UserSettings();
  }
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get('/profile/settings');
    return UserSettings.fromJson(response.data as Map<String, dynamic>);
  } catch (_) {
    // If backend returns 404/error or user has no saved settings row, use local defaults
    final locale = ref.watch(localePreferenceProvider)?.languageCode ?? 'en';
    return UserSettings(locale: locale);
  }
});

final updateUserSettingsProvider =
    Provider<Future<UserSettings> Function(UserSettings)>((ref) {
      return (UserSettings settings) async {
        final apiClient = ref.read(apiClientProvider);
        try {
          final response = await apiClient.put(
            '/profile/settings',
            data: settings.toJson(),
          );
          ref.invalidate(userSettingsProvider);
          return UserSettings.fromJson(response.data as Map<String, dynamic>);
        } catch (_) {
          // If backend update fails, still persist locale locally
          if (settings.locale.isNotEmpty) {
            await ref
                .read(localePreferenceProvider.notifier)
                .setLocale(settings.locale);
          }
          ref.invalidate(userSettingsProvider);
          return settings;
        }
      };
    });
