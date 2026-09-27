import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/user_statements_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_transaction_history_section.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class UserTransactionsScreen extends ConsumerWidget {
  const UserTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return ResponsiveNavigationWrapper(
      title: l10n.statements,
      child: RefreshIndicator(
        color: AurumConsumerTheme.chipGold,
        onRefresh: () async {
          ref.invalidate(userStatementsProvider);
          await ref.read(userStatementsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: const [
            AurumTransactionHistorySection(),
          ],
        ),
      ),
    );
  }
}
