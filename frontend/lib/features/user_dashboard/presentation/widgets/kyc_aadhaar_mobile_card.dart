import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

/// Shows only the Aadhaar-linked mobile after stage-1 verification.
class KycAadhaarMobileCard extends StatelessWidget {
  final String mobileMasked;

  const KycAadhaarMobileCard({
    super.key,
    required this.mobileMasked,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AurumSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: AurumConsumerTheme.liveGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.aadhaarVerified,
                  style: TextStyle(
                    color: AurumConsumerTheme.liveGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.aadhaarMobileVerifiedSubtitle,
            style: TextStyle(
              color: AurumConsumerTheme.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.mobileNumber,
            style: TextStyle(
              color: AurumConsumerTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mobileMasked,
            style: TextStyle(
              color: AurumConsumerTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
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
        ],
      ),
    );
  }
}
