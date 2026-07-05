import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class KycPanInfoCard extends StatelessWidget {
  const KycPanInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AurumSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.howPanVerificationWorks,
            style: TextStyle(
              color: AurumConsumerTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.panVerificationFlowSubtitle,
            style: TextStyle(
              color: AurumConsumerTheme.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _FlowStep(
                  active: true,
                  icon: Icons.edit_outlined,
                  title: l10n.panFlowYourDetails,
                  subtitle: l10n.panFlowYourDetailsSubtitle,
                ),
              ),
              const _FlowConnector(),
              Expanded(
                child: _FlowStep(
                  icon: Icons.smartphone_outlined,
                  title: l10n.navAurum,
                  subtitle: l10n.panFlowSecureTransfer,
                ),
              ),
              const _FlowConnector(),
              Expanded(
                child: _FlowStep(
                  icon: Icons.shield_outlined,
                  title: l10n.panFlowSecureKycApi,
                  subtitle: l10n.panFlowLicensedProvider,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowConnector extends StatelessWidget {
  const _FlowConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 2,
      margin: const EdgeInsets.only(bottom: 28),
      color: AurumConsumerTheme.border,
    );
  }
}

class _FlowStep extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String title;
  final String subtitle;

  const _FlowStep({
    this.active = false,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final circleColor = active
        ? AppTheme.primaryGold
        : AurumConsumerTheme.surfaceElevated;
    final iconColor =
        active ? const Color(0xFF1A1200) : AurumConsumerTheme.textMuted;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: active
                ? null
                : Border.all(color: AurumConsumerTheme.border),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active
                ? AurumConsumerTheme.textPrimary
                : AurumConsumerTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AurumConsumerTheme.textMuted,
            fontSize: 10,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
