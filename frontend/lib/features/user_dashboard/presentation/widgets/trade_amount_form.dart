import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/gold_payment_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/services/razorpay_checkout.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/scheme_completion_dialog.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class TradeAmountForm extends ConsumerStatefulWidget {
  final bool isBuy;
  final MetalType metal;

  const TradeAmountForm({
    super.key,
    required this.isBuy,
    required this.metal,
  });

  @override
  ConsumerState<TradeAmountForm> createState() => _TradeAmountFormState();
}

class _TradeAmountFormState extends ConsumerState<TradeAmountForm>
    with WidgetsBindingObserver {
  final _gramsController = TextEditingController();
  final _amountController = TextEditingController();
  final _checkout = RazorpayCheckout();
  bool _syncing = false;
  bool _paying = false;
  bool _syncingPendingPayment = false;
  String? _pendingOrderId;
  GoldSchemeStatus? _schemeWasActiveBeforePayment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gramsController.dispose();
    _amountController.dispose();
    _checkout.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingOrderId != null) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted && _pendingOrderId != null) {
          _syncPendingPayment();
        }
      });
    }
  }

  void _syncFromGrams(double rate) {
    if (_syncing) return;
    _syncing = true;
    final grams = double.tryParse(_gramsController.text) ?? 0;
    final gstMultiplier = _gstMultiplier();
    _amountController.text =
        grams > 0 ? (grams * rate * gstMultiplier).toStringAsFixed(2) : '';
    _syncing = false;
  }

  void _syncFromAmount(double rate) {
    if (_syncing || rate <= 0) return;
    _syncing = true;
    final amount = double.tryParse(_amountController.text) ?? 0;
    final gstMultiplier = _gstMultiplier();
    _gramsController.text =
        amount > 0 ? (amount / gstMultiplier / rate).toStringAsFixed(4) : '';
    _syncing = false;
  }

  double _gstMultiplier() {
    // Matches backend METAL_*_GST_PERCENT (3%)
    return 1.03;
  }

  Future<void> _startPayment(double rate) async {
    if (_paying || !widget.isBuy) return;

    final grams = double.tryParse(_gramsController.text);
    final amount = double.tryParse(_amountController.text);
    if ((grams == null || grams <= 0) && (amount == null || amount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.enterValidTradeAmount)),
      );
      return;
    }

    setState(() => _paying = true);
    try {
      if (widget.isBuy && widget.metal == MetalType.gold) {
        _schemeWasActiveBeforePayment =
            ref.read(personalDashboardProvider).value?.goldScheme.status;
      }

      final order = await ref.read(goldPaymentProvider)(
        metal: widget.metal == MetalType.silver ? 'silver' : 'gold',
        grams: grams != null && grams > 0 ? grams : null,
        amountInr: amount != null && amount > 0 ? amount : null,
      );

      if (!mounted) return;

      if (order.keyId == 'dev_mock') {
        await _completeDevMockPayment(order.orderId);
        return;
      }

      _pendingOrderId = order.orderId;
      _checkout.open(
        keyId: order.keyId,
        orderId: order.orderId,
        amountPaise: order.amountPaise,
        onSuccess: (response) {
          _pendingOrderId = null;
          _onPaymentSuccess(response);
        },
        onError: (response) {
          _pendingOrderId = null;
          _onPaymentError(response.message);
        },
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        setState(() => _paying = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.paymentFailed)),
        );
        setState(() => _paying = false);
      }
    }
  }

  Future<void> _syncPendingPayment() async {
    final orderId = _pendingOrderId;
    if (orderId == null || _syncingPendingPayment) return;

    _syncingPendingPayment = true;
    if (mounted) setState(() => _paying = true);
    try {
      final result = await ref.read(syncGoldPaymentProvider)(orderId: orderId);
      if (!mounted) return;

      if (result.isPaid) {
        _pendingOrderId = null;
        await _finishSuccessfulPayment(result.message);
        return;
      }

      if (result.isPending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.paymentPending)),
        );
      } else {
        _pendingOrderId = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.paymentFailed)),
        );
      }
    } finally {
      _syncingPendingPayment = false;
      if (mounted && _pendingOrderId == null) {
        setState(() => _paying = false);
      }
    }
  }

  Future<void> _finishSuccessfulPayment(String message) async {
    await ref.read(personalDashboardProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    await _handlePostPaymentNavigation();
    if (mounted) setState(() => _paying = false);
  }

  Future<void> _completeDevMockPayment(String orderId) async {
    setState(() => _paying = true);
    try {
      final result = await ref.read(verifyGoldPaymentProvider)(
        orderId: orderId,
        paymentId: 'pay_dev_mock',
        signature: 'dev_mock',
      );
      await _finishSuccessfulPayment(result.message);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId;
    final orderId = response.orderId;
    final signature = response.signature;

    if (paymentId == null || orderId == null || signature == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.paymentFailed)),
        );
        setState(() => _paying = false);
      }
      return;
    }

    setState(() => _paying = true);
    try {
      final result = await ref.read(verifyGoldPaymentProvider)(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );
      await _finishSuccessfulPayment(result.message);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _onPaymentError(String? message) {
    if (!mounted) return;
    setState(() => _paying = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? context.l10n.paymentFailed)),
    );
  }

  Future<void> _handlePostPaymentNavigation() async {
    if (!mounted) return;

    final dashboard = ref.read(personalDashboardProvider).value;
    final scheme = dashboard?.goldScheme;
    final justCompleted = widget.isBuy &&
        widget.metal == MetalType.gold &&
        _schemeWasActiveBeforePayment == GoldSchemeStatus.active &&
        scheme?.status.isCompleted == true;

    if (justCompleted && scheme != null) {
      await handleSchemeJustCompleted(context, ref, scheme);
      return;
    }

    if (mounted) {
      context.go('/user-dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pricesAsync = ref.watch(metalPricesProvider);
    final dashboardAsync = ref.watch(personalDashboardProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    if (widget.isBuy && widget.metal == MetalType.gold) {
      return dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(
          l10n.failedToLoadDashboard('$e'),
          style: const TextStyle(color: Colors.redAccent),
        ),
        data: (dashboard) {
          if (dashboard.goldScheme.status.isNotSelected) {
            return AurumSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.goldSchemeBuyBlockedTitle,
                    style: TextStyle(
                      color: AurumConsumerTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.goldSchemeBuyBlockedBody,
                    style: TextStyle(
                      color: AurumConsumerTheme.textMuted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/user-dashboard'),
                    child: Text(l10n.back),
                  ),
                ],
              ),
            );
          }

          return pricesAsync.when(
            data: (prices) => _buildTradeForm(
              l10n: l10n,
              currency: currency,
              prices: prices,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              l10n.failedToLoadLivePrice('$e'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        },
      );
    }

    return pricesAsync.when(
      data: (prices) => _buildTradeForm(
        l10n: l10n,
        currency: currency,
        prices: prices,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(
        l10n.failedToLoadLivePrice('$e'),
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildTradeForm({
    required dynamic l10n,
    required NumberFormat currency,
    required MetalPrices prices,
  }) {
    final quote = prices.quoteFor(widget.metal);
    final rate = quote.displayPrice;
    final rateLabel = widget.isBuy
        ? l10n.buyRatePerGram(currency.format(rate))
        : l10n.sellRatePerGram(currency.format(rate));

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AurumSurfaceCard(
              child: Row(
                children: [
                  Icon(
                    widget.isBuy
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: AurumConsumerTheme.liveGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rateLabel,
                      style: TextStyle(
                        color: AurumConsumerTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Field(
              label: l10n.goldWeightGrams,
              controller: _gramsController,
              hint: '0.0000',
              onChanged: (_) => _syncFromGrams(rate),
            ),
            const SizedBox(height: 16),
            _Field(
              label: l10n.amountInr,
              controller: _amountController,
              hint: '0.00',
              onChanged: (_) => _syncFromAmount(rate),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _paying
                  ? null
                  : widget.isBuy
                      ? () => _startPayment(rate)
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.paymentComingSoon)),
                          );
                        },
              child: _paying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.continueToPayment),
            ),
          ],
        ),
        if (_paying && _pendingOrderId != null)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: AurumSurfaceCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.confirmingPayment,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AurumConsumerTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AurumConsumerTheme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: TextStyle(
            color: AurumConsumerTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(hintText: hint),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
