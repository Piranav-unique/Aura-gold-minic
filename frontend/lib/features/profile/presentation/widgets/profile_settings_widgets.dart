import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/aura_components.dart';

class ProfileSectionHeader extends StatelessWidget {
  final String title;

  const ProfileSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
          letterSpacing: 0.2,
        ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, thickness: 1, color: theme.dividerColor),
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
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.onSurface),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: muted,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small tappable "Verify" pill shown next to the name when KYC is pending.
class _VerifyChip extends StatelessWidget {
  final VoidCallback onTap;

  const _VerifyChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.ctaBlack,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.gpp_maybe_outlined,
                  size: 13, color: AppTheme.primaryGold),
              SizedBox(width: 4),
              Text(
                'Verify',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileHeaderCard extends StatelessWidget {
  final String displayName;
  final String contactLine;
  final String memberSinceLine;
  final String initials;
  final bool showVerifiedBadge;
  final bool kycVerified;
  final VoidCallback? onVerifyTap;
  final VoidCallback? onAvatarTap;

  const ProfileHeaderCard({
    super.key,
    required this.displayName,
    required this.contactLine,
    required this.memberSinceLine,
    required this.initials,
    this.showVerifiedBadge = false,
    this.kycVerified = false,
    this.onVerifyTap,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color onGold = Color(0xFF20180A);
    return GoldGradientCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppTheme.goldDeep,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (showVerifiedBadge)
                  Positioned(
                    right: -2,
                    bottom: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppTheme.emerald,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: onGold,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (kycVerified)
                      const Icon(
                        Icons.verified,
                        size: 20,
                        color: Color(0xFF1B6E3C),
                      )
                    else if (onVerifyTap != null)
                      _VerifyChip(onTap: onVerifyTap!),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  contactLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: onGold,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  memberSinceLine,
                  style: const TextStyle(
                    color: AppTheme.onGoldMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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
