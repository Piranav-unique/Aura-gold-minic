import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ags_gold/config/env_config.dart';
import 'package:ags_gold/services/interfaces/secure_storage.dart';
import 'package:ags_gold/services/secure_storage_service.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/features/audit_logs/domain/audit_log.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthNotifier extends AsyncNotifier<AuthStatus> {
  late final ISecureStorage _storage;

  @override
  FutureOr<AuthStatus> build() async {
    _storage = ref.watch(secureStorageProvider);
    final hasToken = await _storage.hasAccessToken();
    return hasToken ? AuthStatus.authenticated : AuthStatus.unauthenticated;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      state = const AsyncValue.data(AuthStatus.authenticated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      final apiClient = ref.read(apiClientProvider);
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null) {
        try {
          await apiClient.post(
            '/auth/logout',
            data: {'refresh_token': refreshToken},
          );
        } catch (_) {}
      }
      await _storage.clearTokens();
      state = const AsyncValue.data(AuthStatus.unauthenticated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clearSession() async {
    await _storage.clearTokens();
    state = const AsyncValue.data(AuthStatus.unauthenticated);
  }
}

final envConfigProvider = Provider<EnvConfig>((ref) => EnvConfig.active);

final secureStorageProvider = Provider<ISecureStorage>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final env = ref.watch(envConfigProvider);
  return ApiClient(
    storageService: storage,
    config: env,
    onUnauthorized: () {
      ref.read(authNotifierProvider.notifier).clearSession();
    },
  );
});

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthStatus>(
  AuthNotifier.new,
);

final auditLogsProvider = FutureProvider.autoDispose<List<AuditLog>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get('/audit-logs/', queryParameters: {
      'limit': 10,
    });
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/profile/');
  return UserProfile.fromJson(response.data as Map<String, dynamic>);
});

final avatarBytesProvider = FutureProvider.autoDispose<Uint8List?>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (!profile.hasAvatar) return null;
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.getBytes('/profile/avatar');
  final data = response.data;
  if (data == null) return null;
  return Uint8List.fromList(data);
});

final profileActivityProvider =
    FutureProvider.autoDispose<List<AuditLog>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/profile/activity');
  final data = response.data as Map<String, dynamic>;
  final items = data['items'] as List<dynamic>? ?? [];
  return items
      .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
      .toList();
});

class UsersSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  @override
  set state(String value) => super.state = value;
}

final usersSearchQueryProvider =
    NotifierProvider<UsersSearchQueryNotifier, String>(
  UsersSearchQueryNotifier.new,
);

class UsersIsActiveFilterNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;
  @override
  set state(bool? value) => super.state = value;
}

final usersIsActiveFilterProvider =
    NotifierProvider<UsersIsActiveFilterNotifier, bool?>(
  UsersIsActiveFilterNotifier.new,
);

class UsersIsSuperuserFilterNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;
  @override
  set state(bool? value) => super.state = value;
}

final usersIsSuperuserFilterProvider =
    NotifierProvider<UsersIsSuperuserFilterNotifier, bool?>(
  UsersIsSuperuserFilterNotifier.new,
);

class UsersRoleIdFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  @override
  set state(String? value) => super.state = value;
}

final usersRoleIdFilterProvider =
    NotifierProvider<UsersRoleIdFilterNotifier, String?>(
  UsersRoleIdFilterNotifier.new,
);

class UsersLimitNotifier extends Notifier<int> {
  @override
  int build() => 50;
  @override
  set state(int value) => super.state = value;
}

final usersLimitProvider =
    NotifierProvider<UsersLimitNotifier, int>(UsersLimitNotifier.new);

class UsersSkipNotifier extends Notifier<int> {
  @override
  int build() => 0;
  @override
  set state(int value) => super.state = value;
}

final usersSkipProvider =
    NotifierProvider<UsersSkipNotifier, int>(UsersSkipNotifier.new);

final usersListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final search = ref.watch(usersSearchQueryProvider);
  final isActive = ref.watch(usersIsActiveFilterProvider);
  final isSuperuser = ref.watch(usersIsSuperuserFilterProvider);
  final roleId = ref.watch(usersRoleIdFilterProvider);
  final limit = ref.watch(usersLimitProvider);
  final skip = ref.watch(usersSkipProvider);

  final queryParams = <String, dynamic>{'skip': skip, 'limit': limit};
  if (search.isNotEmpty) queryParams['search'] = search;
  if (isActive != null) queryParams['is_active'] = isActive;
  if (isSuperuser != null) queryParams['is_superuser'] = isSuperuser;
  if (roleId != null && roleId.isNotEmpty) queryParams['role_id'] = roleId;

  final response = await apiClient.get('/users/', queryParameters: queryParams);
  return response.data as List<dynamic>;
});

final rolesListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/rbac/roles');
  return response.data as List<dynamic>;
});

final permissionsListProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/rbac/permissions');
  return response.data as List<dynamic>;
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _prefsKey = 'theme_mode';

  @override
  ThemeMode build() {
    _loadPersisted();
    return ThemeMode.system;
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == 'light') state = ThemeMode.light;
    if (stored == 'dark') state = ThemeMode.dark;
    if (stored == 'system') state = ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_prefsKey, value);
  }

  void toggleTheme(BuildContext context) {
    final currentBrightness = Theme.of(context).brightness;
    if (state == ThemeMode.system) {
      setThemeMode(
        currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
      );
    } else {
      setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
