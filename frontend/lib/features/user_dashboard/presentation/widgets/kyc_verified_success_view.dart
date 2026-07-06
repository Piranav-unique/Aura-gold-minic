import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class KycVerifiedSuccessView extends StatelessWidget {
  final KycGovernmentProfile profile;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;

  const KycVerifiedSuccessView({
    super.key,
    required this.profile,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.onSecondaryAction,
    this.secondaryActionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.verified_user_rounded,
            color: AurumConsumerTheme.liveGreen,
            size: 52,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.kycVerifiedHeading,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AurumConsumerTheme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.verifiedViaSandbox,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AurumConsumerTheme.liveGreen,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.panVerificationLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AurumConsumerTheme.textMuted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 28),
        if (profile.fullName != null)
          _CenteredDetail(
            label: l10n.registeredName,
            value: profile.fullName!,
          ),
        if (profile.panNumberMasked != null) ...[
          const SizedBox(height: 16),
          _CenteredDetail(
            label: l10n.panNumber,
            value: profile.panNumberMasked!,
          ),
        ],
        if (profile.aadhaarLast4 != null) ...[
          const SizedBox(height: 16),
          _CenteredDetail(
            label: l10n.aadhaarNumber,
            value: 'XXXX XXXX ${profile.aadhaarLast4}',
          ),
        ],
        if (profile.dateOfBirth != null) ...[
          const SizedBox(height: 16),
          _CenteredDetail(
            label: l10n.dateOfBirth,
            value: profile.dateOfBirth!,
          ),
        ],
        if (profile.fullAddress != null) ...[
          const SizedBox(height: 16),
          _CenteredDetail(
            label: l10n.address,
            value: profile.fullAddress!,
          ),
        ],
        if (profile.state != null) ...[
          const SizedBox(height: 16),
          _CenteredDetail(label: l10n.state, value: profile.state!),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_android_outlined,
              size: 16,
              color: AurumConsumerTheme.liveGreen,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.mobileLinkedAadhaar,
              style: TextStyle(
                color: AurumConsumerTheme.liveGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPrimaryAction,
            child: Text(primaryActionLabel),
          ),
        ),
        if (onSecondaryAction != null && secondaryActionLabel != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}

class _CenteredDetail extends StatelessWidget {
  final String label;
  final String value;

  const _CenteredDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AurumConsumerTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AurumConsumerTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class KycVerifiedBanner extends StatelessWidget {
  const KycVerifiedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: AurumConsumerTheme.liveGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.kycVerifiedTitle,
                  style: TextStyle(
                    color: AurumConsumerTheme.liveGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.kycVerifiedDashboardSubtitle,
                  style: TextStyle(
                    color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountSection extends StatelessWidget {
  final bool kycVerified;
  final bool showProfileTile;

  const AccountSection({
    super.key,
    required this.kycVerified,
    this.showProfileTile = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.accountSection,
          style: TextStyle(
            color: AurumConsumerTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (showProfileTile) ...[
          _AccountTile(
            icon: Icons.person_outline,
            title: l10n.myProfile,
            subtitle: l10n.manageYourProfile,
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(height: 10),
        ],
        _AccountTile(
          icon: Icons.badge_outlined,
          title: kycVerified ? l10n.kycVerifiedHeading : l10n.kycVerification,
          subtitle: kycVerified
              ? l10n.identityVerified
              : l10n.completeKycToStartTrading,
          verified: kycVerified,
          onTap: () => context.push('/kyc'),
        ),
        const SizedBox(height: 10),
        _AccountTile(
          icon: Icons.account_balance_outlined,
          title: l10n.bankAccounts,
          subtitle: l10n.manageBankAccounts,
          onTap: () => context.push('/bank-accounts'),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool verified;

  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = verified ? AppTheme.emerald : AppTheme.primaryGold;

    return Material(
      color: AurumConsumerTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: verified
                  ? AppTheme.emerald.withValues(alpha: 0.35)
                  : AurumConsumerTheme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  verified ? Icons.verified_user_rounded : icon,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AurumConsumerTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: verified
                            ? AppTheme.emerald
                            : AurumConsumerTheme.textMuted,
                        fontSize: 12,
                        fontWeight:
                            verified ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (verified)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.emerald,
                    size: 22,
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: AurumConsumerTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
