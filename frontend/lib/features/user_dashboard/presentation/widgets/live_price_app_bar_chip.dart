import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/logging/app_event_log.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/live_price_sheet.dart';

/// Compact 24K price chip beside the notification bell — opens live price sheet.
class LivePriceAppBarChip extends ConsumerWidget {
  const LivePriceAppBarChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(metalPricesProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: pricesAsync.when(
        data: (data) {
          final price = currency.format(data.gold.displayPrice);
          return _PriceChip(
            label: '24K',
            price: '$price/gm',
            onTap: () {
              AppEventLog.action(
                'gold_price_chip_tap',
                data: {'price': data.gold.displayPrice},
              );
              showLivePriceSheet(context);
            },
          );
        },
        loading: () => const _PriceChip(
          label: '24K',
          price: '…',
          onTap: null,
        ),
        error: (_, _) => _PriceChip(
          label: '24K',
          price: 'Live',
          onTap: () {
            AppEventLog.action('gold_price_chip_tap', data: {'price': 'error'});
            showLivePriceSheet(context);
          },
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final String price;
  final VoidCallback? onTap;

  const _PriceChip({
    required this.label,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF9A7B2F),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryGold.withValues(alpha: 0.65),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                price,
                style: const TextStyle(
                  color: Color(0xFFFFF8E7),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
