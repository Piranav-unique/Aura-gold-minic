import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class KycTradeCtaCard extends StatelessWidget {
  final KycStatus status;

  const KycTradeCtaCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status.isComplete) return const SizedBox.shrink();

    final l10n = context.l10n;

    return AurumSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: AppTheme.primaryGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.completeKycToTrade,
                      style: TextStyle(
                        color: AurumConsumerTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.verifyPanBeforeTrading,
                      style: TextStyle(
                        color: AurumConsumerTheme.textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/kyc'),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(l10n.completeKyc),
            ),
          ),
        ],
      ),
    );
  }
}
