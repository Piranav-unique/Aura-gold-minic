import 'package:flutter/material.dart';
import 'package:ags_gold/core/widgets/aura_components.dart';

/// Social-proof trust card shown on the consumer home screen.
class SocialProofCard extends StatelessWidget {
  const SocialProofCard({super.key});

  @override
  Widget build(BuildContext context) {
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
                    text: 'Thousands of investors ',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const TextSpan(
                    text: 'started their wealth journey this month',
                  ),
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
    return const Row(
      children: [
        Expanded(
          child: FeatureBadgeCard(
            icon: Icons.verified_user_outlined,
            title: '100% INSURED',
            subtitle: 'Vault-backed gold & silver',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: FeatureBadgeCard(
            icon: Icons.workspace_premium_outlined,
            title: '24K PURITY',
            subtitle: 'Certified bullion',
          ),
        ),
      ],
    );
  }
}

/// "Start SIP in 10 seconds" dark call-to-action banner.
class StartSipBanner extends StatelessWidget {
  final VoidCallback onTap;
  const StartSipBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DarkCtaBanner(
      label: 'Start SIP in 10 seconds',
      trailingIcon: Icons.arrow_forward_rounded,
      onTap: onTap,
    );
  }
}
