import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_data_table.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/presentation/providers/sell_inquiries_provider.dart';
import 'package:ags_gold/features/user_dashboard/domain/sell_gold_inquiry.dart';

class SellInquiriesScreen extends ConsumerWidget {
  const SellInquiriesScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'needs_info':
        return Colors.blue;
      case 'approved':
        return AppTheme.emerald;
      case 'rejected':
        return Colors.red;
      case 'payout_failed':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiriesAsync = ref.watch(sellInquiriesListProvider);
    final dateFormat = DateFormat('MMM d, yyyy');
    final gramFormat = NumberFormat('#,##0.##');
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    return ResponsiveNavigationWrapper(
      title: 'Gold Sell Inquiries',
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gold Sell Inquiries',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review customer sell requests and process approvals.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: inquiriesAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.sell_outlined,
                      title: 'No sell inquiries yet',
                      subtitle:
                          'Customer gold sell requests will appear here.',
                    );
                  }

                  if (isDesktop || isTablet) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(sellInquiriesListProvider);
                        await ref.read(sellInquiriesListProvider.future);
                      },
                      child: ListView(
                        children: [
                          PremiumDataTable<AdminSellGoldInquiry>(
                            items: items,
                            columns: [
                              DataTableColumn(
                                label: 'Date',
                                valueGetter: (i) => i.createdAt,
                                cellBuilder: (i) => InkWell(
                                  onTap: () => context.go(
                                    '/admin/sell-inquiries/${i.id}',
                                  ),
                                  child: Text(
                                    dateFormat.format(i.createdAt.toLocal()),
                                  ),
                                ),
                              ),
                              DataTableColumn(
                                label: 'Customer',
                                valueGetter: (i) => i.name,
                                cellBuilder: (i) => Text(i.name),
                              ),
                              DataTableColumn(
                                label: 'Mobile',
                                valueGetter: (i) => i.mobileNumber,
                                cellBuilder: (i) => Text(i.mobileNumber),
                              ),
                              DataTableColumn(
                                label: 'Quantity',
                                valueGetter: (i) => i.quantityGrams ?? 0,
                                cellBuilder: (i) => Text(
                                  '${gramFormat.format(i.quantityGrams ?? 0)} g',
                                ),
                              ),
                              DataTableColumn(
                                label: 'Gold balance',
                                valueGetter: (i) => i.goldBalanceGrams ?? 0,
                                cellBuilder: (i) => Text(
                                  '${gramFormat.format(i.goldBalanceGrams ?? 0)} g',
                                ),
                              ),
                              DataTableColumn(
                                label: 'Scheme',
                                valueGetter: (i) => i.goldSchemeStatus ?? '',
                                cellBuilder: (i) =>
                                    Text(i.goldSchemeStatus ?? '—'),
                              ),
                              DataTableColumn(
                                label: 'KYC',
                                valueGetter: (i) => i.kycStatus ?? '',
                                cellBuilder: (i) => Text(i.kycStatus ?? '—'),
                              ),
                              DataTableColumn(
                                label: 'Status',
                                valueGetter: (i) => i.status,
                                cellBuilder: (i) => Text(
                                  i.status.toUpperCase(),
                                  style: TextStyle(
                                    color: _statusColor(i.status),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(sellInquiriesListProvider);
                      await ref.read(sellInquiriesListProvider.future);
                    },
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final inquiry = items[index];
                        final statusColor = _statusColor(inquiry.status);
                        return _inquiryCard(
                          context,
                          inquiry,
                          statusColor,
                          dateFormat,
                          gramFormat,
                        );
                      },
                    ),
                  );
                },
                loading: () => const PremiumSkeletonList(itemCount: 5),
                error: (error, _) =>
                    Center(child: Text('Failed to load: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inquiryCard(
    BuildContext context,
    AdminSellGoldInquiry inquiry,
    Color statusColor,
    DateFormat dateFormat,
    NumberFormat gramFormat,
  ) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/admin/sell-inquiries/${inquiry.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      inquiry.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      inquiry.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(inquiry.mobileNumber),
              const SizedBox(height: 8),
              Text(
                'Qty: ${gramFormat.format(inquiry.quantityGrams ?? 0)} g • '
                'Balance: ${gramFormat.format(inquiry.goldBalanceGrams ?? 0)} g',
              ),
              const SizedBox(height: 4),
              Text(
                'Scheme: ${inquiry.goldSchemeStatus ?? '—'} • '
                'KYC: ${inquiry.kycStatus ?? '—'}',
              ),
              const SizedBox(height: 8),
              Text(
                dateFormat.format(inquiry.createdAt.toLocal()),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
