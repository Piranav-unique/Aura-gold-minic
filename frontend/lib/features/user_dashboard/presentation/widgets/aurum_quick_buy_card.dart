import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class AurumQuickBuyCard extends StatefulWidget {
  final double liveGoldRatePerGram;
  final ValueChanged<double> onBuy;
  final VoidCallback onCustomAmount;

  const AurumQuickBuyCard({
    super.key,
    required this.liveGoldRatePerGram,
    required this.onBuy,
    required this.onCustomAmount,
  });

  @override
  State<AurumQuickBuyCard> createState() => _AurumQuickBuyCardState();
}

class _AurumQuickBuyCardState extends State<AurumQuickBuyCard> {
  double _selectedAmount = 100.0;

  final List<double> _presetAmounts = [50.0, 100.0, 250.0, 500.0, 1000.0, 2000.0];

  String _approxGrams(double amount) {
    final rate = widget.liveGoldRatePerGram > 0 ? widget.liveGoldRatePerGram : 15736.0;
    // 3% GST included calculation: net_value = amount / 1.03, grams = net_value / rate
    final netAmount = amount / 1.03;
    final grams = netAmount / rate;
    return '≈ ${grams.toStringAsFixed(4)} g';
  }

  Widget _buildChip(double amount, bool isDark) {
    final isSelected = amount == _selectedAmount;
    final formattedAmount = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: InkWell(
          onTap: () => setState(() => _selectedAmount = amount),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF38290D) : const Color(0xFFFBF4DC))
                  : AurumConsumerTheme.surfaceElevatedOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryGold
                    : AurumConsumerTheme.borderOf(context),
                width: isSelected ? 1.6 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Text(
                  formattedAmount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? AppTheme.primaryGold
                        : (isDark ? Colors.white : const Color(0xFF1E1A14)),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _approxGrams(amount),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AurumConsumerTheme.muted(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Quick Buy + Custom Amount Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.quickBuy,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E1A14),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: widget.onCustomAmount,
                child: Row(
                  children: [
                    Text(
                      context.l10n.customAmount,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGold,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 15,
                      color: AppTheme.primaryGold,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 1: ₹50, ₹100, ₹250
          Row(
            children: [
              _buildChip(_presetAmounts[0], isDark),
              _buildChip(_presetAmounts[1], isDark),
              _buildChip(_presetAmounts[2], isDark),
            ],
          ),
          // Row 2: ₹500, ₹1,000, ₹2,000
          Row(
            children: [
              _buildChip(_presetAmounts[3], isDark),
              _buildChip(_presetAmounts[4], isDark),
              _buildChip(_presetAmounts[5], isDark),
            ],
          ),
          const SizedBox(height: 16),

          // CTA Button
          Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFAA7C11)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGold.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onBuy(_selectedAmount),
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.buyGoldNow,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C1E03),
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Color(0xFF2C1E03),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
