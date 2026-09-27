import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';

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
                  'Why Your Gold Is 100% Safe',
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
          const _TrustItem(
            icon: Icons.verified_rounded,
            title: 'BIS Hallmarked 24K Pure Gold',
            description:
                '100% pure 24-Karat (999 fineness) gold, certified with government BIS hallmarking standards for genuine quality you can trust.',
          ),
          const SizedBox(height: 12),

          // 2. 100% Real Physical Gold in Safe Lockers
          const _TrustItem(
            icon: Icons.lock_outline_rounded,
            title: 'Stored in Bank-Grade Insured Lockers',
            description:
                'Every rupee you save buys real physical gold, safely kept in fully insured bank vaults on your behalf.',
          ),
          const SizedBox(height: 12),

          // 3. Simple & Safe Payments
          const _TrustItem(
            icon: Icons.shield_outlined,
            title: 'Safe Payments via UPI & Cards',
            description:
                'Pay securely with Google Pay, PhonePe, Paytm, Net Banking, or Debit Cards via India’s trusted Razorpay gateway.',
          ),
          const SizedBox(height: 12),

          // 4. Easy Cashout or Shop Collection
          const _TrustItem(
            icon: Icons.storefront_outlined,
            title: 'Sell Anytime or Visit Our Shop',
            description:
                'Withdraw money directly to your bank account at today’s live gold rate, or visit our shop to collect your physical gold.',
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
