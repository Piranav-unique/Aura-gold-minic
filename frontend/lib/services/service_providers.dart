import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ags_gold/config/env_config.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/domain/app_audience_resolver.dart';
import 'package:ags_gold/features/auth/domain/device_auth_storage.dart';
import 'package:ags_gold/features/auth/presentation/providers/app_audience_provider.dart';
import 'package:ags_gold/services/interfaces/secure_storage.dart';
import 'package:ags_gold/services/secure_storage_service.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/features/audit_logs/domain/audit_log.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthNotifier extends AsyncNotifier<AuthStatus> {
  late final ISecureStorage _storage;

  Future<void> _syncAudienceAfterAuth({String? mobileHint}) async {
    final env = ref.read(envConfigProvider);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/profile/');
      final profile = UserProfile.fromJson(
        response.data as Map<String, dynamic>,
      );
      final audience = resolveAppAudience(
        profile: profile,
        adminMobile: env.adminNumber,
        mobileHint: mobileHint ?? profile.mobileNumber,
      );
      await ref.read(appAudienceProvider.notifier).setAudience(audience);
    } catch (_) {
      if (mobileHint == null) return;
      final audience =
          normalizeIndianMobile(mobileHint) ==
              normalizeIndianMobile(env.adminNumber)
          ? AppAudience.staffAdmin
          : AppAudience.endUser;
      await ref.read(appAudienceProvider.notifier).setAudience(audience);
    }
  }

  @override
  FutureOr<AuthStatus> build() async {
    _storage = ref.watch(secureStorageProvider);
    final hasToken = await _storage.hasAccessToken();
    if (!hasToken) {
      await ref.read(appAudienceProvider.notifier).clearAudience();
      return AuthStatus.unauthenticated;
    }

    // Token may still exist on the device after a DB reset or logout elsewhere.
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.get('/auth/me');
      await _syncAudienceAfterAuth();
      return AuthStatus.authenticated;
    } catch (_) {
      await _storage.clearTokens();
      await ref.read(appAudienceProvider.notifier).clearAudience();
      return AuthStatus.unauthenticated;
    }
  }

  Future<void> login({
    String? email,
    String? mobileNumber,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final apiClient = ref.read(apiClientProvider);
      final data = <String, dynamic>{'password': password};
      if (mobileNumber != null && mobileNumber.isNotEmpty) {
        data['mobile_number'] = mobileNumber;
      } else if (email != null) {
        data['email'] = email;
      }
      final response = await apiClient.post('/auth/login', data: data);

      final responseData = response.data as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: responseData['access_token'] as String,
        refreshToken: responseData['refresh_token'] as String,
      );
      await _syncAudienceAfterAuth(mobileHint: mobileNumber);
      state = const AsyncValue.data(AuthStatus.authenticated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> sendSignupOtp(String mobileNumber) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.post(
      '/auth/signup/otp/send',
      data: {'mobile_number': mobileNumber},
    );
  }

  Future<void> sendLoginOtp(String mobileNumber) async {
    final deviceId =
        await ref.read(deviceAuthStorageProvider).getOrCreateDeviceId();
    final apiClient = ref.read(apiClientProvider);
    await apiClient.post(
      '/auth/login/otp/send',
      data: {
        'mobile_number': mobileNumber,
        'device_id': deviceId,
      },
    );
  }

  Future<void> loginWithTrustedMobile(String mobileNumber) async {
    state = const AsyncValue.loading();
    try {
      final deviceAuth = ref.read(deviceAuthStorageProvider);
      final deviceId = await deviceAuth.getOrCreateDeviceId();
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/auth/login/mobile/trusted',
        data: {
          'mobile_number': mobileNumber,
          'device_id': deviceId,
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: responseData['access_token'] as String,
        refreshToken: responseData['refresh_token'] as String,
      );
      await deviceAuth.clearPendingTrustedFirstLogin();
      await _syncAudienceAfterAuth(mobileHint: mobileNumber);
      state = const AsyncValue.data(AuthStatus.authenticated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> loginWithMobile(String mobileNumber, String otp) async {
    state = const AsyncValue.loading();
    try {
      final deviceAuth = ref.read(deviceAuthStorageProvider);
      final deviceId = await deviceAuth.getOrCreateDeviceId();
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/auth/login/mobile',
        data: {
          'mobile_number': mobileNumber,
          'otp': otp,
          'device_id': deviceId,
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: responseData['access_token'] as String,
        refreshToken: responseData['refresh_token'] as String,
      );
      await _syncAudienceAfterAuth(mobileHint: mobileNumber);
      state = const AsyncValue.data(AuthStatus.authenticated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> verifySignupOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.post(
      '/auth/signup/otp/verify',
      data: {
        'mobile_number': mobileNumber,
        'otp': otp,
      },
    );
  }

  Future<void> register({
    required String name,
    required String mobileNumber,
    required String otp,
    required String email,
    required String password,
    String? referralCode,
    int? referralSchemeGrams,
  }) async {
    final deviceAuth = ref.read(deviceAuthStorageProvider);
    final deviceId = await deviceAuth.getOrCreateDeviceId();
    final apiClient = ref.read(apiClientProvider);
    await apiClient.post(
      '/auth/register',
      data: {
        'name': name,
        'mobile_number': mobileNumber,
        'otp': otp,
        'email': email,
        'password': password,
        'device_id': deviceId,
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode,
        'referral_scheme_grams': ?referralSchemeGrams,
      },
    );
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
      await ref.read(appAudienceProvider.notifier).clearAudience();
      state = const AsyncValue.data(AuthStatus.unauthenticated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clearSession() async {
    await _storage.clearTokens();
    await ref.read(appAudienceProvider.notifier).clearAudience();
    state = const AsyncValue.data(AuthStatus.unauthenticated);
  }
}

final envConfigProvider = Provider<EnvConfig>((ref) => EnvConfig.active);

final secureStorageProvider = Provider<ISecureStorage>((ref) {
  return SecureStorageService();
});

final deviceAuthStorageProvider = Provider<IDeviceAuthStorage>((ref) {
  return DeviceAuthStorage();
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

final auditLogsProvider = FutureProvider.autoDispose<List<AuditLog>>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get(
      '/audit-logs/',
      queryParameters: {'limit': 10},
    );
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

final profileActivityProvider = FutureProvider.autoDispose<List<AuditLog>>((
  ref,
) async {
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

final usersLimitProvider = NotifierProvider<UsersLimitNotifier, int>(
  UsersLimitNotifier.new,
);

class UsersSkipNotifier extends Notifier<int> {
  @override
  int build() => 0;
  @override
  set state(int value) => super.state = value;
}

final usersSkipProvider = NotifierProvider<UsersSkipNotifier, int>(
  UsersSkipNotifier.new,
);

final usersListProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
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

final rolesListProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/rbac/roles');
  return response.data as List<dynamic>;
});

final permissionsListProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/rbac/permissions');
  return response.data as List<dynamic>;
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _prefsKey = 'theme_mode';

  @override
  ThemeMode build() {
    _loadPersisted();
    // Default to the light cream + gold experience; dark remains available
    // as a user toggle and is restored from persistence when set.
    return ThemeMode.light;
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

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
