import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

/// Dashboard-only selection before the user taps Buy Gold (not yet saved).
class PendingGoldSchemeGramsNotifier extends Notifier<int?> {
  @override
  int? build() {
    ref.listen(authNotifierProvider, (previous, next) {
      final status = next.value;
      if (status != null && status != AuthStatus.authenticated) {
        state = null;
      }
    });
    return null;
  }

  @override
  set state(int? value) => super.state = value;
}

final pendingGoldSchemeGramsProvider =
    NotifierProvider<PendingGoldSchemeGramsNotifier, int?>(
  PendingGoldSchemeGramsNotifier.new,
);

typedef SelectGoldScheme = Future<GoldScheme> Function(int targetGrams);
typedef UpgradeGoldScheme = Future<GoldScheme> Function(int targetGrams);

final selectGoldSchemeProvider = Provider<SelectGoldScheme>((ref) {
  return (int targetGrams) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post(
      '/gold-scheme/select',
      data: {'target_grams': targetGrams},
    );
    await ref.read(personalDashboardProvider.notifier).refresh();
    return GoldScheme.fromJson(response.data as Map<String, dynamic>);
  };
});

final upgradeGoldSchemeProvider = Provider<UpgradeGoldScheme>((ref) {
  return (int targetGrams) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post(
      '/gold-scheme/upgrade',
      data: {'target_grams': targetGrams},
    );
    await ref.read(personalDashboardProvider.notifier).refresh();
    return GoldScheme.fromJson(response.data as Map<String, dynamic>);
  };
});
