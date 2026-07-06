import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme_utils.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/gold_scheme_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/services/api_client.dart';

enum SchemeCompletionChoice { stay, sell, upgrade }

class SchemeCompletionResult {
  final SchemeCompletionChoice choice;
  final int? upgradeGrams;

  const SchemeCompletionResult(this.choice, [this.upgradeGrams]);
}

void openSellGoldInquiry(BuildContext context) {
  context.push('/sell-gold-inquiry');
}

/// Shown when the user completes a gold savings scheme target.
Future<SchemeCompletionResult?> showSchemeCompletionDialog(
  BuildContext context,
  WidgetRef ref,
  GoldScheme scheme,
) {
  if (!scheme.status.isCompleted) {
    return Future.value(null);
  }

  final l10n = context.l10n;
  final completedGrams = scheme.targetGrams?.toStringAsFixed(0) ?? '';
  final upgradeOptions = goldSchemeUpgradeOptions(scheme);
  final completedTier = scheme.targetGrams?.round() ?? 0;
  final bodyText = completedTier <= 1
      ? l10n.goldSchemeCompletionBodyAfter1g
      : completedTier <= 5
          ? l10n.goldSchemeCompletionBodyAfter5g
          : l10n.goldSchemeCompletionBodyMaxTier;

  return showDialog<SchemeCompletionResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AurumConsumerTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.celebration_outlined, color: AppTheme.primaryGold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.goldSchemeCompletionTitle(completedGrams),
                style: TextStyle(
                  color: AurumConsumerTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          bodyText,
          style: TextStyle(
            color: AurumConsumerTheme.textMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(
                const SchemeCompletionResult(SchemeCompletionChoice.sell),
              ),
              icon: const Icon(Icons.sell_outlined, size: 18),
              label: Text(l10n.goldSchemeCompletionSell),
            ),
          ),
          for (final grams in upgradeOptions) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(
                  SchemeCompletionResult(SchemeCompletionChoice.upgrade, grams),
                ),
                child: Text(l10n.goldSchemeCompletionUpgrade(grams)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                const SchemeCompletionResult(SchemeCompletionChoice.stay),
              ),
              child: Text(l10n.goldSchemeCompletionStay),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> navigateAfterSchemeCompletion(
  BuildContext context,
  WidgetRef ref,
  SchemeCompletionResult? result,
) async {
  if (!context.mounted) return;

  if (result == null) {
    context.go('/user-dashboard');
    return;
  }

  switch (result.choice) {
    case SchemeCompletionChoice.sell:
      openSellGoldInquiry(context);
      return;
    case SchemeCompletionChoice.upgrade:
      final grams = result.upgradeGrams;
      if (grams != null) {
        await handleSchemeUpgrade(
          context: context,
          ref: ref,
          targetGrams: grams,
        );
      }
      return;
    case SchemeCompletionChoice.stay:
      context.go('/user-dashboard');
  }
}

/// Called when a scheme becomes completed (after buy, join, or upgrade).
Future<void> handleSchemeJustCompleted(
  BuildContext context,
  WidgetRef ref,
  GoldScheme scheme,
) async {
  if (!scheme.status.isCompleted) return;

  if (goldSchemeIsMaxTier(scheme)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.goldSchemeCompletionAutoSell)),
    );
    openSellGoldInquiry(context);
    return;
  }

  final choice = await showSchemeCompletionDialog(context, ref, scheme);
  if (!context.mounted) return;
  await navigateAfterSchemeCompletion(context, ref, choice);
}

Future<void> handleSchemeUpgrade({
  required BuildContext context,
  required WidgetRef ref,
  required int targetGrams,
}) async {
  final l10n = context.l10n;

  try {
    final updated = await ref.read(upgradeGoldSchemeProvider)(targetGrams);
    await ref.read(personalDashboardProvider.notifier).refresh();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.goldSchemeUpgraded(targetGrams)),
      ),
    );

    if (updated.status.isCompleted) {
      await handleSchemeJustCompleted(context, ref, updated);
    } else if (updated.status.isActive) {
      context.push('/buy-gold?metal=gold');
    }
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.goldSchemeUpgradeFailed)),
    );
  }
}
