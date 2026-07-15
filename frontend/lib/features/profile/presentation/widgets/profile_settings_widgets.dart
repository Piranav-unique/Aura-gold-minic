import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

/// Profile-only typography — tighter tracking and lighter weights than the
/// consumer dashboard so the screen reads as AGS, not a clone of Aura Gold.
abstract final class ProfileTypography {
  static TextStyle displayName(BuildContext context) {
    return TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.15,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  static TextStyle contactLine(BuildContext context) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.6,
      color: AppTheme.inkMuted,
    );
  }

  static TextStyle sectionLabel(BuildContext context) {
    return const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.35,
      color: AppTheme.goldDeep,
    );
  }

  static TextStyle tileTitle(BuildContext context) {
    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  static TextStyle tileSubtitle(BuildContext context) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: AppTheme.inkMuted,
    );
  }
}

class ProfileSectionHeader extends StatelessWidget {
  final String title;

  const ProfileSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.primaryGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: ProfileTypography.sectionLabel(context),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const ProfileSettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.85)),
        boxShadow: isDark ? null : AppTheme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                endIndent: 16,
                color: theme.dividerColor.withValues(alpha: 0.7),
              ),
          ],
        ],
      ),
    );
  }
}

class ProfileSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ProfileSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.creamElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppTheme.goldDeep,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: ProfileTypography.tileTitle(context),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: muted,
                    size: 22,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileAccountShortcuts extends StatelessWidget {
  final bool kycVerified;

  const ProfileAccountShortcuts({super.key, required this.kycVerified});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        _ProfileShortcutCard(
          icon: kycVerified ? Icons.verified_user_rounded : Icons.badge_outlined,
          title: kycVerified ? l10n.kycVerifiedHeading : l10n.kycVerification,
          subtitle: kycVerified
              ? l10n.identityVerified
              : l10n.completeKycToStartTrading,
          accent: kycVerified ? AppTheme.emerald : AppTheme.goldDeep,
          onTap: () => context.push('/kyc'),
        ),
        const SizedBox(height: 10),
        _ProfileShortcutCard(
          icon: Icons.account_balance_outlined,
          title: l10n.bankAccounts,
          subtitle: l10n.manageBankAccounts,
          accent: AppTheme.goldDeep,
          onTap: () => context.push('/bank-accounts'),
        ),
      ],
    );
  }
}

class _ProfileShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _ProfileShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.dividerColor),
            boxShadow: theme.brightness == Brightness.dark
                ? null
                : AppTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ProfileTypography.tileTitle(context)),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: ProfileTypography.tileSubtitle(context).copyWith(
                          color: accent == AppTheme.emerald
                              ? AppTheme.emerald
                              : AppTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppTheme.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileHeaderCard extends StatelessWidget {
  final String displayName;
  final String contactLine;
  final String initials;
  final bool showVerifiedBadge;
  final bool kycVerified;
  final VoidCallback? onVerifyTap;
  final VoidCallback? onAvatarTap;

  const ProfileHeaderCard({
    super.key,
    required this.displayName,
    required this.contactLine,
    required this.initials,
    this.showVerifiedBadge = false,
    this.kycVerified = false,
    this.onVerifyTap,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
        boxShadow: theme.brightness == Brightness.dark
            ? null
            : AppTheme.softShadow,
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.goldGradient,
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: theme.cardColor,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppTheme.goldDeep,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                if (showVerifiedBadge)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.emerald,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.cardColor, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: ProfileTypography.displayName(context),
                ),
              ),
              if (kycVerified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: AppTheme.emerald,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            contactLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ProfileTypography.contactLine(context),
          ),
          if (!kycVerified && onVerifyTap != null) ...[
            const SizedBox(height: 14),
            _VerifyChip(onTap: onVerifyTap!),
          ],
        ],
      ),
    );
  }
}

class _VerifyChip extends StatelessWidget {
  final VoidCallback onTap;

  const _VerifyChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.ctaBlack,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.gpp_maybe_outlined,
                size: 14,
                color: AppTheme.primaryGold,
              ),
              SizedBox(width: 6),
              Text(
                'Complete KYC',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
