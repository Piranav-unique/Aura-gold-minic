class ReferralTier {
  final int schemeGrams;
  final double rewardInr;
  final double minPurchaseInr;

  const ReferralTier({
    required this.schemeGrams,
    required this.rewardInr,
    this.minPurchaseInr = 100,
  });

  factory ReferralTier.fromJson(Map<String, dynamic> json) {
    final grams = _parseInt(json['scheme_grams']);
    final defaultMin = grams == 10 ? 2000.0 : (grams == 5 ? 1000.0 : 100.0);
    return ReferralTier(
      schemeGrams: grams,
      rewardInr: _parse(json['reward_inr']),
      minPurchaseInr: json['min_purchase_inr'] != null
          ? _parse(json['min_purchase_inr'])
          : defaultMin,
    );
  }
}

class ReferralRewardEntry {
  final String refereeName;
  final double schemeGrams;
  final double rewardInr;
  final DateTime createdAt;

  const ReferralRewardEntry({
    required this.refereeName,
    required this.schemeGrams,
    required this.rewardInr,
    required this.createdAt,
  });

  factory ReferralRewardEntry.fromJson(Map<String, dynamic> json) {
    return ReferralRewardEntry(
      refereeName: json['referee_name'] as String? ?? 'Friend',
      schemeGrams: _parse(json['scheme_grams']),
      rewardInr: _parse(json['reward_inr']),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ReferralSummary {
  final String referralCode;
  final double walletBalanceInr;
  final int totalReferrals;
  final double totalEarnedInr;
  final List<ReferralTier> tiers;
  final List<ReferralRewardEntry> recentRewards;

  const ReferralSummary({
    required this.referralCode,
    this.walletBalanceInr = 0,
    this.totalReferrals = 0,
    this.totalEarnedInr = 0,
    this.tiers = const [],
    this.recentRewards = const [],
  });

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    return ReferralSummary(
      referralCode: json['referral_code'] as String? ?? '',
      walletBalanceInr: _parse(json['wallet_balance_inr']),
      totalReferrals: _parseInt(json['total_referrals']),
      totalEarnedInr: _parse(json['total_earned_inr']),
      tiers: (json['tiers'] as List<dynamic>? ?? [])
          .map((e) => ReferralTier.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentRewards: (json['recent_rewards'] as List<dynamic>? ?? [])
          .map((e) => ReferralRewardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

double _parse(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
