import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/buy_gold_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/trade_amount_form.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class SellGoldScreen extends StatelessWidget {
  const SellGoldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metal = metalFromQuery(GoRouterState.of(context));
    final isSilver = metal == MetalType.silver;
    final title = isSilver ? l10n.sellSilver : l10n.sellGold;

    return ResponsiveNavigationWrapper(
      title: title,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TradeAmountForm(isBuy: false, metal: metal),
      ),
    );
  }
}
