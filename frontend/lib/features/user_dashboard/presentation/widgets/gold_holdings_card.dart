import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/features/user_dashboard/domain/market_linked_holdings.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class GoldHoldingsCard extends ConsumerWidget {
  final double goldGrams;
  final double goldInvestedInr;
  final KycStatus kycStatus;
  final GoldScheme? goldScheme;

  const GoldHoldingsCard({
    super.key,
    required this.goldGrams,
    required this.goldInvestedInr,
    required this.kycStatus,
    this.goldScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final investedText = l10n.goldInvestedAmount(currency.format(goldInvestedInr));
    final scheme = goldScheme;
    final pricesAsync = ref.watch(metalPricesProvider);
    final liveRate = pricesAsync.asData?.value.gold.displayPrice ?? 0;
    final hasLiveRate = liveRate > 0 && goldGrams > 0;
    final displayGrams = hasLiveRate
        ? MarketLinkedHoldings.marketLinkedGrams(
            storedGrams: goldGrams,
            investedInr: goldInvestedInr,
            liveRatePerGram: liveRate,
          )
        : goldGrams;
    final gramsText = '${displayGrams.toStringAsFixed(4)} g';
    final currentValue = hasLiveRate
        ? MarketLinkedHoldings.currentValueInr(
            storedGrams: goldGrams,
            liveRatePerGram: liveRate,
          )
        : 0.0;
    final gainInr = hasLiveRate ? currentValue - goldInvestedInr : 0.0;
    final gainPct =
        goldInvestedInr > 0 ? (gainInr / goldInvestedInr) * 100 : 0.0;

    String footerText;
    if (!kycStatus.isComplete) {
      footerText = l10n.completeKycToStartTrading;
    } else if (scheme != null && scheme.status.isActive) {
      footerText = l10n.goldHoldingsSchemeActiveFooter;
    } else if (scheme != null && scheme.status.isCompleted) {
      footerText = l10n.goldHoldingsFooterVerified;
    } else {
      footerText = l10n.goldHoldingsChooseSchemeFooter;
    }

    return AurumSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.monetization_on_outlined,
                  color: AppTheme.primaryGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.goldHoldings,
                  style: const TextStyle(
                    color: AurumConsumerTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasLiveRate)
                Text(
                  l10n.goldLiveAtMarketRate,
                  style: TextStyle(
                    color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            gramsText,
            style: const TextStyle(
              color: AppTheme.primaryGold,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (hasLiveRate) ...[
            const SizedBox(height: 4),
            Text(
              l10n.goldCurrentValue(currency.format(currentValue)),
              style: const TextStyle(
                color: AurumConsumerTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (goldInvestedInr > 0) ...[
            const SizedBox(height: 6),
            Text(
              investedText,
              style: const TextStyle(
                color: AurumConsumerTheme.textMuted,
                fontSize: 14,
              ),
            ),
            if (hasLiveRate) ...[
              const SizedBox(height: 4),
              Text(
                '${gainInr >= 0 ? '+' : ''}${currency.format(gainInr)} (${gainPct >= 0 ? '+' : ''}${gainPct.toStringAsFixed(2)}%)',
                style: TextStyle(
                  color: gainInr >= 0
                      ? AurumConsumerTheme.liveGreen
                      : const Color(0xFFE57373),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
          if (footerText.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AurumConsumerTheme.border),
            const SizedBox(height: 12),
            Text(
              footerText,
              style: const TextStyle(
                color: AurumConsumerTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
