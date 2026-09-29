import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/executive_dashboard_provider.dart';

/// Admin Executive Dashboard matching the AURA design system.
/// Focuses on:
/// 1. What Customers Have Paid FIRST (customer name, mobile, email, total ₹ paid,
///    gold/silver grams, payment modes used).
/// 2. User Payments list (who paid, how much, which mode, with customer details).
/// 3. Payment Methods Breakdown (UPI, Cards, Net Banking, Wallets) with interactive filtering.
/// 4. 2x2 KPI metrics (Total Customers, Gold Sold, Silver Sold, Total Collections).
/// NOTE: Daily revenue graph (Today's Overview) removed per requirement.
class AdminExecutiveView extends ConsumerStatefulWidget {
  final ExecutiveDashboard data;

  const AdminExecutiveView({super.key, required this.data});

  static String formatGrams(double grams) {
    final kg = grams / 1000;
    if (kg >= 1) {
      return '${NumberFormat('#,##0.##').format(kg)} KG';
    }
    if (grams > 0 && grams < 0.01) {
      // Sub-centigram holdings (e.g. ₹1 ≈ 0.0001 g) — don't round to "0 g".
      return '${NumberFormat('0.0000').format(grams)} g';
    }
    return '${NumberFormat('#,##0.##').format(grams)} g';
  }

  @override
  ConsumerState<AdminExecutiveView> createState() => _AdminExecutiveViewState();
}

class _AdminExecutiveViewState extends ConsumerState<AdminExecutiveView> {
  String? _selectedPaymentMethod; // 'upi', 'card', 'netbanking', 'wallet'
  String? _selectedCustomerFilter; // mobile
  String _customerSearch = '';
  String _transactionFilter = 'all'; // 'all', 'upi', 'card', 'netbanking', 'success'

  ExecutiveDashboard get data => widget.data;

  @override
  Widget build(BuildContext context) {
    // Calculate Gold & Silver sold and revenue from paymentSummary, customer summaries or recent payments
    double totalGoldSold = data.paymentSummary?.goldSoldGrams ?? 0.0;
    double totalSilverSold = data.paymentSummary?.silverSoldGrams ?? 0.0;
    double goldRevenue = data.paymentSummary?.goldSoldRevenue ?? 0.0;
    double silverRevenue = data.paymentSummary?.silverSoldRevenue ?? 0.0;

    // Fallback if paymentSummary doesn't have breakdown: compute from customer summaries or recent payments
    if (totalGoldSold == 0.0 && totalSilverSold == 0.0) {
      for (final c in data.customerSummaries) {
        totalGoldSold += c.goldGrams;
        totalSilverSold += c.silverGrams;
      }
    }
    if (totalGoldSold == 0.0 && totalSilverSold == 0.0) {
      for (final p in data.recentPayments) {
        if ((p.status == 'captured' || p.status == 'paid')) {
          if (p.metal.toLowerCase() == 'silver') {
            totalSilverSold += p.grams;
            silverRevenue += p.amountInr;
          } else {
            totalGoldSold += p.grams;
            goldRevenue += p.amountInr;
          }
        }
      }
    }

    final totalRevenue = data.paymentSummary?.totalCapturedRevenue ??
        (goldRevenue + silverRevenue > 0
            ? (goldRevenue + silverRevenue)
            : (data.appMetrics?.totalRevenue ?? 0.0));

    // Accurate Customers count: prioritize paying customers and active members
    int customersCount = data.paymentSummary?.payingCustomersCount ?? 0;
    if (customersCount == 0 && data.customerSummaries.isNotEmpty) {
      customersCount = data.customerSummaries.length;
    }
    if ((data.customerMetrics?.totalCustomers ?? 0) > customersCount) {
      customersCount = data.customerMetrics!.totalCustomers;
    }
    if ((data.appMetrics?.memberCount ?? 0) > customersCount) {
      customersCount = data.appMetrics!.memberCount;
    }
    final totalCustomers = customersCount;
    final payingCustomers = data.paymentSummary?.payingCustomersCount ?? data.customerSummaries.length;

    // Payment methods aggregated stats
    final methodStats = _computeMethodStats(data.recentPayments, data.paymentSummary);

    // Filter customer summaries
    final filteredCustomers = data.customerSummaries.where((c) {
      if (_customerSearch.isNotEmpty) {
        final q = _customerSearch.toLowerCase();
        final matchName = (c.name ?? '').toLowerCase().contains(q);
        final matchPhone = c.mobile.toLowerCase().contains(q);
        final matchEmail = (c.email ?? '').toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchEmail) return false;
      }
      if (_selectedPaymentMethod != null) {
        final hasMethod = c.paymentMethods.any((m) =>
            _normalizeMethod(m) == _selectedPaymentMethod);
        if (!hasMethod) return false;
      }
      return true;
    }).toList();

    // Filter recent transactions
    final filteredPayments = data.recentPayments.where((p) {
      if (_selectedCustomerFilter != null) {
        final contact = p.customerMobile ?? p.customerEmail ?? '';
        if (!contact.contains(_selectedCustomerFilter!)) return false;
      }
      if (_selectedPaymentMethod != null) {
        if (_normalizeMethod(p.paymentMethod) != _selectedPaymentMethod) {
          return false;
        }
      }
      if (_transactionFilter != 'all') {
        if (_transactionFilter == 'success') {
          if (p.status != 'captured' && p.status != 'paid') return false;
        } else {
          if (_normalizeMethod(p.paymentMethod) != _transactionFilter) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    final isSyncing = ref.watch(razorpaySyncProvider).isLoading;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Welcome Header with Live Sync & Notifications
          _AdminHeader(
            displayName: data.displayName,
            lastSyncedAt: data.paymentSummary?.lastSyncedAt ?? data.refreshedAt,
            isSyncing: isSyncing,
            unreadCount: data.unreadNotifications,
            onSync: () async {
              try {
                final result =
                    await ref.read(razorpaySyncProvider.notifier).syncNow();
                if (context.mounted) {
                  final captured = result?['captured_count'] ?? 0;
                  final rev = result?['total_revenue'] ?? 0;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Live Razorpay Synced: ₹$rev ($captured successful orders)',
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF1E1B18),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sync error: $e'),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 18),

          // 2. FIRST: What Customers Have Paid — who paid, how much, which mode,
          // with customer name + mobile + email + metal details.
          _PayingCustomersSection(
            customers: filteredCustomers,
            selectedCustomerMobile: _selectedCustomerFilter,
            searchQuery: _customerSearch,
            onSearchChanged: (val) => setState(() => _customerSearch = val),
            onSelectCustomer: (mobile) {
              setState(() {
                if (_selectedCustomerFilter == mobile) {
                  _selectedCustomerFilter = null;
                } else {
                  _selectedCustomerFilter = mobile;
                }
              });
            },
            onClearCustomerFilter: () =>
                setState(() => _selectedCustomerFilter = null),
          ),
          const SizedBox(height: 22),

          // 3. User Payments — each payment shows customer name, amount, mode.
          _RecentTransactionsSection(
            payments: filteredPayments,
            activeFilter: _transactionFilter,
            selectedCustomerFilter: _selectedCustomerFilter,
            selectedMethodFilter: _selectedPaymentMethod,
            onFilterChanged: (filter) => setState(() => _transactionFilter = filter),
            onClearCustomerFilter: () =>
                setState(() => _selectedCustomerFilter = null),
            onViewAll: () => context.go('/admin/payment-settlements'),
          ),
          const SizedBox(height: 22),

          // 4. Payment Methods Breakdown
          _PaymentMethodsSection(
            methodStats: methodStats,
            selectedMethod: _selectedPaymentMethod,
            totalOrders: data.paymentSummary?.totalCapturedCount ?? data.recentPayments.length,
            onSelectMethod: (method) {
              setState(() {
                if (_selectedPaymentMethod == method) {
                  _selectedPaymentMethod = null;
                } else {
                  _selectedPaymentMethod = method;
                }
              });
            },
            onClearFilter: () => setState(() => _selectedPaymentMethod = null),
          ),
          const SizedBox(height: 22),

          // 5. 2x2 Metric Cards Grid (Total Customers, Gold Sold, Silver Sold, Total Collections)
          _KpiMetricGrid(
            totalCustomers: totalCustomers,
            payingCustomersCount: payingCustomers,
            goldSoldGrams: totalGoldSold,
            goldSoldRevenue: goldRevenue,
            silverSoldGrams: totalSilverSold,
            silverSoldRevenue: silverRevenue,
            totalCollectionsInr: totalRevenue,
          ),
          const SizedBox(height: 24),

          // 6. Quick Admin Hub Navigation
          const _AdminQuickHub(),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  static String _normalizeMethod(String? raw) {
    if (raw == null) return 'other';
    final s = raw.toLowerCase();
    if (s.contains('upi') || s.contains('gpay') || s.contains('phonepe') || s.contains('paytm')) {
      return 'upi';
    }
    if (s.contains('card') || s.contains('credit') || s.contains('debit') || s.contains('visa') || s.contains('mastercard')) {
      return 'card';
    }
    if (s.contains('netbanking') || s.contains('net_banking') || s.contains('bank')) {
      return 'netbanking';
    }
    if (s.contains('wallet')) {
      return 'wallet';
    }
    return 'other';
  }

  static Map<String, _MethodData> _computeMethodStats(
    List<AdminPaymentItem> payments,
    AdminPaymentSummary? summary,
  ) {
    final stats = <String, _MethodData>{
      'upi': _MethodData(
        key: 'upi',
        title: 'UPI',
        subtitle: 'Google Pay, PhonePe, Paytm, BHIM',
        icon: Icons.qr_code_2_rounded,
        color: const Color(0xFFC59A27),
      ),
      'card': _MethodData(
        key: 'card',
        title: 'Cards',
        subtitle: 'Visa, Mastercard, RuPay Cards',
        icon: Icons.credit_card_rounded,
        color: const Color(0xFF0D9488),
      ),
      'netbanking': _MethodData(
        key: 'netbanking',
        title: 'Net Banking',
        subtitle: 'HDFC, ICICI, SBI, Axis & all banks',
        icon: Icons.account_balance_rounded,
        color: const Color(0xFFEA580C),
      ),
      'wallet': _MethodData(
        key: 'wallet',
        title: 'Wallets & Other',
        subtitle: 'Paytm, Amazon Pay, EMI, Others',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF7C3AED),
      ),
    };

    // Calculate from payments
    for (final p in payments) {
      if (p.status == 'captured' || p.status == 'paid') {
        final key = _normalizeMethod(p.paymentMethod);
        final target = stats[key] ?? stats['wallet']!;
        target.count += 1;
        target.amount += p.amountInr;
      }
    }

    // Blend breakdown counts from summary if available
    if (summary != null && summary.paymentMethodsBreakdown.isNotEmpty) {
      for (final entry in summary.paymentMethodsBreakdown.entries) {
        final key = _normalizeMethod(entry.key);
        final target = stats[key] ?? stats['wallet']!;
        if (target.count < entry.value) {
          target.count = entry.value;
        }
      }
    }

    // Calculate total amount for percentage
    final totalAmt = stats.values.fold<double>(0.0, (acc, item) => acc + item.amount);
    final totalCount = stats.values.fold<int>(0, (acc, item) => acc + item.count);

    for (final item in stats.values) {
      if (totalAmt > 0) {
        item.percent = (item.amount / totalAmt) * 100;
      } else if (totalCount > 0) {
        item.percent = (item.count / totalCount) * 100;
      }
    }

    return stats;
  }
}

class _MethodData {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  int count = 0;
  double amount = 0.0;
  double percent = 0.0;

  _MethodData({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

// -----------------------------------------------------------------------------
// 1. Welcome Header
// -----------------------------------------------------------------------------
class _AdminHeader extends StatelessWidget {
  final String? displayName;
  final DateTime lastSyncedAt;
  final bool isSyncing;
  final int unreadCount;
  final VoidCallback onSync;

  const _AdminHeader({
    this.displayName,
    required this.lastSyncedAt,
    required this.isSyncing,
    required this.unreadCount,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(lastSyncedAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFAA7C11)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFF1E1B18),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName != null && displayName!.isNotEmpty
                      ? 'Welcome, $displayName'
                      : 'Welcome Admin',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1B18),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Here's what's happening today",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E1B18).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          // Live Sync button
          Tooltip(
            message: 'Sync Razorpay Live ($timeStr)',
            child: InkWell(
              onTap: isSyncing ? null : onSync,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDE8DF)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSyncing)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFC59A27),
                        ),
                      )
                    else
                      const Icon(
                        Icons.sync_rounded,
                        size: 16,
                        color: Color(0xFFC59A27),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      isSyncing ? 'Syncing...' : 'Razorpay Live Sync',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1B18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. 2x2 Metric Cards Grid
// -----------------------------------------------------------------------------
class _KpiMetricGrid extends StatelessWidget {
  final int totalCustomers;
  final int payingCustomersCount;
  final double goldSoldGrams;
  final double goldSoldRevenue;
  final double silverSoldGrams;
  final double silverSoldRevenue;
  final double totalCollectionsInr;

  const _KpiMetricGrid({
    required this.totalCustomers,
    required this.payingCustomersCount,
    required this.goldSoldGrams,
    required this.goldSoldRevenue,
    required this.silverSoldGrams,
    required this.silverSoldRevenue,
    required this.totalCollectionsInr,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final countFmt = NumberFormat.decimalPattern();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Total Customers',
                value: countFmt.format(totalCustomers),
                subtitle: payingCustomersCount > 0 ? '$payingCustomersCount paying' : 'Active users',
                badgeText: '+12%',
                icon: Icons.people_alt_rounded,
                iconBg: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFC59A27),
                onTap: () => context.go('/customers'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Gold Sold',
                value: AdminExecutiveView.formatGrams(goldSoldGrams),
                subtitle: 'Rev: ${currency.format(goldSoldRevenue)}',
                badgeText: '+8%',
                icon: Icons.workspace_premium_rounded,
                iconBg: const Color(0xFFFFFBEB),
                iconColor: const Color(0xFFD4AF37),
                onTap: () => context.go('/inventory'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Silver Sold',
                value: AdminExecutiveView.formatGrams(silverSoldGrams),
                subtitle: 'Rev: ${currency.format(silverSoldRevenue)}',
                badgeText: '+10%',
                icon: Icons.toll_rounded,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF64748B),
                onTap: () => context.go('/inventory'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Total Collections',
                value: currency.format(totalCollectionsInr),
                subtitle: 'Total revenue',
                badgeText: '+15%',
                icon: Icons.currency_rupee_rounded,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF059669),
                onTap: () => context.go('/admin/payment-settlements'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final String badgeText;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDE8DF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        color: Color(0xFF166534),
                        size: 11,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1B18),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E1B18).withValues(alpha: 0.6),
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC59A27),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// Daily revenue graph removed per requirement (Todays Overview deleted).
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// 4. Payment Methods Breakdown (CRITICAL USER REQUIREMENT)
// -----------------------------------------------------------------------------
class _PaymentMethodsSection extends StatelessWidget {
  final Map<String, _MethodData> methodStats;
  final String? selectedMethod;
  final int totalOrders;
  final ValueChanged<String> onSelectMethod;
  final VoidCallback onClearFilter;

  const _PaymentMethodsSection({
    required this.methodStats,
    required this.selectedMethod,
    required this.totalOrders,
    required this.onSelectMethod,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE8DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  size: 18,
                  color: Color(0xFFC59A27),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Methods',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1B18),
                      ),
                    ),
                    Text(
                      'Live breakdown of customer payment channels',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7E7A75),
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedMethod != null)
                TextButton.icon(
                  onPressed: onClearFilter,
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Clear', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Proportional Multi-Segment Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: methodStats.values.map((item) {
                  final flex = (item.percent.clamp(2.0, 100.0) * 10).toInt();
                  return Expanded(
                    flex: flex > 0 ? flex : 1,
                    child: Container(color: item.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2x2 Grid of Payment Methods
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MethodCard(
                      data: methodStats['upi']!,
                      currency: currency,
                      isSelected: selectedMethod == 'upi',
                      onTap: () => onSelectMethod('upi'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MethodCard(
                      data: methodStats['card']!,
                      currency: currency,
                      isSelected: selectedMethod == 'card',
                      onTap: () => onSelectMethod('card'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MethodCard(
                      data: methodStats['netbanking']!,
                      currency: currency,
                      isSelected: selectedMethod == 'netbanking',
                      onTap: () => onSelectMethod('netbanking'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MethodCard(
                      data: methodStats['wallet']!,
                      currency: currency,
                      isSelected: selectedMethod == 'wallet',
                      onTap: () => onSelectMethod('wallet'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (selectedMethod != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_rounded, size: 14, color: Color(0xFF92400E)),
                  const SizedBox(width: 6),
                  Text(
                    'Filtering lists by: ${methodStats[selectedMethod]?.title ?? selectedMethod}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClearFilter,
                    child: const Text(
                      'Show All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final _MethodData data;
  final NumberFormat currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.data,
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFFAF8F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFC59A27) : const Color(0xFFEDE8DF),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(data.icon, size: 16, color: data.color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF9A7210) : const Color(0xFF1E1B18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              currency.format(data.amount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1B18),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${data.count} orders',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E1B18).withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${data.percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: data.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. What Customers Have Paid (CRITICAL USER REQUIREMENT)
// -----------------------------------------------------------------------------
class _PayingCustomersSection extends StatelessWidget {
  final List<CustomerPaymentSummary> customers;
  final String? selectedCustomerMobile;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelectCustomer;
  final VoidCallback onClearCustomerFilter;

  const _PayingCustomersSection({
    required this.customers,
    required this.selectedCustomerMobile,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSelectCustomer,
    required this.onClearCustomerFilter,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE8DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_circle_rounded,
                  size: 18,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Payments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1B18),
                      ),
                    ),
                    Text(
                      'Who paid • How much • Which mode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7E7A75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${customers.length} users',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1B18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search customer name or mobile...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: const Color(0xFF1E1B18).withValues(alpha: 0.4),
              ),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF7E7A75)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFFAF8F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEDE8DF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEDE8DF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC59A27)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Customer Cards List
          if (customers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                'No paying customers match this filter',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF1E1B18).withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: customers.take(10).length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final c = customers[index];
                final isSelected = selectedCustomerMobile == c.mobile;

                return _CustomerPaidCard(
                  customer: c,
                  currency: currency,
                  isSelected: isSelected,
                  onTap: () => onSelectCustomer(c.mobile),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CustomerPaidCard extends StatelessWidget {
  final CustomerPaymentSummary customer;
  final NumberFormat currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomerPaidCard({
    required this.customer,
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(customer.name ?? customer.mobile);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFFAF8F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFC59A27) : const Color(0xFFEDE8DF),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + Total Amount Paid
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3E8FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7E22CE),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name?.isNotEmpty == true
                            ? customer.name!
                            : 'Customer ${customer.mobile}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1B18),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 11, color: Color(0xFF7E7A75)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.mobile,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E1B18).withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (customer.email?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 11, color: Color(0xFF7E7A75)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                customer.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: const Color(0xFF1E1B18).withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.payment_rounded, size: 11, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.paymentMethods.isNotEmpty
                                  ? 'Paid via: ${customer.paymentMethods.map((m) => m.toUpperCase()).join(" • ")}'
                                  : 'Paid via: —',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(customer.totalPaidInr),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${customer.successCount} orders paid',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E1B18).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Metal Breakdown & Payment Types Used
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Gold Grams Chip
                if (customer.goldGrams > 0)
                  _buildTag(
                    icon: Icons.workspace_premium_rounded,
                    label: '${AdminExecutiveView.formatGrams(customer.goldGrams)} Gold',
                    color: const Color(0xFFC59A27),
                    bg: const Color(0xFFFFFBEB),
                  ),
                // Silver Grams Chip
                if (customer.silverGrams > 0)
                  _buildTag(
                    icon: Icons.toll_rounded,
                    label: '${AdminExecutiveView.formatGrams(customer.silverGrams)} Silver',
                    color: const Color(0xFF64748B),
                    bg: const Color(0xFFF1F5F9),
                  ),
                // Payment Method Badges
                ...customer.paymentMethods.map((m) {
                  final (label, icon, color, bg) = _methodBadgeInfo(m);
                  return _buildTag(
                    icon: icon,
                    label: label,
                    color: color,
                    bg: bg,
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static (String, IconData, Color, Color) _methodBadgeInfo(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('upi')) {
      return ('UPI', Icons.qr_code_2_rounded, const Color(0xFFB45309), const Color(0xFFFEF3C7));
    }
    if (s.contains('card')) {
      return ('Card', Icons.credit_card_rounded, const Color(0xFF0F766E), const Color(0xFFCCFBF1));
    }
    if (s.contains('netbanking')) {
      return ('NetBanking', Icons.account_balance_rounded, const Color(0xFFC2410C), const Color(0xFFFFEDD5));
    }
    return ('Wallet', Icons.account_balance_wallet_rounded, const Color(0xFF6D28D9), const Color(0xFFEDE9FE));
  }

  static Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _getInitials(String str) {
    final trimmed = str.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// -----------------------------------------------------------------------------
// 6. Recent Transactions Section
// -----------------------------------------------------------------------------
class _RecentTransactionsSection extends StatelessWidget {
  final List<AdminPaymentItem> payments;
  final String activeFilter;
  final String? selectedCustomerFilter;
  final String? selectedMethodFilter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onClearCustomerFilter;
  final VoidCallback onViewAll;

  const _RecentTransactionsSection({
    required this.payments,
    required this.activeFilter,
    required this.selectedCustomerFilter,
    required this.selectedMethodFilter,
    required this.onFilterChanged,
    required this.onClearCustomerFilter,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE8DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + "View All" Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'User Payments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B18),
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC59A27),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter Pills: All, UPI, Card, Net Banking, Success
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterPill('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterPill('UPI', 'upi'),
                const SizedBox(width: 8),
                _buildFilterPill('Cards', 'card'),
                const SizedBox(width: 8),
                _buildFilterPill('Net Banking', 'netbanking'),
                const SizedBox(width: 8),
                _buildFilterPill('Success', 'success'),
              ],
            ),
          ),
          if (selectedCustomerFilter != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtered by: $selectedCustomerFilter',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClearCustomerFilter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Clear Filter',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Transactions List
          if (payments.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                'No transactions found',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF1E1B18).withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.take(8).length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final p = payments[index];
                return _TransactionItemTile(
                  payment: p,
                  onTap: () => _showPaymentReceiptModal(context, p),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, String key) {
    final isSelected = activeFilter == key;
    return GestureDetector(
      onTap: () => onFilterChanged(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1B18) : const Color(0xFFFAF8F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E1B18) : const Color(0xFFEDE8DF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF706E6B),
          ),
        ),
      ),
    );
  }
}

class _TransactionItemTile extends StatelessWidget {
  final AdminPaymentItem payment;
  final VoidCallback onTap;

  const _TransactionItemTile({
    required this.payment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGold = payment.metal.toLowerCase() != 'silver';
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final dateStr = DateFormat('dd MMM, hh:mm a').format(payment.createdAt);

    final status = payment.status.toLowerCase();
    final isSuccess = status == 'captured' || status == 'paid';
    final isPending = status == 'created';

    final statusBg = isSuccess
        ? const Color(0xFFDCFCE7)
        : (isPending ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2));
    final statusColor = isSuccess
        ? const Color(0xFF166534)
        : (isPending ? const Color(0xFF92400E) : const Color(0xFF991B1B));
    final statusLabel = isSuccess ? 'Success' : (isPending ? 'Pending' : 'Failed');

    final method = (payment.paymentMethod ?? 'UPI').toUpperCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF8F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDE8DF)),
        ),
        child: Row(
          children: [
            // Metal icon square
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isGold ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isGold ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Center(
                child: Icon(
                  isGold ? Icons.workspace_premium_rounded : Icons.toll_rounded,
                  color: isGold ? const Color(0xFFD4AF37) : const Color(0xFF64748B),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Middle info: Customer + Metal details + Payment method
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.customerName?.isNotEmpty == true
                        ? payment.customerName!
                        : (payment.customerMobile?.isNotEmpty == true
                            ? 'Customer (${payment.customerMobile})'
                            : (isGold ? 'Digital Gold' : 'Digital Silver')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E1B18),
                    ),
                  ),
                  if (payment.customerName?.isNotEmpty == true &&
                      payment.customerMobile?.isNotEmpty == true) ...[
                    Text(
                      payment.customerMobile!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1E1B18).withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${payment.metal.toUpperCase()} · ${AdminExecutiveView.formatGrams(payment.grams)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E1B18).withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          method,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3730A3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: const Color(0xFF1E1B18).withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),

            // Right info: Amount + Status Pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(payment.amountInr),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1B18),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 7. Quick Admin Hub
// -----------------------------------------------------------------------------
class _AdminQuickHub extends StatelessWidget {
  const _AdminQuickHub();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE8DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Operations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1B18),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HubTile(
                  icon: Icons.people_outline_rounded,
                  label: 'Customers',
                  route: '/customers',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HubTile(
                  icon: Icons.payments_outlined,
                  label: 'Payments',
                  route: '/admin/payment-settlements',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HubTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Inventory',
                  route: '/inventory',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HubTile(
                  icon: Icons.analytics_outlined,
                  label: 'Reports',
                  route: '/reports',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _HubTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF8F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEDE8DF)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFC59A27), size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1B18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Payment Details Modal Sheet
// -----------------------------------------------------------------------------
void _showPaymentReceiptModal(BuildContext context, AdminPaymentItem item) {
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final isPaid = item.status == 'captured' || item.status == 'paid';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Details',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1B18),
                        ),
                      ),
                      Text(
                        DateFormat('dd MMMM yyyy, hh:mm a').format(item.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF1E1B18).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPaid ? 'PAID / CAPTURED' : item.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isPaid ? const Color(0xFF166534) : const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFEDE8DF)),

            // Rows of Details
            _detailRow('Customer Name', item.customerName ?? '—'),
            _detailRow('Customer Mobile', item.customerMobile ?? '—', copyable: true, context: ctx),
            if (item.customerEmail != null)
              _detailRow('Customer Email', item.customerEmail!, copyable: true, context: ctx),
            _detailRow('Payment Method', (item.paymentMethod ?? 'UPI').toUpperCase()),
            _detailRow('Metal Purchased', '${item.metal.toUpperCase()} (${AdminExecutiveView.formatGrams(item.grams)})'),
            if (item.metalValueInr != null)
              _detailRow('Metal Value (excl GST)', currency.format(item.metalValueInr!)),
            if (item.gstAmountInr != null)
              _detailRow('GST (3%)', currency.format(item.gstAmountInr!)),
            _detailRow('Total Paid Amount', currency.format(item.amountInr), bold: true, valueColor: const Color(0xFF059669)),
            if (item.merchantSettlementInr != null)
              _detailRow('Merchant Net Settlement', currency.format(item.merchantSettlementInr!)),

            const Divider(height: 20, color: Color(0xFFEDE8DF)),
            _detailRow('Razorpay Order ID', item.razorpayOrderId, copyable: true, context: ctx),
            if (item.razorpayPaymentId != null)
              _detailRow('Payment ID', item.razorpayPaymentId!, copyable: true, context: ctx),
            if (item.bankRrn != null)
              _detailRow('Bank RRN', item.bankRrn!, copyable: true, context: ctx),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1B18),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _detailRow(
  String label,
  String value, {
  bool bold = false,
  Color? valueColor,
  bool copyable = false,
  BuildContext? context,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF1E1B18).withValues(alpha: 0.6),
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (copyable && context != null)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $label: $value'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? const Color(0xFF1E1B18),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF7E7A75)),
              ],
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? const Color(0xFF1E1B18),
            ),
          ),
      ],
    ),
  );
}
