import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/trade_amount_form.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

MetalType metalFromQuery(GoRouterState state) {
  final raw = state.uri.queryParameters['metal']?.toLowerCase();
  return raw == 'silver' ? MetalType.silver : MetalType.gold;
}

double? initialAmountFromQuery(GoRouterState state) {
  final raw = state.uri.queryParameters['amount'];
  if (raw != null) return double.tryParse(raw);
  return null;
}

class BuyGoldScreen extends StatelessWidget {
  const BuyGoldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = GoRouterState.of(context);
    final metal = metalFromQuery(state);
    final initialAmount = initialAmountFromQuery(state);
    final isSilver = metal == MetalType.silver;
    final title = isSilver ? l10n.buySilver : l10n.buyGold;

    return ResponsiveNavigationWrapper(
      title: title,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TradeAmountForm(
          isBuy: true,
          metal: metal,
          initialAmount: initialAmount,
        ),
      ),
    );
  }
}
