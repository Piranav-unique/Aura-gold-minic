import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class AurumSecurityTrustCard extends StatelessWidget {
  const AurumSecurityTrustCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AurumConsumerTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurumConsumerTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AurumConsumerTheme.borderOf(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Shield Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: AppTheme.primaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.whyGoldSafe,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1A14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. BIS Hallmarked 24K Pure Gold
          _TrustItem(
            icon: Icons.verified_rounded,
            title: context.l10n.safeFeature1Title,
            description: context.l10n.safeFeature1Desc,
          ),
          const SizedBox(height: 12),

          // 2. 100% Real Physical Gold in Safe Lockers
          _TrustItem(
            icon: Icons.lock_outline_rounded,
            title: context.l10n.safeFeature2Title,
            description: context.l10n.safeFeature2Desc,
          ),
          const SizedBox(height: 12),

          // 3. Simple & Safe Payments
          _TrustItem(
            icon: Icons.shield_outlined,
            title: context.l10n.safeFeature3Title,
            description: context.l10n.safeFeature3Desc,
          ),
          const SizedBox(height: 12),

          // 4. Easy Cashout or Shop Collection
          _TrustItem(
            icon: Icons.storefront_outlined,
            title: context.l10n.safeFeature4Title,
            description: context.l10n.safeFeature4Desc,
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TrustItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AurumConsumerTheme.isDark(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryGold, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E1A14),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AurumConsumerTheme.muted(context),
                  height: 1.38,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
