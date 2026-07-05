import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class KycVerificationBanner extends StatelessWidget {
  final KycStatus status;
  final bool showWhenComplete;

  const KycVerificationBanner({
    super.key,
    required this.status,
    this.showWhenComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status.isComplete && !showWhenComplete) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (status.isComplete) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.emerald.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.verified_user,
                color: AppTheme.emerald,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.kycVerifiedTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.kycVerifiedSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final content = _contentFor(l10n, status);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGold.withValues(alpha: 0.18),
            AppTheme.deepNavy.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(content.icon, color: AppTheme.primaryGold, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFCBD5E1),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _KycStepRow(label: l10n.kycStepAadhaar, done: status.aadhaarComplete),
          const SizedBox(height: 8),
          _KycStepRow(
            label: l10n.kycStepPan,
            done: status == KycStatus.verified,
          ),
          const SizedBox(height: 8),
          _KycStepRow(
            label: l10n.kycStepTrading,
            done: status == KycStatus.verified,
          ),
          if (status.needsAction) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.push('/kyc'),
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(content.actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  _KycBannerContent _contentFor(AppLocalizations l10n, KycStatus status) {
    switch (status) {
      case KycStatus.aadhaarVerified:
        return _KycBannerContent(
          icon: Icons.link_outlined,
          title: l10n.kycBannerCompletePanTitle,
          subtitle: l10n.kycBannerCompletePanSubtitle,
          actionLabel: l10n.kycBannerContinuePan,
        );
      case KycStatus.pending:
        return _KycBannerContent(
          icon: Icons.hourglass_top_outlined,
          title: l10n.kycBannerPendingTitle,
          subtitle: l10n.kycBannerPendingSubtitle,
          actionLabel: l10n.kycBannerViewStatus,
        );
      case KycStatus.rejected:
        return _KycBannerContent(
          icon: Icons.error_outline,
          title: l10n.kycBannerRejectedTitle,
          subtitle: l10n.kycBannerRejectedSubtitle,
          actionLabel: l10n.kycBannerRestart,
        );
      case KycStatus.notStarted:
      case KycStatus.verified:
        return _KycBannerContent(
          icon: Icons.shield_outlined,
          title: l10n.kycBannerStartTitle,
          subtitle: l10n.kycBannerStartSubtitle,
          actionLabel: l10n.kycBannerStartAction,
        );
    }
  }
}

class _KycBannerContent {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;

  const _KycBannerContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });
}

class _KycStepRow extends StatelessWidget {
  final String label;
  final bool done;

  const _KycStepRow({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: done ? AppTheme.emerald : Colors.white54,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: done ? Colors.white : Colors.white70,
            fontWeight: done ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
