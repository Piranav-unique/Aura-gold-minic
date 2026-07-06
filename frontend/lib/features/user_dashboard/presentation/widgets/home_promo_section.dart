import 'package:flutter/material.dart';
import 'package:ags_gold/core/widgets/aura_components.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

/// Social-proof trust card shown on the consumer home screen.
class SocialProofCard extends StatelessWidget {
  const SocialProofCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return AuraCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: false,
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 36,
            child: Stack(
              children: [
                _avatarDot(const Color(0xFFE7C65A), Icons.person, 0),
                _avatarDot(const Color(0xFF6B5210), Icons.people, 22),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: muted, fontSize: 13.5, height: 1.35),
                children: [
                  TextSpan(
                    text: l10n.socialProofHighlight,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: l10n.socialProofRest),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarDot(Color color, IconData icon, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Two trust/feature badges (insured + purity) shown side by side.
class FeatureBadgesRow extends StatelessWidget {
  const FeatureBadgesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: FeatureBadgeCard(
            icon: Icons.verified_user_outlined,
            title: l10n.promoInsuredTitle,
            subtitle: l10n.promoInsuredSubtitle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FeatureBadgeCard(
            icon: Icons.diamond_outlined,
            title: l10n.promoPurityTitle,
            subtitle: l10n.promoPuritySubtitle,
          ),
        ),
      ],
    );
  }
}
