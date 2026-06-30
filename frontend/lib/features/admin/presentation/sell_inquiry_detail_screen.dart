import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/presentation/providers/sell_inquiries_provider.dart';
import 'package:ags_gold/features/user_dashboard/domain/sell_gold_inquiry.dart';
import 'package:ags_gold/services/api_client.dart';

class SellInquiryDetailScreen extends ConsumerStatefulWidget {
  final String inquiryId;

  const SellInquiryDetailScreen({super.key, required this.inquiryId});

  @override
  ConsumerState<SellInquiryDetailScreen> createState() =>
      _SellInquiryDetailScreenState();
}

class _SellInquiryDetailScreenState
    extends ConsumerState<SellInquiryDetailScreen> {
  bool _actionLoading = false;

  Future<void> _approve(SellInquiryDetail detail) async {
    final payout = detail.payout;
    if (payout == null) return;

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final destination = detail.userPaymentDestination ?? 'Not linked';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve RazorpayX payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pay ${currency.format(payout.netPayableInr)} via RazorpayX to the customer\'s linked bank account.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Bank account:',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(destination),
            const SizedBox(height: 8),
            const Text(
              'Gold will be debited and RazorpayX will initiate the bank transfer.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve payment'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      await ref.read(approveSellInquiryProvider)(inquiryId: widget.inquiryId);
      ref.invalidate(sellInquiryDetailProvider(widget.inquiryId));
      ref.invalidate(sellInquiriesListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sell request approved')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject sell request'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Rejection reason',
              alignLabelWithHint: true,
            ),
            minLines: 3,
            maxLines: 5,
            validator: (v) =>
                v == null || v.trim().length < 5 ? 'Min 5 characters' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (reason == null || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      await ref.read(rejectSellInquiryProvider)(
        inquiryId: widget.inquiryId,
        rejectionReason: reason,
      );
      ref.invalidate(sellInquiryDetailProvider(widget.inquiryId));
      ref.invalidate(sellInquiriesListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sell request rejected')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _requestInfo() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request more information'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Message to customer',
              alignLabelWithHint: true,
            ),
            minLines: 3,
            maxLines: 5,
            validator: (v) =>
                v == null || v.trim().length < 5 ? 'Min 5 characters' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (message == null || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      await ref.read(respondSellInquiryProvider)(
        inquiryId: widget.inquiryId,
        adminResponse: message,
      );
      ref.invalidate(sellInquiryDetailProvider(widget.inquiryId));
      ref.invalidate(sellInquiriesListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Information request sent')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(sellInquiryDetailProvider(widget.inquiryId));
    final isWide = ResponsiveLayout.isTablet(context) ||
        ResponsiveLayout.isDesktop(context);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final gramFormat = NumberFormat('#,##0.####');

    return ResponsiveNavigationWrapper(
      title: 'Sell inquiry',
      child: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeleton(height: 400),
        ),
        error: (e, _) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Failed to load inquiry',
          subtitle: '$e',
          actionLabel: 'Back',
          onAction: () => context.go('/admin/sell-inquiries'),
        ),
        data: (detail) {
          final canAct = detail.status == 'pending' || detail.status == 'needs_info';
          final content = [
            if (detail.schemeWarning != null)
              Card(
                color: Colors.orange.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(child: Text(detail.schemeWarning!)),
                    ],
                  ),
                ),
              ),
            _sectionCard(
              'Customer details',
              [
                _row('Name', detail.name),
                _row('Mobile', detail.mobileNumber),
                if (detail.userEmail != null) _row('Email', detail.userEmail!),
                _row('Aadhaar', _mask(detail.kycAadhaarLast4, 4)),
                _row('PAN', _mask(detail.kycPanLast4, 4)),
                _row('KYC status', detail.kycStatus ?? '—'),
              ],
            ),
            _sectionCard(
              'Wallet details',
              [
                _row(
                  'Gold balance',
                  '${gramFormat.format(detail.goldBalanceGrams ?? 0)} g',
                ),
                _row(
                  'Silver balance',
                  '${gramFormat.format(detail.silverBalanceGrams)} g',
                ),
                _row(
                  'Total gold purchased',
                  currency.format(detail.goldInvestedInr),
                ),
                _row(
                  'Remaining gold',
                  '${gramFormat.format(detail.goldBalanceGrams ?? 0)} g',
                ),
              ],
            ),
            _sectionCard(
              'Savings scheme',
              [
                _row('Scheme status', detail.goldSchemeStatus ?? '—'),
                if (detail.goldSchemeTargetGrams != null)
                  _row(
                    'Target',
                    '${gramFormat.format(detail.goldSchemeTargetGrams)} g',
                  ),
                if (detail.goldSchemeStartedAt != null)
                  _row(
                    'Start date',
                    dateFormat.format(detail.goldSchemeStartedAt!.toLocal()),
                  ),
                _row(
                  'Scheme completed',
                  detail.schemeCompleted ? 'YES' : 'NO',
                ),
              ],
            ),
            _sectionCard(
              'Inquiry details',
              [
                _row(
                  'Quantity requested',
                  '${gramFormat.format(detail.quantityGrams ?? 0)} g',
                ),
                _row('User notes', detail.message),
                _row('Submitted', dateFormat.format(detail.createdAt.toLocal())),
                _row('Status', detail.status.toUpperCase()),
              ],
            ),
            if (detail.payout != null) _payoutCard(detail.payout!, currency),
            _sectionCard(
              'Payout destination',
              [
                if (detail.userPaymentDestination != null)
                  _row('Bank account', detail.userPaymentDestination!)
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No bank account linked. The customer must add a bank account in the app before you can approve and pay via RazorpayX.',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (detail.razorpayPayoutId != null)
              _sectionCard('RazorpayX payout', [
                _row('Payout ID', detail.razorpayPayoutId!),
                _row('Status', detail.payoutStatus ?? '—'),
                if (detail.payoutFailureReason != null)
                  _row('Failure', detail.payoutFailureReason!),
              ]),
          ];

          return Padding(
            padding: EdgeInsets.all(isWide ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/admin/sell-inquiries'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        detail.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go(
                        '/transactions?user=${Uri.encodeComponent(detail.name)}',
                      ),
                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                      label: const Text('Wallet activity'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      ...content.map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: w,
                          )),
                      if (canAct) _actionBar(detail),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actionBar(SellInquiryDetail detail) {
    final missingBank = detail.userPaymentDestination == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (missingBank)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Approve is disabled until the customer links a bank account.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _actionLoading || missingBank
                  ? null
                  : () => _approve(detail),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Approve'),
            ),
            OutlinedButton.icon(
              onPressed: _actionLoading ? null : _reject,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Reject'),
            ),
            OutlinedButton.icon(
              onPressed: _actionLoading ? null : _requestInfo,
              icon: const Icon(Icons.info_outline),
              label: const Text('Request more information'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard(String title, List<Widget> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _payoutCard(SellPayoutBreakdown payout, NumberFormat currency) {
    return Card(
      color: AppTheme.emerald.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Automatic payout calculation',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _row('Current rate', '${currency.format(payout.sellRatePerGram)}/g'),
            _row('Quantity', '${payout.quantityGrams} g'),
            _row('Gross amount', currency.format(payout.grossAmountInr)),
            _row(
              'Platform charges',
              currency.format(payout.platformChargeInr),
            ),
            _row('Tax', currency.format(payout.taxAmountInr)),
            const Divider(),
            _row(
              'Final payable amount',
              currency.format(payout.netPayableInr),
            ),
          ],
        ),
      ),
    );
  }

  String _mask(String? last4, int length) {
    if (last4 == null || last4.isEmpty) return '—';
    return '${'X' * length}$last4';
  }
}
