import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';

/// Tamil Nadu live gold/silver rates — dashboard only (no chart).
class TnMarketRatesSection extends ConsumerStatefulWidget {
  const TnMarketRatesSection({super.key});

  @override
  ConsumerState<TnMarketRatesSection> createState() =>
      _TnMarketRatesSectionState();
}

class _TnMarketRatesSectionState extends ConsumerState<TnMarketRatesSection> {
  MetalType _selected = MetalType.gold;

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(metalPricesProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return pricesAsync.when(
      data: (prices) {
        final goldRate = prices.gold.displayPrice;
        final silverRate = prices.silver.displayPrice;

        return AurumSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live rates',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AurumConsumerTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Updated ${DateFormat('HH:mm').format(prices.refreshedAt.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AurumConsumerTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _RateTile(
                      label: '24K Gold',
                      price: currency.format(goldRate),
                      selected: _selected == MetalType.gold,
                      accent: AppTheme.primaryGold,
                      onTap: () => setState(() => _selected = MetalType.gold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RateTile(
                      label: 'Silver',
                      price: currency.format(silverRate),
                      selected: _selected == MetalType.silver,
                      accent: const Color(0xFFC0C0C0),
                      onTap: () => setState(() => _selected = MetalType.silver),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const AurumSurfaceCard(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => AurumSurfaceCard(
        child: TextButton(
          onPressed: () => ref.invalidate(metalPricesProvider),
          child: const Text('Retry loading live rates'),
        ),
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  final String label;
  final String price;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  const _RateTile({
    required this.label,
    required this.price,
    required this.selected,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.14)
          : AurumConsumerTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : AurumConsumerTheme.border,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: selected ? accent : AurumConsumerTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                price,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AurumConsumerTheme.textPrimary,
                ),
              ),
              Text(
                '/gm',
                style: TextStyle(
                  fontSize: 11,
                  color: AurumConsumerTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
