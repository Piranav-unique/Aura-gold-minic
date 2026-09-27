import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';

class AurumInvestmentSummaryCard extends StatelessWidget {
  final double totalInvestedInr;
  final double currentValueInr;
  final double gainPct;
  final double goldGrams;
  final double liveGoldRate;
  final int? totalTransactionsCount;

  const AurumInvestmentSummaryCard({
    super.key,
    required this.totalInvestedInr,
    required this.currentValueInr,
    required this.gainPct,
    required this.goldGrams,
    required this.liveGoldRate,
    this.totalTransactionsCount,
  });

  String _formatGrams(double grams) {
    if (grams <= 0) return '0.0000 g';
    final s = grams.toStringAsFixed(4);
    final trimmed = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return '$trimmed g';
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final currency0 = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final avgBuyPrice = goldGrams > 0 ? (totalInvestedInr / goldGrams) : liveGoldRate;
    final isDark = AurumConsumerTheme.isDark(context);
    final isGain = gainPct >= 0;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pie_chart_outline_rounded,
                  color: AppTheme.primaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Investment Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E1A14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _SummaryRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Total Amount Invested',
            value: currencyFormatter.format(totalInvestedInr),
          ),
          _SummaryRow(
            icon: Icons.trending_up_rounded,
            label: 'Current Value',
            valueWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currencyFormatter.format(currentValueInr),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1A14),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${isGain ? '+' : ''}${gainPct.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isGain ? const Color(0xFF10B981) : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          _SummaryRow(
            icon: Icons.view_in_ar_outlined,
            label: 'Total Gold Quantity',
            value: _formatGrams(goldGrams),
          ),
          _SummaryRow(
            icon: Icons.currency_rupee_rounded,
            label: 'Average Buy Price',
            value: '${currency0.format(avgBuyPrice)}/g',
          ),
          _SummaryRow(
            icon: Icons.show_chart_rounded,
            label: 'Current Market Price',
            value: '${currency0.format(liveGoldRate)}/g',
            isLast: totalTransactionsCount == null,
          ),
          if (totalTransactionsCount != null)
            _SummaryRow(
              icon: Icons.receipt_long_outlined,
              label: 'Total Transactions',
              value: '$totalTransactionsCount',
              isLast: true,
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool isLast;

  const _SummaryRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AurumConsumerTheme.isDark(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: AurumConsumerTheme.muted(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AurumConsumerTheme.muted(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (valueWidget != null)
                valueWidget!
              else
                Text(
                  value ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1A14),
                  ),
                ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: AurumConsumerTheme.borderOf(context).withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
