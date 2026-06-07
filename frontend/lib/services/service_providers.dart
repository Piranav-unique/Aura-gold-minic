import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/config/env_config.dart';
import 'package:ags_gold/services/interfaces/secure_storage.dart';
import 'package:ags_gold/services/secure_storage_service.dart';
import 'package:ags_gold/services/api_client.dart';

// Authentication Status Options
enum AuthStatus { initial, authenticated, unauthenticated }

class AuthNotifier extends AsyncNotifier<AuthStatus> {
  late final ISecureStorage _storage;

  @override
  FutureOr<AuthStatus> build() async {
    _storage = ref.watch(secureStorageProvider);
    // Artificial delay to make the splash screen visible
    await Future.delayed(const Duration(seconds: 2));
    final hasToken = await _storage.hasAccessToken();
    return hasToken ? AuthStatus.authenticated : AuthStatus.unauthenticated;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;

      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
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
            data: {
              'refresh_token': refreshToken,
            },
          );
        } catch (_) {
          // If server log out fails, we still clear tokens locally
        }
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

// Provides environment config parameters
final envConfigProvider = Provider<EnvConfig>((ref) {
  return EnvConfig.active;
});

// Provides Secure Storage service
final secureStorageProvider = Provider<ISecureStorage>((ref) {
  return SecureStorageService();
});

// Provides ApiClient instance injected with SecureStorage interface and onUnauthorized callback
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

// Provides current authentication state using AsyncNotifierProvider
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthStatus>(
  AuthNotifier.new,
);

// Provides recent audit logs from backend
final auditLogsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get('/audit-logs/?limit=10');
    return response.data as List<dynamic>;
  } catch (e) {
    // Return empty list if unauthorized/forbidden, letting UI handle it
    return [];
  }
});

// Provides current user profile details
final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/auth/me');
  return response.data as Map<String, dynamic>;
});

// Users management states & provider
class UsersSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  @override
  set state(String value) => super.state = value;
}
final usersSearchQueryProvider = NotifierProvider<UsersSearchQueryNotifier, String>(UsersSearchQueryNotifier.new);

class UsersIsActiveFilterNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;
  @override
  set state(bool? value) => super.state = value;
}
final usersIsActiveFilterProvider = NotifierProvider<UsersIsActiveFilterNotifier, bool?>(UsersIsActiveFilterNotifier.new);

class UsersIsSuperuserFilterNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;
  @override
  set state(bool? value) => super.state = value;
}
final usersIsSuperuserFilterProvider = NotifierProvider<UsersIsSuperuserFilterNotifier, bool?>(UsersIsSuperuserFilterNotifier.new);

class UsersRoleIdFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  @override
  set state(String? value) => super.state = value;
}
final usersRoleIdFilterProvider = NotifierProvider<UsersRoleIdFilterNotifier, String?>(UsersRoleIdFilterNotifier.new);

class UsersLimitNotifier extends Notifier<int> {
  @override
  int build() => 50;
  @override
  set state(int value) => super.state = value;
}
final usersLimitProvider = NotifierProvider<UsersLimitNotifier, int>(UsersLimitNotifier.new);

class UsersSkipNotifier extends Notifier<int> {
  @override
  int build() => 0;
  @override
  set state(int value) => super.state = value;
}
final usersSkipProvider = NotifierProvider<UsersSkipNotifier, int>(UsersSkipNotifier.new);

final usersListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final search = ref.watch(usersSearchQueryProvider);
  final isActive = ref.watch(usersIsActiveFilterProvider);
  final isSuperuser = ref.watch(usersIsSuperuserFilterProvider);
  final roleId = ref.watch(usersRoleIdFilterProvider);
  final limit = ref.watch(usersLimitProvider);
  final skip = ref.watch(usersSkipProvider);

  final queryParams = <String, dynamic>{
    'skip': skip,
    'limit': limit,
  };
  if (search.isNotEmpty) queryParams['search'] = search;
  if (isActive != null) queryParams['is_active'] = isActive;
  if (isSuperuser != null) queryParams['is_superuser'] = isSuperuser;
  if (roleId != null && roleId.isNotEmpty) queryParams['role_id'] = roleId;

  final response = await apiClient.get('/users/', queryParameters: queryParams);
  return response.data as List<dynamic>;
});

// Roles provider
final rolesListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/rbac/roles');
  return response.data as List<dynamic>;
});

// Permissions provider
final permissionsListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/rbac/permissions');
  return response.data as List<dynamic>;
});

// Theme mode state and provider
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void toggleTheme(BuildContext context) {
    final currentBrightness = Theme.of(context).brightness;
    if (state == ThemeMode.system) {
      state = currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    } else {
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    }
  }
}
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

