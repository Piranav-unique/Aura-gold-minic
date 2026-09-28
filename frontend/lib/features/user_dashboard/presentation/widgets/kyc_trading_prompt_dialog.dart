import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/widgets/aura_dialog_actions.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/pending_trade_provider.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

Future<void> showKycTradingPrompt(
  BuildContext context,
  WidgetRef ref, {
  required bool isBuy,
  required MetalType metal,
}) async {
  final l10n = context.l10n;
  final actionLabel = _actionLabel(l10n, isBuy, metal);

  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.verified_user_outlined),
      title: Text(l10n.kycPromptTitle),
      content: Text(l10n.kycPromptMessage(actionLabel)),
      actions: [
        AuraDialogActions.buttons(
          context: context,
          cancelLabel: l10n.cancel,
          onCancel: () => Navigator.pop(context, false),
          confirmLabel: l10n.kycBannerStartAction,
          onConfirm: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );

  if (proceed == true && context.mounted) {
    ref.read(pendingTradeProvider.notifier).set(
      PendingTrade(isBuy: isBuy, metal: metal),
    );
    context.push('/kyc');
  }
}

String _actionLabel(dynamic l10n, bool isBuy, MetalType metal) {
  if (metal == MetalType.silver) {
    return isBuy ? l10n.buySilver : l10n.sellSilver;
  }
  return isBuy ? l10n.buyGold : l10n.sellGold;
}
