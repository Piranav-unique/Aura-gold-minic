import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';

/// Higher scheme tiers available after completing the current plan.
List<int> goldSchemeUpgradeOptions(GoldScheme scheme) {
  if (!scheme.status.isCompleted) return const [];
  final completed = scheme.targetGrams?.round() ?? 0;
  if (completed == 1) return const [5, 10];
  if (completed == 5) return const [10];
  return const [];
}

bool goldSchemeHasUpgradeOptions(GoldScheme scheme) =>
    goldSchemeUpgradeOptions(scheme).isNotEmpty;

/// Higher tiers a user can upgrade to from their current plan, regardless of
/// whether the plan is still active (in progress) or already completed.
List<int> goldSchemeHigherTiers(GoldScheme scheme) {
  if (scheme.status.isNotSelected) return const [];
  final current = scheme.targetGrams?.round() ?? 0;
  if (current <= 1) return const [5, 10];
  if (current <= 5) return const [10];
  return const [];
}
