import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class AurumHeroPortfolioCard extends StatefulWidget {
  final double totalValue;
  final double gainPct;
  final double gainInr;
  final double goldGrams;
  final double silverGrams;
  final VoidCallback? onDetailsTap;

  const AurumHeroPortfolioCard({
    super.key,
    required this.totalValue,
    required this.gainPct,
    required this.gainInr,
    required this.goldGrams,
    required this.silverGrams,
    this.onDetailsTap,
  });

  @override
  State<AurumHeroPortfolioCard> createState() => _AurumHeroPortfolioCardState();
}

class _AurumHeroPortfolioCardState extends State<AurumHeroPortfolioCard> {
  bool _obscured = false;

  String _formatGrams(double grams) {
    if (grams <= 0) return '0 g';
    // Format up to 4 decimal places, trimming trailing zeros
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

    final isPositiveGain = widget.gainPct >= 0;
    final gainSign = isPositiveGain ? '+' : '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF38290D),
            Color(0xFF261B07),
            Color(0xFF150F03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8860B).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle Gold Bar Graphic Watermark in Top-Right
          Positioned(
            right: -10,
            top: -10,
            child: Opacity(
              opacity: 0.12,
              child: Icon(
                Icons.view_in_ar_rounded,
                size: 150,
                color: AppTheme.primaryGold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Privacy Eye Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              context.l10n.totalPortfolioValue,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                                color: const Color(0xFFF1E6CC).withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() => _obscured = !_obscured),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 17,
                                color: const Color(0xFFD4AF37),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.onDetailsTap != null)
                      InkWell(
                        onTap: widget.onDetailsTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.details,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFE5D5AA),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: Color(0xFFE5D5AA),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Main Portfolio Value + Gain
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _obscured ? '₹ ••••••' : currencyFormatter.format(widget.totalValue),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!_obscured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositiveGain
                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                              : Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPositiveGain
                                ? const Color(0xFF10B981).withValues(alpha: 0.45)
                                : Colors.redAccent.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositiveGain ? Icons.north_east_rounded : Icons.south_east_rounded,
                              size: 13,
                              color: isPositiveGain ? const Color(0xFF34D399) : Colors.redAccent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$gainSign${widget.gainPct.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isPositiveGain ? const Color(0xFF34D399) : Colors.redAccent,
                              ),
                            ),
                            if (widget.gainInr != 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '($gainSign₹${widget.gainInr.abs().toStringAsFixed(2)})',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isPositiveGain
                                      ? const Color(0xFF34D399).withValues(alpha: 0.85)
                                      : Colors.redAccent.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // Bottom Split Pills: Gold Owned & Silver Owned
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Gold Owned
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFFFFDF00), Color(0xFFD4AF37)],
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  '₹',
                                  style: TextStyle(
                                    color: Color(0xFF4A3700),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.goldOwned,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.65),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _obscured ? '••••' : _formatGrams(widget.goldGrams),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      const SizedBox(width: 8),
                      // Silver Owned
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.hexagon_outlined,
                                  size: 15,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.silverOwned,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.65),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _obscured ? '••••' : _formatGrams(widget.silverGrams),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
