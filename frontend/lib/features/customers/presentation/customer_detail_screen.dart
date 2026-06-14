import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/customers/domain/customer.dart';
import 'package:ags_gold/features/customers/presentation/providers/customers_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'blacklisted':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete "${customer.fullName}"? '
          'This action can be reversed by an administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(deleteCustomerProvider)(customer.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer deleted successfully')),
      );
      context.go('/customers');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete customer: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    return ResponsiveNavigationWrapper(
      title: 'Customer Details',
      child: customerAsync.when(
        data: (customer) =>
            _buildContent(context, ref, customer, currency, dateFormat),
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeletonList(itemCount: 6),
        ),
        error: (e, _) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Customer not found',
          subtitle: e.toString(),
          actionLabel: 'Back to list',
          onAction: () => context.go('/customers'),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
    NumberFormat currency,
    DateFormat dateFormat,
  ) {
    final profile = ref.watch(profileProvider).value;
    final canUpdate =
        profile != null && hasPermission(profile, 'customer.update');
    final canDelete =
        profile != null && hasPermission(profile, 'customer.delete');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.15),
                child: Text(
                  customer.fullName.isNotEmpty
                      ? customer.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Chip(
                          label: Text(customer.displayType),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            customer.displayStatus,
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: _statusColor(customer.status),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canUpdate)
                FilledButton.icon(
                  onPressed: () => context.go('/customers/${customer.id}/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              if (canUpdate && canDelete) const SizedBox(width: 8),
              if (canDelete)
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context, ref, customer),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          _sectionTitle(context, 'Contact Information'),
          _infoCard([
            _infoRow(Icons.email_outlined, 'Email', customer.email),
            _infoRow(Icons.phone_outlined, 'Mobile', customer.mobileNumber),
            _infoRow(Icons.location_on_outlined, 'Address', customer.address),
            if (customer.gstNumber != null)
              _infoRow(
                Icons.receipt_long_outlined,
                'GST Number',
                customer.gstNumber!,
              ),
          ]),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Business Metrics'),
          _infoCard([
            _infoRow(
              Icons.shopping_bag_outlined,
              'Total Purchases',
              '${customer.totalPurchases}',
            ),
            _infoRow(
              Icons.payments_outlined,
              'Total Revenue',
              currency.format(customer.totalRevenue),
            ),
            _infoRow(
              Icons.event_outlined,
              'Last Transaction',
              customer.lastTransactionDate != null
                  ? dateFormat.format(customer.lastTransactionDate!)
                  : 'No transactions yet',
            ),
          ]),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Record Information'),
          _infoCard([
            _infoRow(Icons.fingerprint, 'Customer ID', customer.id),
            _infoRow(
              Icons.calendar_today_outlined,
              'Created',
              dateFormat.format(customer.createdAt),
            ),
            _infoRow(
              Icons.update_outlined,
              'Last Updated',
              dateFormat.format(customer.updatedAt),
            ),
          ]),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => context.go('/customers'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Customers'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: rows),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
