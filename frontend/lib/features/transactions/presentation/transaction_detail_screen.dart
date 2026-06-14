import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/transactions/domain/transaction.dart';
import 'package:ags_gold/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/utils/file_download.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  Future<void> _cancelTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction txn,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel transaction'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Why is this transaction being cancelled?',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep active'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel transaction'),
          ),
        ],
      ),
    );

    if (confirmed != true || reasonController.text.trim().isEmpty) return;

    try {
      await ref.read(cancelTransactionProvider)(
        transactionId,
        reasonController.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction cancelled')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
      }
    }
  }

  Future<void> _showDocument(
    BuildContext context,
    TransactionDocument doc,
  ) async {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doc.documentType == 'invoice' ? 'Invoice' : 'Receipt'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Number: ${doc.documentNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Transaction: ${doc.transactionNumber}'),
              if (doc.customerName != null)
                Text('Customer: ${doc.customerName}'),
              Text('Total: ${currency.format(doc.totalAmount)}'),
              const SizedBox(height: 12),
              ...doc.lines.map(
                (line) => Text(
                  '${line.itemName} x${line.quantity} — ${currency.format(line.lineTotal)}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              downloadTextFile(
                filename: '${doc.documentNumber}.json',
                content: const JsonEncoder.withIndent('  ').convert({
                  'document_type': doc.documentType,
                  'document_number': doc.documentNumber,
                  'transaction_number': doc.transactionNumber,
                  'total_amount': doc.totalAmount,
                }),
                mimeType: 'application/json',
              );
            },
            child: const Text('Download JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnAsync = ref.watch(transactionDetailProvider(transactionId));
    final profile = ref.watch(profileProvider).value;
    final canUpdate =
        profile != null && hasPermission(profile, 'transaction.update');
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    return ResponsiveNavigationWrapper(
      title: 'Transaction Details',
      child: txnAsync.when(
        data: (txn) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          txn.transactionNumber,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${transactionTypeLabel(txn.transactionType)} • ${paymentStatusLabel(txn.paymentStatus)}',
                        ),
                      ],
                    ),
                  ),
                  if (canUpdate && !txn.isCancelled) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.go('/transactions/$transactionId/edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _cancelTransaction(context, ref, txn),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final doc = await ref.read(generateInvoiceProvider)(
                          transactionId,
                        );
                        if (context.mounted) await _showDocument(context, doc);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Invoice failed: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: Text(txn.invoiceNumber ?? 'Generate Invoice'),
                  ),
                  if (txn.isPaid)
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final doc = await ref.read(generateReceiptProvider)(
                            transactionId,
                          );
                          if (context.mounted) {
                            await _showDocument(context, doc);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Receipt failed: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(txn.receiptNumber ?? 'Generate Receipt'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Customer', txn.customer?.fullName ?? '—'),
                      _detailRow('Subtotal', currency.format(txn.subtotal)),
                      _detailRow('Tax', currency.format(txn.taxAmount)),
                      _detailRow(
                        'Total',
                        currency.format(txn.totalAmount),
                        bold: true,
                      ),
                      _detailRow(
                        'Stock applied',
                        txn.stockApplied ? 'Yes' : 'No',
                      ),
                      _detailRow('Created', dateFormat.format(txn.createdAt)),
                      if (txn.notes != null && txn.notes!.isNotEmpty)
                        _detailRow('Notes', txn.notes!),
                      if (txn.isCancelled) ...[
                        _detailRow(
                          'Cancelled',
                          dateFormat.format(txn.cancelledAt!),
                        ),
                        _detailRow('Reason', txn.cancellationReason ?? '—'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Line Items',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: txn.lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = txn.lines[index];
                    return ListTile(
                      title: Text(line.itemName),
                      subtitle: Text(
                        'Qty ${line.quantity} • ${line.stockDirection.toUpperCase()}',
                      ),
                      trailing: Text(currency.format(line.lineTotal)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeletonCard(),
        ),
        error: (error, _) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Transaction not found',
          subtitle: error.toString(),
          actionLabel: 'Back to list',
          onAction: () => context.go('/transactions'),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
