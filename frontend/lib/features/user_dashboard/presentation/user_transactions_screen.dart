import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/user_statements_provider.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class UserTransactionsScreen extends ConsumerWidget {
  const UserTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statementsAsync = ref.watch(userStatementsProvider);

    return ResponsiveNavigationWrapper(
      title: l10n.statements,
      child: statementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(userStatementsProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return _EmptyState(message: l10n.noTransactionsYet);
          }

          return RefreshIndicator(
            color: AurumConsumerTheme.chipGold,
            onRefresh: () async {
              ref.invalidate(userStatementsProvider);
              await ref.read(userStatementsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: page.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _StatementCard(item: page.items[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        Icon(
          Icons.receipt_long_outlined,
          size: 56,
          color: AurumConsumerTheme.muted(context),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurumConsumerTheme.muted(context),
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AurumConsumerTheme.muted(context)),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  final WalletTransactionItem item;

  const _StatementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('d MMM yyyy, h:mm a');
    final isBuy = item.transactionType.toUpperCase() == 'BUY';
    final isSell = item.transactionType.toUpperCase() == 'SELL';
    final accent = isBuy
        ? const Color(0xFF1B7F4B)
        : isSell
            ? const Color(0xFFB45309)
            : AppTheme.primaryGold;

    return Material(
      color: AurumConsumerTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AurumConsumerTheme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBuy
                      ? Icons.add_shopping_cart_rounded
                      : isSell
                          ? Icons.sell_outlined
                          : Icons.receipt_long_outlined,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _titleFor(item),
                            style: TextStyle(
                              color: AurumConsumerTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _StatusChip(status: item.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(item.occurredAt.toLocal()),
                      style: TextStyle(
                        color: AurumConsumerTheme.muted(context),
                        fontSize: 12.5,
                      ),
                    ),
                    if (item.metal != null || item.quantityGrams != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _detailsFor(item),
                        style: TextStyle(
                          color: AurumConsumerTheme.textPrimary,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                    if (item.amountInr != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        currency.format(item.amountInr),
                        style: TextStyle(
                          color: AurumConsumerTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  String _titleFor(WalletTransactionItem item) {
    switch (item.transactionType.toUpperCase()) {
      case 'BUY':
        return 'Buy ${item.metal ?? 'Gold'}';
      case 'SELL':
        return 'Sell Gold';
      case 'REFERRAL':
        return 'Referral reward';
      case 'SAVINGS':
        return 'Savings scheme';
      default:
        return item.transactionType;
    }
  }

  String _detailsFor(WalletTransactionItem item) {
    final parts = <String>[];
    if (item.metal != null) {
      parts.add(item.metal!);
    }
    if (item.quantityGrams != null) {
      parts.add('${item.quantityGrams!.toStringAsFixed(4)} g');
    }
    return parts.join(' • ');
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(status);
    final color = _colorFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _labelFor(String raw) {
    switch (raw.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'created':
        return 'Pending';
      case 'pending':
        return 'Pending';
      case 'responded':
        return 'Responded';
      case 'closed':
        return 'Closed';
      case 'failed':
        return 'Failed';
      case 'completed':
        return 'Completed';
      default:
        return raw;
    }
  }

  Color _colorFor(String raw) {
    switch (raw.toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'responded':
        return const Color(0xFF1B7F4B);
      case 'failed':
        return Colors.redAccent;
      case 'pending':
      case 'created':
        return const Color(0xFFB45309);
      default:
        return AurumConsumerTheme.textMuted;
    }
  }
}
