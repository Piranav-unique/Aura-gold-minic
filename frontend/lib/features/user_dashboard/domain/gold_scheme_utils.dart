import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';

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

bool goldSchemeIsMaxTier(GoldScheme scheme) {
  if (!scheme.status.isCompleted) return false;
  return (scheme.targetGrams?.round() ?? 0) >= 10;
}

/// Higher tiers a user can upgrade to after completing the current plan.
List<int> goldSchemeHigherTiers(GoldScheme scheme) =>
    goldSchemeUpgradeOptions(scheme);

/// Sell enquiry is allowed once KYC is done, the user holds gold, and a plan
/// is active or completed. Works even if the API omits [GoldScheme.canSellInquiry].
bool canSubmitGoldSellInquiry({
  required KycStatus kycStatus,
  required double goldGrams,
  GoldScheme? scheme,
}) {
  if (!kycStatus.isComplete || goldGrams <= 0) return false;
  if (scheme == null || scheme.status.isNotSelected) return false;
  if (scheme.canSellInquiry) return true;
  return scheme.status.isActive || scheme.status.isCompleted;
}