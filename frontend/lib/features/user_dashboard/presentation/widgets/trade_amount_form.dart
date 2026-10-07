import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/gold_payment_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/services/razorpay_checkout.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/scheme_completion_dialog.dart';
import 'package:ags_gold/core/utils/email_validator.dart';
import 'package:ags_gold/features/profile/presentation/widgets/add_email_dialog.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/features/admin/domain/metal_inventory_models.dart';
import 'package:ags_gold/features/admin/presentation/providers/admin_metal_inventory_provider.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

enum PurchaseMode { amount, grams }

class TradeAmountForm extends ConsumerStatefulWidget {
  final bool isBuy;
  final MetalType metal;
  final double? initialAmount;

  const TradeAmountForm({
    super.key,
    required this.isBuy,
    required this.metal,
    this.initialAmount,
  });

  @override
  ConsumerState<TradeAmountForm> createState() => _TradeAmountFormState();
}

class _TradeAmountFormState extends ConsumerState<TradeAmountForm>
    with WidgetsBindingObserver {
  final _gramsController = TextEditingController();
  final _amountController = TextEditingController();
  final _checkout = RazorpayCheckout();

  PurchaseMode _purchaseMode = PurchaseMode.amount;
  bool _syncing = false;
  bool _paying = false;
  bool _syncingPendingPayment = false;
  String? _pendingOrderId;
  GoldSchemeStatus? _schemeWasActiveBeforePayment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _purchaseMode = PurchaseMode.amount;
      _amountController.text = widget.initialAmount!.toStringAsFixed(0);
    }
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

  double _gstMultiplier() {
    // Matches backend METAL_*_GST_PERCENT (3%)
    return 1.03;
  }

  String _formatGramsForDisplay(double grams) {
    if (grams <= 0) return '';
    if (grams < 0.0001) {
      return grams.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '');
    }
    return grams.toStringAsFixed(4);
  }

  void _syncFromGrams(double rate) {
    if (_syncing || rate <= 0) return;
    _syncing = true;
    _purchaseMode = PurchaseMode.grams;
    final grams = double.tryParse(_gramsController.text) ?? 0;
    if (grams > 0) {
      final metalValue = grams * rate;
      final total = metalValue * _gstMultiplier();
      _amountController.text = total.toStringAsFixed(2);
    } else {
      _amountController.text = '';
    }
    _syncing = false;
    setState(() {});
  }

  void _syncFromAmount(double rate) {
    if (_syncing || rate <= 0) return;
    _syncing = true;
    _purchaseMode = PurchaseMode.amount;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount > 0) {
      final metalValue = amount / _gstMultiplier();
      final grams = metalValue / rate;
      _gramsController.text = _formatGramsForDisplay(grams);
    } else {
      _gramsController.text = '';
    }
    _syncing = false;
    setState(() {});
  }

  void _onModeChanged(PurchaseMode mode, double rate) {
    if (_purchaseMode == mode) return;
    setState(() {
      _purchaseMode = mode;
    });
    if (rate > 0) {
      if (mode == PurchaseMode.amount && _amountController.text.isNotEmpty) {
        _syncFromAmount(rate);
      } else if (mode == PurchaseMode.grams && _gramsController.text.isNotEmpty) {
        _syncFromGrams(rate);
      }
    }
  }

  void _showConfirmationSummary({
    required double rate,
    required NumberFormat currency,
    required dynamic l10n,
  }) {
    if (_paying || !widget.isBuy) return;

    final gramsInput = double.tryParse(_gramsController.text);
    final amountInput = double.tryParse(_amountController.text);

    if (_purchaseMode == PurchaseMode.amount) {
      if (amountInput == null || amountInput <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.enterValidTradeAmount)),
        );
        return;
      }
      if (amountInput < 1.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum purchase amount is ₹1.')),
        );
        return;
      }
    } else {
      if (gramsInput == null || gramsInput <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.enterValidTradeAmount)),
        );
        return;
      }
      if (gramsInput < 0.0001) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum gold quantity is 0.0001 g.')),
        );
        return;
      }
    }

    // Verify personal email is added for official tax invoice delivery
    final profile = ref.read(profileProvider).value;
    final dashboard = ref.read(personalDashboardProvider).value;
    final userEmail = profile?.email ?? dashboard?.email;
    if (isPlaceholderEmail(userEmail)) {
      showAddEmailDialog(
        context,
        ref,
        currentEmail: userEmail,
        onEmailSaved: () {
          if (mounted) {
            _showConfirmationSummary(
              rate: rate,
              currency: currency,
              l10n: l10n,
            );
          }
        },
      );
      return;
    }

    double finalAmount = 0;
    double metalValue = 0;
    double gstAmount = 0;
    double finalGrams = 0;

    if (_purchaseMode == PurchaseMode.amount) {
      finalAmount = amountInput!;
      metalValue = finalAmount / 1.03;
      gstAmount = finalAmount - metalValue;
      finalGrams = metalValue / rate;
    } else {
      finalGrams = gramsInput!;
      metalValue = finalGrams * rate;
      gstAmount = metalValue * 0.03;
      finalAmount = metalValue + gstAmount;
    }

    final formattedGrams = _formatGramsForDisplay(finalGrams);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PurchaseConfirmationSheet(
        metal: widget.metal == MetalType.silver ? 'Pure Silver' : '24K Pure Gold',
        purchaseMode: _purchaseMode,
        formattedGrams: formattedGrams,
        rateLabel: currency.format(rate),
        metalValue: currency.format(metalValue),
        gstAmount: currency.format(gstAmount),
        totalPayable: currency.format(finalAmount),
        onConfirm: () {
          Navigator.of(sheetContext).pop();
          _startPayment(rate);
        },
      ),
    );
  }

  Future<void> _startPayment(double rate) async {
    if (_paying || !widget.isBuy) return;

    final gramsInput = double.tryParse(_gramsController.text);
    final amountInput = double.tryParse(_amountController.text);

    setState(() => _paying = true);
    try {
      if (widget.isBuy && widget.metal == MetalType.gold) {
        _schemeWasActiveBeforePayment =
            ref.read(personalDashboardProvider).value?.goldScheme.status;
      }

      // CRITICAL: Strictly separate inputs based on selected purchaseMode.
      // In AMOUNT mode: pass only amountInr (grams is null).
      // In GRAMS mode: pass only grams (amountInr is null).
      final isAmountMode = _purchaseMode == PurchaseMode.amount;
      final order = await ref.read(goldPaymentProvider)(
        metal: widget.metal == MetalType.silver ? 'silver' : 'gold',
        purchaseMode: isAmountMode ? 'amount' : 'grams',
        amountInr: isAmountMode ? amountInput : null,
        grams: isAmountMode ? null : gramsInput,
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
        paymentId: 'pay_mock_${DateTime.now().millisecondsSinceEpoch}',
        signature: 'sig_mock',
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
    final orderId = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (orderId == null || paymentId == null || signature == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.paymentFailed)),
        );
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

    if (_amountController.text.isNotEmpty &&
        _gramsController.text.isEmpty &&
        rate > 0 &&
        !_syncing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _gramsController.text.isEmpty) {
          _syncFromAmount(rate);
        }
      });
    }

    final gramsInput = double.tryParse(_gramsController.text) ?? 0;
    final amountInput = double.tryParse(_amountController.text) ?? 0;
    final hasValidInput = (_purchaseMode == PurchaseMode.amount && amountInput >= 1.0) ||
        (_purchaseMode == PurchaseMode.grams && gramsInput >= 0.0001);

    final metalStr = widget.metal == MetalType.silver ? 'silver' : 'gold';
    final inventoryAsync = ref.watch(digitalMetalInventoryProvider);
    final metalItem = inventoryAsync.asData?.value.firstWhere(
      (item) => item.metalType == metalStr,
      orElse: () => DigitalMetalInventory(
        id: '',
        metalType: metalStr,
        metalLabel: metalStr.toUpperCase(),
        totalWeightGrams: 999999,
        usedWeightGrams: 0,
        reservedWeightGrams: 0,
        availableWeightGrams: 999999,
        lowStockThresholdGrams: 1000,
        stockStatus: MetalStockStatus.available,
        updatedAt: DateTime.now(),
      ),
    );
    final isStockUnavailable = widget.isBuy && metalItem != null && metalItem.availableWeightGrams <= 0;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isStockUnavailable) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.rose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.rose.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pause_circle_outline, color: AppTheme.rose, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.metal == MetalType.silver ? 'Silver' : 'Gold'} is temporarily unavailable.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.rose,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Purchasing is temporarily paused as sellable inventory is out of stock.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await ref.read(subscribeStockNotificationProvider)(metalType: metalStr);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('We will notify you when ${widget.metal == MetalType.silver ? 'Silver' : 'Gold'} is available again!'),
                                  backgroundColor: const Color(0xFF16A34A),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Notification note: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.notifications_active_outlined, size: 18),
                        label: const Text('Notify Me When Available', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGold,
                          side: const BorderSide(color: AppTheme.primaryGold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // 1. Live Market Rate Card
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
            const SizedBox(height: 16),

            // 2. Mode Selector: Pay by Amount vs Buy by Weight
            if (widget.isBuy) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGold.withValues(alpha: 0.25),
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeTabButton(
                        label: 'Enter Amount (₹)',
                        icon: Icons.currency_rupee_rounded,
                        isSelected: _purchaseMode == PurchaseMode.amount,
                        onTap: () => _onModeChanged(PurchaseMode.amount, rate),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _ModeTabButton(
                        label: 'Enter Weight (g)',
                        icon: Icons.scale_rounded,
                        isSelected: _purchaseMode == PurchaseMode.grams,
                        onTap: () => _onModeChanged(PurchaseMode.grams, rate),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Input Fields: Display in selected order with clear indication of authoritative field
            if (_purchaseMode == PurchaseMode.amount) ...[
              _Field(
                label: '${l10n.amountInr} (Exact Payable)',
                controller: _amountController,
                hint: '100.00',
                prefixText: '₹ ',
                badgeText: 'AUTHORITATIVE',
                helperText: 'You will be charged this exact amount via Razorpay.',
                onChanged: (_) => _syncFromAmount(rate),
              ),
              const SizedBox(height: 16),
              _Field(
                label: '${l10n.goldWeightGrams} (Calculated Quantity)',
                controller: _gramsController,
                hint: '0.0000',
                suffixText: ' g',
                badgeText: 'ESTIMATED WEIGHT',
                helperText: 'Pure metal allocated to your vault after 3% GST.',
                onChanged: (_) => _syncFromGrams(rate),
              ),
            ] else ...[
              _Field(
                label: '${l10n.goldWeightGrams} (Exact Quantity)',
                controller: _gramsController,
                hint: '1.0000',
                suffixText: ' g',
                badgeText: 'AUTHORITATIVE',
                helperText: 'Your vault will be credited with this exact weight.',
                onChanged: (_) => _syncFromGrams(rate),
              ),
              const SizedBox(height: 16),
              _Field(
                label: '${l10n.amountInr} (Payable Amount)',
                controller: _amountController,
                hint: '0.00',
                prefixText: '₹ ',
                badgeText: 'CALCULATED PAYABLE',
                helperText: 'Includes live metal value + 3% GST.',
                onChanged: (_) => _syncFromAmount(rate),
              ),
            ],
            const SizedBox(height: 16),

            // 4. Live Breakdown Card
            _buildLiveBreakdownCard(
              rate: rate,
              currency: currency,
            ),
            const SizedBox(height: 24),

            // 5. Action Button
            FilledButton(
              onPressed: (_paying || (widget.isBuy && (!hasValidInput || isStockUnavailable)))
                  ? null
                  : widget.isBuy
                      ? () => _showConfirmationSummary(
                            rate: rate,
                            currency: currency,
                            l10n: l10n,
                          )
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
                  : Text(widget.isBuy ? 'Review & Pay' : l10n.continueToPayment),
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

  Widget _buildLiveBreakdownCard({
    required double rate,
    required NumberFormat currency,
  }) {
    if (rate <= 0) return const SizedBox.shrink();

    final gramsInput = double.tryParse(_gramsController.text) ?? 0;
    final amountInput = double.tryParse(_amountController.text) ?? 0;

    if (gramsInput <= 0 && amountInput <= 0) {
      return const SizedBox.shrink();
    }

    double finalAmount = 0;
    double metalValue = 0;
    double gstAmount = 0;
    double finalGrams = 0;

    if (_purchaseMode == PurchaseMode.amount) {
      if (amountInput <= 0) return const SizedBox.shrink();
      finalAmount = amountInput;
      metalValue = amountInput / 1.03;
      gstAmount = amountInput - metalValue;
      finalGrams = metalValue / rate;
    } else {
      if (gramsInput <= 0) return const SizedBox.shrink();
      finalGrams = gramsInput;
      metalValue = gramsInput * rate;
      gstAmount = metalValue * 0.03;
      finalAmount = metalValue + gstAmount;
    }

    final formattedGrams = _formatGramsForDisplay(finalGrams);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PAYMENT BREAKDOWN',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                _purchaseMode == PurchaseMode.amount
                    ? 'Mode: INR Amount'
                    : 'Mode: Metal Weight',
                style: TextStyle(
                  color: AurumConsumerTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _breakdownRow(
            label: 'Gold to be Credited',
            value: '$formattedGrams g',
            isBold: true,
          ),
          const SizedBox(height: 6),
          _breakdownRow(
            label: 'Net Metal Value',
            value: currency.format(metalValue),
          ),
          const SizedBox(height: 6),
          _breakdownRow(
            label: 'GST Included (3%)',
            value: currency.format(gstAmount),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _breakdownRow(
            label: 'TOTAL PAYABLE (RAZORPAY)',
            value: currency.format(finalAmount),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow({
    required String label,
    required String value,
    bool isBold = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal
                ? AurumConsumerTheme.textPrimary
                : AurumConsumerTheme.textMuted,
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal
                ? FontWeight.w800
                : (isBold ? FontWeight.w600 : FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal
                ? AppTheme.primaryGold
                : AurumConsumerTheme.textPrimary,
            fontSize: isTotal ? 15 : 12,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGold
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AurumConsumerTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AurumConsumerTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? prefixText;
  final String? suffixText;
  final String? badgeText;
  final String? helperText;
  final ValueChanged<String> onChanged;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.prefixText,
    this.suffixText,
    this.badgeText,
    this.helperText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AurumConsumerTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badgeText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
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
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            suffixText: suffixText,
            prefixStyle: TextStyle(
              color: AurumConsumerTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            suffixStyle: TextStyle(
              color: AurumConsumerTheme.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          onChanged: onChanged,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: TextStyle(
              color: AurumConsumerTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _PurchaseConfirmationSheet extends StatelessWidget {
  final String metal;
  final PurchaseMode purchaseMode;
  final String formattedGrams;
  final String rateLabel;
  final String metalValue;
  final String gstAmount;
  final String totalPayable;
  final VoidCallback onConfirm;

  const _PurchaseConfirmationSheet({
    required this.metal,
    required this.purchaseMode,
    required this.formattedGrams,
    required this.rateLabel,
    required this.metalValue,
    required this.gstAmount,
    required this.totalPayable,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PURCHASE SUMMARY',
                      style: TextStyle(
                        color: AurumConsumerTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Review before opening secure payment gateway',
                      style: TextStyle(
                        color: AurumConsumerTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryGold.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              children: [
                _summaryRow('Asset Type', metal),
                const SizedBox(height: 8),
                _summaryRow('Live Market Rate', '$rateLabel / g'),
                const SizedBox(height: 8),
                _summaryRow(
                  'Gold Quantity to Credit',
                  '$formattedGrams g',
                  isBold: true,
                ),
                const SizedBox(height: 8),
                _summaryRow('Metal Value', metalValue),
                const SizedBox(height: 8),
                _summaryRow('GST (3%)', gstAmount),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL PAYABLE',
                      style: TextStyle(
                        color: AurumConsumerTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      totalPayable,
                      style: TextStyle(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 15,
                color: AurumConsumerTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Insured vault storage. Razorpay will charge exactly $totalPayable.',
                  style: TextStyle(
                    color: AurumConsumerTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Pay $totalPayable with Razorpay',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AurumConsumerTheme.textMuted,
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AurumConsumerTheme.textPrimary,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
