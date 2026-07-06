import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ags_gold/features/settings/domain/user_settings.dart';
import 'package:ags_gold/features/settings/presentation/providers/settings_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

const _localePrefsKey = 'app_locale_code';

/// Persists UI language locally and syncs with profile settings when logged in.
class LocalePreferenceNotifier extends Notifier<Locale?> {
  Locale? _persistedLocale;
  bool _initialized = false;

  @override
  Locale? build() {
    _ensureInitialized();

    final auth = ref.watch(authNotifierProvider).value;
    if (auth == AuthStatus.authenticated) {
      final settings = ref.watch(userSettingsProvider).asData?.value;
      if (settings != null && settings.locale.isNotEmpty) {
        return _localeFromCode(settings.locale);
      }
    }

    return _persistedLocale;
  }

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    Future.microtask(_loadPersisted);

    ref.listen<AsyncValue<UserSettings>>(userSettingsProvider, (previous, next) {
      next.whenData((settings) {
        final code = settings.locale;
        if (code.isNotEmpty) {
          Future.microtask(() => setLocale(code));
        }
      });
    });
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localePrefsKey);
    if (code != null && code.isNotEmpty && ref.mounted) {
      _persistedLocale = _localeFromCode(code);
      state = _persistedLocale;
    }
  }

  Future<void> setLocale(String code) async {
    final locale = _localeFromCode(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefsKey, code);
    if (ref.mounted) {
      _persistedLocale = locale;
      state = locale;
    }
  }

  static Locale _localeFromCode(String code) =>
      Locale(code.split('_').first);
}

final localePreferenceProvider =
    NotifierProvider<LocalePreferenceNotifier, Locale?>(
  LocalePreferenceNotifier.new,
);
