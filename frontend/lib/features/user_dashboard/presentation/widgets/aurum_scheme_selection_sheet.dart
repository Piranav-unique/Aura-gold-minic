import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme_utils.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/gold_scheme_provider.dart';

Future<void> showSelectOrUpgradeSchemeSheet({
  required BuildContext context,
  required WidgetRef ref,
  required GoldScheme currentScheme,
}) {
  final isDark = AurumConsumerTheme.isDark(context);
  final isCompleted = currentScheme.status.isCompleted;
  final currentTier = currentScheme.targetGrams?.round() ?? 0;
  final upgradeOptions = goldSchemeUpgradeOptions(currentScheme);

  final tiers = [
    {'grams': 1, 'title': '1 Gram Gold Goal', 'subtitle': 'Ideal for beginners & micro-savings'},
    {'grams': 5, 'title': '5 Gram Gold Goal', 'subtitle': 'Perfect for family festivals & gifts'},
    {'grams': 10, 'title': '10 Gram Gold Goal', 'subtitle': 'Maximum savings for long-term wealth'},
  ];

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          bool loading = false;

          Future<void> onTierSelect(int grams) async {
            setState(() => loading = true);
            try {
              if (isCompleted && upgradeOptions.contains(grams)) {
                await ref.read(upgradeGoldSchemeProvider)(grams);
              } else {
                await ref.read(selectGoldSchemeProvider)(grams);
              }
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text('Switched to ${grams}g Gold Savings Goal!')),
                );
              }
            } catch (e) {
              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text('Failed to update scheme: $e')),
                );
              }
            } finally {
              setState(() => loading = false);
            }
          }

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: AurumConsumerTheme.surfaceOf(sheetContext),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: AurumConsumerTheme.borderOf(sheetContext),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.track_changes_rounded,
                        color: AppTheme.primaryGold,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCompleted ? 'Choose Next Gold Scheme' : 'Select Your Gold Savings Goal',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1E1A14),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Earn 24K pure physical gold coins delivered to your home',
                            style: TextStyle(
                              fontSize: 12,
                              color: AurumConsumerTheme.muted(sheetContext),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  ...tiers.map((t) {
                    final grams = t['grams'] as int;
                    final isCurrent = grams == currentTier;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => onTierSelect(grams),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? (isDark ? const Color(0xFF38290D) : const Color(0xFFFBF4DC))
                                : AurumConsumerTheme.surfaceElevatedOf(sheetContext),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrent
                                  ? AppTheme.primaryGold
                                  : AurumConsumerTheme.borderOf(sheetContext),
                              width: isCurrent ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFDF00), Color(0xFFD4AF37)],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${grams}g',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF38290D),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          t['title'] as String,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF1E1A14),
                                          ),
                                        ),
                                        if (isCurrent) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryGold,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Active',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF2C1E03),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      t['subtitle'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AurumConsumerTheme.muted(sheetContext),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppTheme.primaryGold,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      );
    },
  );
}
