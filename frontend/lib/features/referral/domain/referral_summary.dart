class ReferralTier {
  final int schemeGrams;
  final double rewardInr;
  final double minPurchaseInr;
  final String referralCode;

  const ReferralTier({
    required this.schemeGrams,
    required this.rewardInr,
    this.minPurchaseInr = 100,
    this.referralCode = '',
  });

  /// Returns the distinct referral code for this scheme plan (e.g. `ABCD1234-1G`).
  String codeForUser(String baseCode) {
    if (referralCode.trim().isNotEmpty) {
      return referralCode.trim().toUpperCase();
    }
    final cleanBase = baseCode.trim().toUpperCase();
    if (cleanBase.isEmpty) return '';
    return '$cleanBase-${schemeGrams}G';
  }

  factory ReferralTier.fromJson(Map<String, dynamic> json) {
    final grams = _parseInt(json['scheme_grams']);
    final defaultMin = grams == 10 ? 2000.0 : (grams == 5 ? 1000.0 : 100.0);
    return ReferralTier(
      schemeGrams: grams,
      rewardInr: _parse(json['reward_inr']),
      minPurchaseInr: json['min_purchase_inr'] != null
          ? _parse(json['min_purchase_inr'])
          : defaultMin,
      referralCode: (json['referral_code'] as String? ?? '').trim(),
    );
  }
}

class ParsedReferralCode {
  final String baseCode;
  final int? schemeGrams;
  final String fullTierCode;

  const ParsedReferralCode({
    required this.baseCode,
    required this.schemeGrams,
    required this.fullTierCode,
  });

  bool get hasValidTier =>
      schemeGrams == 1 || schemeGrams == 5 || schemeGrams == 10;

  static ParsedReferralCode? parse(String raw) {
    final cleaned = raw.trim().toUpperCase();
    if (cleaned.isEmpty) return null;

    for (final tier in const [10, 5, 1]) {
      final hyphenSuffix = '-${tier}G';
      final plainSuffix = '${tier}G';
      if (cleaned.endsWith(hyphenSuffix) &&
          cleaned.length > hyphenSuffix.length) {
        final base = cleaned
            .substring(0, cleaned.length - hyphenSuffix.length)
            .replaceAll(RegExp(r'-+$'), '')
            .trim();
        if (base.isNotEmpty) {
          return ParsedReferralCode(
            baseCode: base,
            schemeGrams: tier,
            fullTierCode: '$base-${tier}G',
          );
        }
      }
      if (cleaned.endsWith(plainSuffix) &&
          cleaned.length >= plainSuffix.length + 6) {
        final base = cleaned
            .substring(0, cleaned.length - plainSuffix.length)
            .replaceAll(RegExp(r'-+$'), '')
            .trim();
        if (base.isNotEmpty) {
          return ParsedReferralCode(
            baseCode: base,
            schemeGrams: tier,
            fullTierCode: '$base-${tier}G',
          );
        }
      }
    }

    return ParsedReferralCode(
      baseCode: cleaned,
      schemeGrams: null,
      fullTierCode: cleaned,
    );
  }
}

class ReferralRewardEntry {
  final String refereeName;
  final String? refereeMobile;
  final double schemeGrams;
  final double rewardInr;
  final DateTime createdAt;

  const ReferralRewardEntry({
    required this.refereeName,
    this.refereeMobile,
    required this.schemeGrams,
    required this.rewardInr,
    required this.createdAt,
  });

  factory ReferralRewardEntry.fromJson(Map<String, dynamic> json) {
    return ReferralRewardEntry(
      refereeName: json['referee_name'] as String? ?? 'Friend',
      refereeMobile: json['referee_mobile'] as String?,
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
  final String? referredByName;
  final List<ReferralTier> tiers;
  final List<ReferralRewardEntry> recentRewards;

  const ReferralSummary({
    required this.referralCode,
    this.walletBalanceInr = 0,
    this.totalReferrals = 0,
    this.totalEarnedInr = 0,
    this.referredByName,
    this.tiers = const [],
    this.recentRewards = const [],
  });

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    return ReferralSummary(
      referralCode: json['referral_code'] as String? ?? '',
      walletBalanceInr: _parse(json['wallet_balance_inr']),
      totalReferrals: _parseInt(json['total_referrals']),
      totalEarnedInr: _parse(json['total_earned_inr']),
      referredByName: json['referred_by_name'] as String?,
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
