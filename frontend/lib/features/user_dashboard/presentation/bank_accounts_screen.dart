import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/domain/bank_account.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/bank_account_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accountsAsync = ref.watch(bankAccountsProvider);

    return ResponsiveNavigationWrapper(
        title: l10n.bankAccounts,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(bankAccountsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AurumSurfaceCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.9),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.bankAccountsInfo,
                        style: TextStyle(
                          color: AurumConsumerTheme.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return _EmptyState(
                      onAdd: () => context.push('/bank-accounts/add'),
                    );
                  }
                  return Column(
                    children: [
                      ...accounts.map((a) => _BankCard(account: a)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/bank-accounts/add'),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addBankAccount),
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => AurumSurfaceCard(
                  child: Text(
                    '$e',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.bankAccountsOtpNote,
                style: TextStyle(
                  color: AurumConsumerTheme.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AurumSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 56,
            color: AurumConsumerTheme.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noBankAccountLinked,
            style: TextStyle(
              color: AurumConsumerTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noBankAccountSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurumConsumerTheme.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.addBankAccount),
          ),
        ],
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  final BankAccount account;

  const _BankCard({required this.account});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AurumSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    account.bankName,
                    style: TextStyle(
                      color: AurumConsumerTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (account.isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AurumConsumerTheme.chipGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Primary',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 12,
                        color: AurumConsumerTheme.liveGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.bankLinkVerified,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AurumConsumerTheme.liveGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              account.accountHolderName,
              style: TextStyle(color: AurumConsumerTheme.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              '${account.accountNumberMasked} · ${account.ifsc}',
              style: TextStyle(
                color: AurumConsumerTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              account.branchName,
              style: TextStyle(
                color: AurumConsumerTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
