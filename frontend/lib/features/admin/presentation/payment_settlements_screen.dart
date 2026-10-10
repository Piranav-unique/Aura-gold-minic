import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/presentation/providers/payment_settlements_provider.dart';
import 'package:ags_gold/features/admin/presentation/wallet_transaction_detail_sheet.dart';
import 'package:ags_gold/services/service_providers.dart';

class PaymentSettlementsScreen extends ConsumerStatefulWidget {
  final String? initialCustomerFilter;

  const PaymentSettlementsScreen({
    super.key,
    this.initialCustomerFilter,
  });

  @override
  ConsumerState<PaymentSettlementsScreen> createState() =>
      _PaymentSettlementsScreenState();
}

class _PaymentSettlementsScreenState
    extends ConsumerState<PaymentSettlementsScreen> {
  String? _selectedCustomerMobile;
  String? _selectedMethod;
  String? _selectedMetal;
  String _searchQuery = '';
  bool _isSyncing = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomerFilter != null &&
        widget.initialCustomerFilter!.isNotEmpty) {
      _selectedCustomerMobile = widget.initialCustomerFilter;
      _searchController.text = widget.initialCustomerFilter!;
      _searchQuery = widget.initialCustomerFilter!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _resolveDisplayName(String? rawName, String? mobile) {
    final trimmed = rawName?.trim() ?? '';
    final isHuman = trimmed.isNotEmpty &&
        !trimmed.startsWith('+91') &&
        !trimmed.toLowerCase().startsWith('customer') &&
        !RegExp(r'^\d+$').hasMatch(trimmed.replaceAll(RegExp(r'[\s\-\+]'), ''));
    return isHuman ? trimmed : 'Customer';
  }

  static String _getInitials(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 'C';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final settlementsAsync = ref.watch(paymentSettlementsProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return ResponsiveNavigationWrapper(
      title: 'Customer Payments',
      child: settlementsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeletonList(itemCount: 6),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Failed to load payments',
              subtitle: '$error',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(paymentSettlementsProvider),
            ),
          ),
        ),
        data: (items) {
          // 1. Group unique customers from all payments
          final Map<String, _CustomerSummary> customerMap = {};

          for (final row in items) {
            final mobile = (row['user_mobile'] as String?)?.trim() ??
                (row['customer_mobile'] as String?)?.trim() ??
                '';
            final rawName = (row['user_name'] as String?)?.trim() ??
                (row['customer_name'] as String?)?.trim();
            final email = (row['user_email'] as String?)?.trim() ??
                (row['customer_email'] as String?)?.trim() ??
                '';

            // Never include superadmin, Yogesh (fake payment), dev_mock, or website orders
            final emailLower = email.toLowerCase();
            final nameLower = (rawName ?? '').toLowerCase();
            final payId = (row['razorpay_payment_id'] as String? ?? '').toLowerCase();
            final ordId = (row['razorpay_order_id'] as String? ?? '').toLowerCase();
            const websiteOrders = [
              'order_tkkr0wuxpyd8g5',
              'order_tkkk5aziucoffgz',
              'order_tkkizdw6snmxra',
              'order_tkkc5pv5wdc87y',
              'order_tkkppycdwgd8cd',
              'order_tkksa3pktbihkk',
            ];
            if (emailLower.contains('superadmin') ||
                emailLower.contains('admin@agsgold') ||
                nameLower.contains('super admin') ||
                mobile == '9943795005' ||
                payId.contains('dev_mock') ||
                ordId.contains('order_dev_') ||
                websiteOrders.contains(ordId)) {
              continue;
            }

            final gross = _num(row['gross_amount_inr'] ?? row['amount_inr'] ?? (row['amount_paise'] != null ? _num(row['amount_paise']) / 100 : 0));
            final status = (row['status'] as String? ?? '').toLowerCase();
            final isPaid = status.isEmpty || status == 'paid' || status == 'captured';

            final key = mobile.isNotEmpty ? mobile : (email.isNotEmpty ? email : 'unknown');

            if (!customerMap.containsKey(key)) {
              customerMap[key] = _CustomerSummary(
                key: key,
                name: _resolveDisplayName(rawName, mobile),
                rawName: rawName,
                mobile: mobile,
                email: email,
                totalPaid: 0,
                orderCount: 0,
              );
            }

            final summary = customerMap[key]!;
            if (rawName != null && summary.name == 'Customer') {
              summary.name = _resolveDisplayName(rawName, mobile);
              summary.rawName = rawName;
            }
            if (isPaid) {
              summary.totalPaid += gross;
            }
            summary.orderCount += 1;
          }

          final customers = customerMap.values.toList()
            ..sort((a, b) => b.totalPaid.compareTo(a.totalPaid));

          final queryClean = _searchQuery.trim().toLowerCase();
          final qDigits = queryClean.replaceAll(RegExp(r'\D'), '');
          final displayedCustomers = queryClean.isEmpty
              ? customers
              : customers.where((c) {
                  final mDigits = c.mobile.replaceAll(RegExp(r'\D'), '');
                  final phoneMatches = qDigits.isNotEmpty && mDigits.contains(qDigits);
                  return c.name.toLowerCase().contains(queryClean) ||
                      c.mobile.toLowerCase().contains(queryClean) ||
                      c.email.toLowerCase().contains(queryClean) ||
                      phoneMatches;
                }).toList();

          // 2. Filter payments based on search, selected customer, method, metal
          final filteredItems = items.where((row) {
            final mobile = (row['user_mobile'] as String?)?.trim() ??
                (row['customer_mobile'] as String?)?.trim() ??
                '';
            final email = (row['user_email'] as String?)?.trim() ??
                (row['customer_email'] as String?)?.trim() ??
                '';
            final rawName = (row['user_name'] as String?)?.trim() ??
                (row['customer_name'] as String?)?.trim() ??
                '';

            // Never include superadmin, Yogesh (fake payment), dev_mock, or website orders in payment records
            final emailLower = email.toLowerCase();
            final nameLower = rawName.toLowerCase();
            final payId = (row['razorpay_payment_id'] as String? ?? '').toLowerCase();
            final ordId = (row['razorpay_order_id'] as String? ?? '').toLowerCase();
            const websiteOrders = [
              'order_tkkr0wuxpyd8g5',
              'order_tkkk5aziucoffgz',
              'order_tkkizdw6snmxra',
              'order_tkkc5pv5wdc87y',
              'order_tkkppycdwgd8cd',
              'order_tkksa3pktbihkk',
            ];
            if (emailLower.contains('superadmin') ||
                emailLower.contains('admin@agsgold') ||
                nameLower.contains('super admin') ||
                mobile == '9943795005' ||
                payId.contains('dev_mock') ||
                ordId.contains('order_dev_') ||
                websiteOrders.contains(ordId)) {
              return false;
            }
            final method = (row['payment_method'] as String? ?? '').toLowerCase();
            final metal = (row['metal'] as String? ?? '').toLowerCase();
            final paymentId = (row['razorpay_payment_id'] as String? ?? '').toLowerCase();
            final bankRrn = (row['bank_rrn'] as String? ?? '').toLowerCase();

            // Customer selection filter (Requirement 10: only show this customer's payments!)
            if (_selectedCustomerMobile != null && _selectedCustomerMobile!.isNotEmpty) {
              final sel = _selectedCustomerMobile!.trim().replaceAll(RegExp(r'\D'), '');
              final mDigits = mobile.replaceAll(RegExp(r'\D'), '');
              if (mDigits.isNotEmpty && sel.isNotEmpty) {
                if (!mDigits.contains(sel) && !sel.contains(mDigits)) {
                  return false;
                }
              } else if (mobile != _selectedCustomerMobile && email != _selectedCustomerMobile) {
                return false;
              }
            }

            // Payment method filter
            if (_selectedMethod != null && _selectedMethod != 'all') {
              if (!method.contains(_selectedMethod!)) return false;
            }

            // Metal filter
            if (_selectedMetal != null && _selectedMetal != 'all') {
              if (metal != _selectedMetal) return false;
            }

            // Search query filter
            if (_searchQuery.trim().isNotEmpty) {
              final q = _searchQuery.trim().toLowerCase();
              final matches = rawName.toLowerCase().contains(q) ||
                  mobile.toLowerCase().contains(q) ||
                  email.toLowerCase().contains(q) ||
                  paymentId.contains(q) ||
                  bankRrn.contains(q);
              if (!matches) return false;
            }

            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              try {
                final api = ref.read(apiClientProvider);
                await api.post('/payments/razorpay/sync-all');
              } catch (_) {}
              ref.invalidate(paymentSettlementsProvider);
              await ref.read(paymentSettlementsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header with Sync Button
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Payments',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Overview of customer purchase payments, payment modes, and merchant settlements.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSyncing
                          ? null
                          : () async {
                              setState(() => _isSyncing = true);
                              try {
                                final api = ref.read(apiClientProvider);
                                await api.post('/payments/razorpay/sync-all');
                                ref.invalidate(paymentSettlementsProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Payments synchronized from Razorpay!'),
                                      backgroundColor: Color(0xFF16A34A),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Sync note: $e'),
                                      backgroundColor: Colors.orange.shade800,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isSyncing = false);
                              }
                            },
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync, size: 16),
                      label: Text(_isSyncing ? 'Syncing...' : 'Sync Razorpay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC59A27),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search input
                Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    final isDark = theme.brightness == Brightness.dark;
                    final inputFill = isDark ? theme.cardColor : Colors.white;
                    final inputBorder = isDark ? theme.dividerColor : const Color(0xFFE2E8F0);
                    return TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by customer name, mobile, email, or payment ID...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: inputFill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Customers Section Header
                Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    final isDark = theme.brightness == Brightness.dark;
                    final textPrimary = isDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18);
                    final goldAccent = isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          queryClean.isEmpty
                              ? 'Paying Customers (${customers.length})'
                              : 'Paying Customers (${displayedCustomers.length})',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        if (_selectedCustomerMobile != null || queryClean.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCustomerMobile = null;
                                if (queryClean.isNotEmpty) {
                                  _searchController.clear();
                                  _searchQuery = '';
                                }
                              });
                            },
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('View All Customers'),
                            style: TextButton.styleFrom(
                              foregroundColor: goldAccent,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),

                // Horizontal Customer Selector
                if (displayedCustomers.isEmpty)
                  Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      final isDark = theme.brightness == Brightness.dark;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? theme.cardColor : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? theme.dividerColor : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'No paying customers match "$_searchQuery"',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                else
                  SizedBox(
                    height: 104,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: displayedCustomers.length + (queryClean.isEmpty ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, idx) {
                        final theme = Theme.of(context);
                        final isDark = theme.brightness == Brightness.dark;
                        final cardBg = isDark ? theme.cardColor : Colors.white;
                        final selectedCardBg = isDark
                            ? const Color(0xFFD4AF37).withValues(alpha: 0.14)
                            : const Color(0xFFFFFBEB);
                        final cardBorder = isDark ? theme.dividerColor : const Color(0xFFE2E8F0);
                        final selectedBorder = isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27);
                        final textPrimary = isDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18);
                        final textMuted = isDark
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
                            : const Color(0xFF64748B);

                        if (queryClean.isEmpty && idx == 0) {
                          final isSelected = _selectedCustomerMobile == null;
                          return InkWell(
                            onTap: () => setState(() => _selectedCustomerMobile = null),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 130,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? selectedCardBg : cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? selectedBorder : cardBorder,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isSelected
                                        ? const Color(0xFFC59A27)
                                        : (isDark ? const Color(0xFF1A2432) : const Color(0xFFF1F5F9)),
                                    child: Icon(
                                      Icons.group,
                                      size: 16,
                                      color: isSelected ? Colors.white : textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'All Customers',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${items.length} orders',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final c = queryClean.isEmpty ? displayedCustomers[idx - 1] : displayedCustomers[idx];
                        final isSelected = _selectedCustomerMobile == c.mobile ||
                            _selectedCustomerMobile == c.key;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (_selectedCustomerMobile == c.mobile ||
                                  _selectedCustomerMobile == c.key) {
                                _selectedCustomerMobile = null;
                              } else {
                                _selectedCustomerMobile = c.mobile.isNotEmpty ? c.mobile : c.key;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 175,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? selectedCardBg : cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? selectedBorder : cardBorder,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isSelected
                                          ? const Color(0xFFC59A27)
                                          : (isDark ? const Color(0xFF1A2432) : const Color(0xFFE2E8F0)),
                                      child: Text(
                                        _getInitials(c.name),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark ? theme.colorScheme.onSurface : const Color(0xFF334155)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (c.mobile.isNotEmpty)
                                            Text(
                                              c.mobile,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: textMuted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      currency.format(c.totalPaid),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                                      ),
                                    ),
                                    Text(
                                      '${c.orderCount} order${c.orderCount == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),

                // Active filter banner (Requirement 10)
                if (_selectedCustomerMobile != null) ...[
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.14)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_alt,
                              size: 18,
                              color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFB45309),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Showing payment history for: ${_selectedCustomerMobile!}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFB45309),
                              ),
                              onPressed: () => setState(() => _selectedCustomerMobile = null),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Method and Metal Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All Modes', null, _selectedMethod, (val) {
                        setState(() => _selectedMethod = val);
                      }),
                      const SizedBox(width: 6),
                      _filterChip('UPI', 'upi', _selectedMethod, (val) {
                        setState(() => _selectedMethod = val);
                      }),
                      const SizedBox(width: 6),
                      _filterChip('Cards', 'card', _selectedMethod, (val) {
                        setState(() => _selectedMethod = val);
                      }),
                      const SizedBox(width: 6),
                      _filterChip('Net Banking', 'netbanking', _selectedMethod, (val) {
                        setState(() => _selectedMethod = val);
                      }),
                      const SizedBox(width: 6),
                      _filterChip('Wallet', 'wallet', _selectedMethod, (val) {
                        setState(() => _selectedMethod = val);
                      }),
                      const SizedBox(width: 12),
                      Container(
                        height: 20,
                        width: 1,
                        color: Theme.of(context).dividerColor,
                      ),
                      const SizedBox(width: 12),
                      _filterChip('All Metals', null, _selectedMetal, (val) {
                        setState(() => _selectedMetal = val);
                      }),
                      const SizedBox(width: 6),
                      _filterChip('Gold', 'gold', _selectedMetal, (val) {
                        setState(() => _selectedMetal = val);
                      }),
                      const SizedBox(width: 6),
                      _filterChip('Silver', 'silver', _selectedMetal, (val) {
                        setState(() => _selectedMetal = val);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Transactions Count Title
                Text(
                  'Payment Records (${filteredItems.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.onSurface
                        : const Color(0xFF1E1B18),
                  ),
                ),
                const SizedBox(height: 8),

                // Transactions List
                if (filteredItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No matching payments',
                      subtitle: 'Try adjusting your search or customer filter.',
                    ),
                  )
                else
                  ...filteredItems.map((row) {
                    final theme = Theme.of(context);
                    final isDark = theme.brightness == Brightness.dark;
                    final textPrimary = isDark ? theme.colorScheme.onSurface : const Color(0xFF1E1B18);
                    final textMuted = isDark
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
                        : const Color(0xFF64748B);
                    final cardBorder = isDark ? theme.dividerColor : const Color(0xFFE2E8F0);

                    final gross = _num(row['gross_amount_inr'] ?? row['amount_inr']);
                    final gst = _num(row['gst_amount_inr']);
                    final fee = _num(row['razorpay_fee_inr']);
                    final merchant = _num(row['merchant_settlement_inr']);
                    final grams = _num(row['grams']);
                    final paidAt = DateTime.tryParse(
                      row['paid_at'] as String? ?? row['created_at'] as String? ?? '',
                    );
                    final rawName = (row['user_name'] as String?)?.trim() ??
                        (row['customer_name'] as String?)?.trim();
                    final mobile = (row['user_mobile'] as String?)?.trim() ??
                        (row['customer_mobile'] as String?)?.trim() ??
                        '';
                    final subtitle = mobile.isNotEmpty
                        ? mobile
                        : ((row['user_email'] as String?)?.trim() ?? '');
                    final customerName = _resolveDisplayName(rawName, mobile);
                    final metal = (row['metal'] as String? ?? 'gold').toLowerCase();
                    final isGold = metal == 'gold';
                    final method = (row['payment_method'] as String? ?? 'ONLINE').toUpperCase();
                    final paymentId = row['razorpay_payment_id'] as String? ?? row['id'] as String? ?? '';
                    final rrn = row['bank_rrn'] as String?;
                    final status = (row['status'] as String? ?? 'paid').toUpperCase();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: cardBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          final targetId = row['id'] ??
                              row['razorpay_order_id'] ??
                              row['razorpay_payment_id'];
                          if (targetId != null && targetId.toString().isNotEmpty) {
                            openWalletTransactionDetail(context, targetId.toString());
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            // Header row: Customer name & Metal badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isDark
                                      ? const Color(0xFFD4AF37).withValues(alpha: 0.18)
                                      : const Color(0xFFFEF3C7),
                                  child: Text(
                                    _getInitials(customerName),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? const Color(0xFFD4AF37) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customerName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: textPrimary,
                                        ),
                                      ),
                                      if (subtitle.isNotEmpty)
                                        Text(
                                          subtitle,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: textMuted,
                                          ),
                                        ),
                                      if (paidAt != null)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFFD4AF37).withValues(alpha: 0.14)
                                                : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.schedule,
                                                size: 13,
                                                color: isDark
                                                    ? const Color(0xFFD4AF37)
                                                    : const Color(0xFFB45309),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                dateFormat.format(paidAt.toLocal()),
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? const Color(0xFFFDE68A)
                                                      : const Color(0xFF92400E),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isGold
                                        ? (isDark
                                            ? const Color(0xFFD4AF37).withValues(alpha: 0.16)
                                            : const Color(0xFFFEF9C3))
                                        : (isDark
                                            ? const Color(0xFF94A3B8).withValues(alpha: 0.18)
                                            : const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isGold
                                          ? (isDark
                                              ? const Color(0xFFD4AF37).withValues(alpha: 0.45)
                                              : const Color(0xFFFACC15))
                                          : (isDark
                                              ? const Color(0xFF94A3B8).withValues(alpha: 0.4)
                                              : const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${grams.toStringAsFixed(4)} g',
                                        style: TextStyle(
                                          color: isGold
                                              ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF854D0E))
                                              : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        isGold ? 'Gold Bought' : 'Silver Bought',
                                        style: TextStyle(
                                          color: isGold
                                              ? (isDark ? const Color(0xFFD4AF37) : const Color(0xFF854D0E))
                                              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Amount & Status row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Customer Paid',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      currency.format(gross),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                                            : const Color(0xFFE0E7FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        method,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? const Color(0xFFA5B4FC)
                                              : const Color(0xFF3730A3),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                            : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFF166534),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Settlement details
                            _settlementRow('GST (3% Internal)', currency.format(gst)),
                            _settlementRow('Razorpay Fee', currency.format(fee)),
                            _settlementRow(
                              'Merchant Receives',
                              currency.format(merchant),
                              bold: true,
                              valueColor: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                            ),

                            // Metadata & references
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                if (paymentId.isNotEmpty)
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: paymentId));
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Payment ID copied'),
                                          duration: Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Payment ID: $paymentId',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: textMuted,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.copy_rounded,
                                            size: 13,
                                            color: isDark
                                                ? const Color(0xFFD4AF37)
                                                : const Color(0xFFC59A27),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (rrn != null && rrn.isNotEmpty)
                                  Text(
                                    'Bank RRN: $rrn',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip(
    String label,
    String? value,
    String? selectedValue,
    ValueChanged<String?> onSelected,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = selectedValue == value;
    final selectedBg = isDark
        ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
        : const Color(0xFFFEF3C7);
    final selectedFg = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
    final unselectedFg = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF475569);
    final borderColor = isSelected
        ? (isDark ? const Color(0xFFD4AF37) : const Color(0xFFC59A27))
        : (isDark ? theme.dividerColor : const Color(0xFFE2E8F0));

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: selectedBg,
      backgroundColor: isDark ? theme.cardColor : null,
      checkmarkColor: selectedFg,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? selectedFg : unselectedFg,
      ),
      side: BorderSide(color: borderColor),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _settlementRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
        : const Color(0xFF64748B);
    final defaultValueColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.9)
        : const Color(0xFF334155);

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: labelColor,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? defaultValueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSummary {
  final String key;
  String name;
  String? rawName;
  final String mobile;
  final String email;
  double totalPaid;
  int orderCount;

  _CustomerSummary({
    required this.key,
    required this.name,
    this.rawName,
    required this.mobile,
    required this.email,
    required this.totalPaid,
    required this.orderCount,
  });
}
