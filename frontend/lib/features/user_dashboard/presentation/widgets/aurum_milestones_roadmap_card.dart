import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';

class AurumMilestonesRoadmapCard extends StatelessWidget {
  final double currentGoldGrams;
  final VoidCallback? onTap;

  const AurumMilestonesRoadmapCard({
    super.key,
    required this.currentGoldGrams,
    this.onTap,
  });

  static const List<double> _milestones = [0.01, 0.1, 1.0, 5.0, 10.0];

  @override
  Widget build(BuildContext context) {
    final isDark = AurumConsumerTheme.isDark(context);

    // Find the next milestone
    double nextMilestone = _milestones.last;
    for (final m in _milestones) {
      if (currentGoldGrams < m) {
        nextMilestone = m;
        break;
      }
    }

    final double pctToGo;
    if (currentGoldGrams >= nextMilestone) {
      pctToGo = 0.0;
    } else {
      pctToGo = ((nextMilestone - currentGoldGrams) / nextMilestone * 100).clamp(0, 100);
    }

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Icons.emoji_events_outlined,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Savings Milestones',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1A14),
                    ),
                  ),
                ],
              ),
              // Next Milestone Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF38290D) : const Color(0xFFFBF4DC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Next: ${nextMilestone}g',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryGold,
                      ),
                    ),
                    Text(
                      pctToGo > 0 ? '${pctToGo.toStringAsFixed(0)}% to go' : 'Achieved! 🏆',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AurumConsumerTheme.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Horizontal Stepper
          Row(
            children: List.generate(_milestones.length * 2 - 1, (index) {
              // Odd indices are connecting lines
              if (index.isOdd) {
                final stepIndex = index ~/ 2;
                final isCompletedLine = currentGoldGrams >= _milestones[stepIndex];
                return Expanded(
                  child: Container(
                    height: 3,
                    color: isCompletedLine
                        ? AppTheme.primaryGold
                        : (isDark ? const Color(0xFF263238) : const Color(0xFFE2E8F0)),
                  ),
                );
              }

              // Even indices are step dots
              final stepIndex = index ~/ 2;
              final milestone = _milestones[stepIndex];
              final isReached = currentGoldGrams >= milestone;

              return Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isReached
                          ? AppTheme.primaryGold
                          : (isDark ? const Color(0xFF1E2836) : const Color(0xFFE2E8F0)),
                      border: Border.all(
                        color: isReached
                            ? AppTheme.primaryGold
                            : AurumConsumerTheme.borderOf(context),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isReached
                          ? const Icon(
                              Icons.check,
                              size: 15,
                              color: Color(0xFF2C1E03),
                            )
                          : Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AurumConsumerTheme.muted(context),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${milestone}g',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isReached ? FontWeight.w800 : FontWeight.w600,
                      color: isReached
                          ? AppTheme.primaryGold
                          : AurumConsumerTheme.muted(context),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
