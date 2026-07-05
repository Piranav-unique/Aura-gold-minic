import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class DashboardMenuSection extends StatelessWidget {
  const DashboardMenuSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MenuTile(
          icon: Icons.savings_outlined,
          title: l10n.mySavings,
          onTap: () => context.push('/my-savings'),
        ),
        const SizedBox(height: 10),
        _MenuTile(
          icon: Icons.receipt_long_outlined,
          title: l10n.myTransactions,
          onTap: () => context.push('/user-transactions'),
        ),
        const SizedBox(height: 10),
        _MenuTile(
          icon: Icons.account_balance_outlined,
          title: l10n.bankAccounts,
          onTap: () => context.push('/bank-accounts'),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AurumConsumerTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AurumConsumerTheme.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryGold, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AurumConsumerTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AurumConsumerTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
