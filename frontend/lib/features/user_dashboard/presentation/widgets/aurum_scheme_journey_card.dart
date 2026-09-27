import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_shop_withdrawal_sheet.dart';

class AurumSchemeJourneyCard extends StatelessWidget {
  final GoldScheme goldScheme;
  final double currentGrams;
  final double liveRatePerGram;
  final VoidCallback onChooseNextScheme;
  final VoidCallback onSellInquiry;

  const AurumSchemeJourneyCard({
    super.key,
    required this.goldScheme,
    required this.currentGrams,
    required this.liveRatePerGram,
    required this.onChooseNextScheme,
    required this.onSellInquiry,
  });

  String _formatGrams(double grams) {
    final s = grams.toStringAsFixed(4);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AurumConsumerTheme.isDark(context);
    final isCompleted = goldScheme.status.isCompleted;
    final targetGrams = goldScheme.targetGrams ?? 1.0;
    final remainingGrams = goldScheme.remainingGrams > 0 ? goldScheme.remainingGrams : 0.0;
    final progress = (goldScheme.progressPercent / 100).clamp(0.0, 1.0);

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final currentValue = currentGrams * liveRatePerGram;

    // COMPLETED STATE: Display celebratory card with Choose Next Scheme & Visit Shop to Withdraw
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF38290D),
              Color(0xFF231905),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFFFD700),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFFD700),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatGrams(targetGrams)}g Milestone Achieved! 🎉',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total: ${_formatGrams(currentGrams)}g (${currencyFormatter.format(currentValue)} current value)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFDF00),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Congratulations! You have completed your saving scheme. You can now choose another scheme to continue saving, or visit our showroom to withdraw the money for the current gold value (or collect your certified gold coin).',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Two Core Action Buttons:
            Row(
              children: [
                // Option 1: Choose Another Scheme
                Expanded(
                  child: OutlinedButton(
                    onPressed: onChooseNextScheme,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFDF00),
                      side: const BorderSide(color: Color(0xFFFFDF00), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Choose Next Scheme',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Option 2: Visit Shop to Withdraw
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      showShopWithdrawalSheet(
                        context: context,
                        goldGrams: currentGrams,
                        liveRatePerGram: liveRatePerGram,
                        onSellInquiryTap: onSellInquiry,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: const Color(0xFF2C1E03),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Withdraw at Shop',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ACTIVE JOURNEY STATE: Matches reference mockup
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
          // Top Row: Title + % Completed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.track_changes_rounded,
                        color: AppTheme.primaryGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your ${_formatGrams(targetGrams)} Gram Journey',
                        style: TextStyle(
                          fontSize: 14.5,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}% Completed',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark
                    ? const Color(0xFF263238)
                    : const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryGold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Caption: You have X g | Y g more to reach target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 11,
                      color: AurumConsumerTheme.muted(context),
                      fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
                    ),
                    children: [
                      const TextSpan(text: 'You have '),
                      TextSpan(
                        text: '${_formatGrams(currentGrams)} g',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E1A14),
                        ),
                      ),
                      const TextSpan(text: '  |  '),
                      TextSpan(
                        text: remainingGrams > 0
                            ? '${_formatGrams(remainingGrams)} g more to reach ${_formatGrams(targetGrams)} g'
                            : 'Target achieved!',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: onChooseNextScheme,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 13,
                        color: AppTheme.primaryGold,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Set Goal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),

          // 6 Stages Roadmap (Started -> First Investment -> Regular Saving -> Accumulation -> Target Progress -> Completed)
          Text(
            'Scheme Milestones:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AurumConsumerTheme.muted(context),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StagePill(
                  label: 'Started',
                  isReached: !goldScheme.status.isNotSelected,
                ),
                _StageConnector(isReached: currentGrams > 0),
                _StagePill(
                  label: 'First Investment',
                  isReached: currentGrams > 0,
                ),
                _StageConnector(isReached: currentGrams >= 0.05 || progress >= 0.1),
                _StagePill(
                  label: 'Regular Saving',
                  isReached: currentGrams >= 0.05 || progress >= 0.1,
                ),
                _StageConnector(isReached: progress >= 0.3),
                _StagePill(
                  label: 'Accumulation',
                  isReached: progress >= 0.3,
                ),
                _StageConnector(isReached: progress >= 0.6),
                _StagePill(
                  label: 'Target Progress',
                  isReached: progress >= 0.6,
                ),
                _StageConnector(isReached: isCompleted || progress >= 1.0),
                _StagePill(
                  label: 'Goal Completed',
                  isReached: isCompleted || progress >= 1.0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  final String label;
  final bool isReached;

  const _StagePill({required this.label, required this.isReached});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isReached
            ? AppTheme.primaryGold.withValues(alpha: 0.18)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReached ? AppTheme.primaryGold : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isReached ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 12,
            color: isReached ? AppTheme.primaryGold : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isReached ? FontWeight.w800 : FontWeight.w500,
              color: isReached ? AppTheme.primaryGold : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageConnector extends StatelessWidget {
  final bool isReached;

  const _StageConnector({required this.isReached});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 2,
      color: isReached ? AppTheme.primaryGold : Colors.grey.withValues(alpha: 0.3),
    );
  }
}
