import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/referral/domain/referral_summary.dart';
import 'package:ags_gold/features/referral/presentation/providers/referral_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

const _defaultTiers = <ReferralTier>[
  ReferralTier(schemeGrams: 1, rewardInr: 150, minPurchaseInr: 100),
  ReferralTier(schemeGrams: 5, rewardInr: 350, minPurchaseInr: 1000),
  ReferralTier(schemeGrams: 10, rewardInr: 550, minPurchaseInr: 2000),
];

class ReferAndEarnScreen extends ConsumerWidget {
  const ReferAndEarnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summaryAsync = ref.watch(referralSummaryProvider);

    return ResponsiveNavigationWrapper(
      title: l10n.referAndEarn,
      child: RefreshIndicator(
        color: AurumConsumerTheme.chipGold,
        onRefresh: () async {
          ref.invalidate(referralSummaryProvider);
          await ref.read(referralSummaryProvider.future);
        },
        child: summaryAsync.when(
          data: (summary) => _ReferBody(summary: summary),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.referralLoadFailed('$error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferBody extends StatelessWidget {
  final ReferralSummary summary;

  const _ReferBody({required this.summary});

  List<ReferralTier> get _tiers =>
      summary.tiers.isEmpty ? _defaultTiers : summary.tiers;

  String _inviteLink(int schemeGrams) {
    final code = summary.referralCode.isEmpty ? 'YOURCODE' : summary.referralCode;
    return 'https://api.aurumgold.co.in/signup?ref=$code&scheme=$schemeGrams';
  }

  Future<void> _copyLink(BuildContext context, ReferralTier tier) async {
    final code = summary.referralCode.isEmpty ? '' : summary.referralCode;
    final link = _inviteLink(tier.schemeGrams);
    final minFormatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(tier.minPurchaseInr);
    final rewardFormatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(tier.rewardInr);
    final text =
        'Join AGS Gold (${tier.schemeGrams} g scheme) with referral code $code: $link. Pay $minFormatted or more to activate $rewardFormatted gold coupon bonus!';
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.referralLinkCopied)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          l10n.referAndEarn,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AurumConsumerTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.referAndEarnSubtitle,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AurumConsumerTheme.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        AurumSurfaceCard(
          color: AurumConsumerTheme.surfaceElevated,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.digitalWalletBalance,
                style: TextStyle(
                  color: AurumConsumerTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currency.format(summary.walletBalanceInr),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryGold,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MetricChip(
                    label: l10n.totalEarned,
                    value: currency.format(summary.totalEarnedInr),
                  ),
                  const SizedBox(width: 10),
                  _MetricChip(
                    label: l10n.successfulReferrals,
                    value: '${summary.totalReferrals}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AurumSurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.yourReferralCode,
                      style: TextStyle(color: AurumConsumerTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summary.referralCode.isEmpty ? '—' : summary.referralCode,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AurumConsumerTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: summary.referralCode.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: summary.referralCode),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.referralCodeCopied)),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryGold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          l10n.shareSchemeEarn,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AurumConsumerTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.stars_rounded, color: AppTheme.primaryGold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rewards are credited as pure 24K digital gold directly into your gold savings wallet when your friend completes their first deposit.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AurumConsumerTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final tier in _tiers) ...[
          AurumSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.referralSchemeTitle(tier.schemeGrams),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AurumConsumerTheme.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${tier.schemeGrams}g Scheme',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E5B34).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF1E5B34).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Coupon Reward',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E5B34),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currency.format(tier.rewardInr),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E5B34),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Min. Deposit Needed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AurumConsumerTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currency.format(tier.minPurchaseInr),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AurumConsumerTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Coupon applies when your referee makes a deposit of ${currency.format(tier.minPurchaseInr)} or more.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AurumConsumerTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _copyLink(context, tier),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(l10n.copyInviteLink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (summary.recentRewards.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.recentReferralRewards,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AurumConsumerTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (final reward in summary.recentRewards)
            AurumSurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, color: AppTheme.primaryGold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reward.refereeName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AurumConsumerTheme.textPrimary,
                          ),
                        ),
                        Text(
                          l10n.referralRewardDetail(
                            reward.schemeGrams.toStringAsFixed(0),
                            currency.format(reward.rewardInr),
                          ),
                          style: TextStyle(
                            color: AurumConsumerTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AurumConsumerTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AurumConsumerTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: AurumConsumerTheme.textMuted)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AurumConsumerTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
