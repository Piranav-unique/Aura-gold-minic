import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/referral/domain/referral_summary.dart';

void main() {
  group('ReferralTier and ReferralSummary Domain Tests', () {
    test('ReferralTier sets default minPurchaseInr for scheme tiers', () {
      final tier1 = ReferralTier.fromJson({'scheme_grams': 1, 'reward_inr': 150});
      expect(tier1.schemeGrams, 1);
      expect(tier1.rewardInr, 150.0);
      expect(tier1.minPurchaseInr, 100.0);

      final tier5 = ReferralTier.fromJson({'scheme_grams': 5, 'reward_inr': 350});
      expect(tier5.schemeGrams, 5);
      expect(tier5.rewardInr, 350.0);
      expect(tier5.minPurchaseInr, 1000.0);

      final tier10 = ReferralTier.fromJson({'scheme_grams': 10, 'reward_inr': 550});
      expect(tier10.schemeGrams, 10);
      expect(tier10.rewardInr, 550.0);
      expect(tier10.minPurchaseInr, 2000.0);
    });

    test('ReferralTier parses explicit min_purchase_inr from API response', () {
      final tier = ReferralTier.fromJson({
        'scheme_grams': 1,
        'reward_inr': 150,
        'min_purchase_inr': 100,
      });
      expect(tier.schemeGrams, 1);
      expect(tier.rewardInr, 150.0);
      expect(tier.minPurchaseInr, 100.0);
    });

    test('ReferralSummary parses tiers list and reward entries', () {
      final json = {
        'referral_code': 'AURAGOLD1',
        'wallet_balance_inr': 350.0,
        'total_referrals': 2,
        'total_earned_inr': 500.0,
        'tiers': [
          {'scheme_grams': 1, 'reward_inr': 150, 'min_purchase_inr': 100},
          {'scheme_grams': 5, 'reward_inr': 350, 'min_purchase_inr': 1000},
          {'scheme_grams': 10, 'reward_inr': 550, 'min_purchase_inr': 2000},
        ],
        'recent_rewards': [
          {
            'referee_name': 'Friend A',
            'scheme_grams': 1,
            'reward_inr': 150,
            'created_at': '2026-09-26T10:00:00Z',
          }
        ]
      };

      final summary = ReferralSummary.fromJson(json);
      expect(summary.referralCode, 'AURAGOLD1');
      expect(summary.walletBalanceInr, 350.0);
      expect(summary.totalReferrals, 2);
      expect(summary.totalEarnedInr, 500.0);
      expect(summary.tiers.length, 3);
      expect(summary.tiers[0].minPurchaseInr, 100.0);
      expect(summary.tiers[1].minPurchaseInr, 1000.0);
      expect(summary.tiers[2].minPurchaseInr, 2000.0);
      expect(summary.recentRewards.length, 1);
      expect(summary.recentRewards.first.refereeName, 'Friend A');
    });
  });
}
