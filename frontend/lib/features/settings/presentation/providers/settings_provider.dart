import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/settings/domain/user_settings.dart';

final userSettingsProvider =
    FutureProvider.autoDispose<UserSettings>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/profile/settings');
  return UserSettings.fromJson(response.data as Map<String, dynamic>);
});

final updateUserSettingsProvider =
    Provider<Future<UserSettings> Function(UserSettings)>((ref) {
  return (UserSettings settings) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.put(
      '/profile/settings',
      data: settings.toJson(),
    );
    ref.invalidate(userSettingsProvider);
    return UserSettings.fromJson(response.data as Map<String, dynamic>);
  };
});
