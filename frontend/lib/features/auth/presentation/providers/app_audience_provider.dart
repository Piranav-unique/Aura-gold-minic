import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';

class AppAudienceNotifier extends Notifier<AppAudience?> {
  static const _prefsKey = 'app_audience';
  bool _loaded = false;

  @override
  AppAudience? build() {
    if (!_loaded) {
      _loaded = true;
      _loadPersisted();
    }
    return AppAudience.endUser;
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final loaded = switch (stored) {
      'endUser' => AppAudience.endUser,
      'staffAdmin' => AppAudience.staffAdmin,
      _ => null,
    };
    if (loaded != null) {
      state = loaded;
    }
  }

  Future<void> setAudience(AppAudience audience) async {
    state = audience;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, audience.name);
  }

  Future<void> clearAudience() async {
    state = AppAudience.endUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

final appAudienceProvider = NotifierProvider<AppAudienceNotifier, AppAudience?>(
  AppAudienceNotifier.new,
);
