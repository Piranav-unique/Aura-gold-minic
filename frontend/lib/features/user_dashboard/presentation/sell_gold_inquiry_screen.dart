import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/domain/bank_account.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/bank_account_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/sell_gold_inquiry_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/services/api_client.dart';

class SellGoldInquiryScreen extends ConsumerStatefulWidget {
  const SellGoldInquiryScreen({super.key});

  @override
  ConsumerState<SellGoldInquiryScreen> createState() =>
      _SellGoldInquiryScreenState();
}

class _SellGoldInquiryScreenState extends ConsumerState<SellGoldInquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _quantityController = TextEditingController();
  final _messageController = TextEditingController();
  String? _selectedBankAccountId;
  bool _bankDefaultInitialized = false;
  bool _loading = false;
  String? _error;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _quantityController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _prefillFromDashboard() {
    if (_prefilled) return;
    final dashboard = ref.read(personalDashboardProvider).value;
    if (dashboard != null && dashboard.displayName.isNotEmpty) {
      _nameController.text = dashboard.displayName;
    }
    _prefilled = true;
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(submitSellGoldInquiryProvider)(
        name: _nameController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        quantityGrams: double.parse(_quantityController.text.trim()),
        message: _messageController.text.trim(),
        bankAccountId: _selectedBankAccountId,
      );
      ref.invalidate(mySellGoldInquiriesProvider);
      if (!mounted) return;
      context.go('/sell-gold-inquiry/success');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.sellGoldInquirySubmitFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildPayoutDestinationSection(
    BuildContext context,
    AsyncValue<List<BankAccount>> accountsAsync,
  ) {
    final l10n = context.l10n;
    return accountsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => _buildDirectSettlementBanner(context),
      data: (accounts) {
        if (!_bankDefaultInitialized && accounts.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_bankDefaultInitialized) {
              setState(() {
                _selectedBankAccountId = accounts.first.id;
                _bankDefaultInitialized = true;
              });
            }
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payout Destination',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AurumConsumerTheme.textPrimary,
                  ),
                ),
                if (accounts.length < maxUserBankAccounts)
                  TextButton.icon(
                    onPressed: () async {
                      await context.push('/bank-accounts/add');
                      ref.invalidate(bankAccountsProvider);
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l10n.addBankAccount),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final acc in accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedBankAccountId = acc.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedBankAccountId == acc.id
                            ? AurumConsumerTheme.chipGold
                            : Colors.grey.withValues(alpha: 0.35),
                        width: _selectedBankAccountId == acc.id ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedBankAccountId == acc.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 20,
                          color: _selectedBankAccountId == acc.id
                              ? AurumConsumerTheme.chipGold
                              : AurumConsumerTheme.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${acc.bankName} • ${acc.accountNumberMasked}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                  color: AurumConsumerTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${acc.accountHolderName} • IFSC: ${acc.ifsc}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AurumConsumerTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            InkWell(
              onTap: () => setState(() => _selectedBankAccountId = null),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedBankAccountId == null
                        ? AurumConsumerTheme.chipGold
                        : Colors.grey.withValues(alpha: 0.35),
                    width: _selectedBankAccountId == null ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedBankAccountId == null
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 20,
                      color: _selectedBankAccountId == null
                          ? AurumConsumerTheme.chipGold
                          : AurumConsumerTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Direct Settlement (Admin Assisted)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: AurumConsumerTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Admin will review and settle directly via UPI / Bank / Store visit',
                            style: TextStyle(
                              fontSize: 12,
                              color: AurumConsumerTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDirectSettlementBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_outlined,
            color: AurumConsumerTheme.chipGold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Payout routing: Direct Settlement upon admin approval',
              style: TextStyle(
                fontSize: 13,
                color: AurumConsumerTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountsAsync = ref.watch(bankAccountsProvider);
    _prefillFromDashboard();

    return ResponsiveNavigationWrapper(
      title: l10n.sellGoldInquiryTitle,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.sellGoldInquiryTitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AurumConsumerTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.sellGoldInquirySubtitle,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AurumConsumerTheme.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              AurumSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.sellGoldInquiryName,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return l10n.sellGoldInquiryNameRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: InputDecoration(
                        labelText: l10n.sellGoldInquiryMobile,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        final digits =
                            value?.replaceAll(RegExp(r'\D'), '') ?? '';
                        if (digits.length != 10) {
                          return l10n.sellGoldInquiryMobileRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity to sell (grams)',
                        prefixIcon: Icon(Icons.scale_outlined),
                        suffixText: 'g',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,4}'),
                        ),
                      ],
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid quantity in grams';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPayoutDestinationSection(context, accountsAsync),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: l10n.sellGoldInquiryMessage,
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 72),
                          child: Icon(Icons.message_outlined),
                        ),
                      ),
                      minLines: 4,
                      maxLines: 6,
                      validator: (value) {
                        if (value == null || value.trim().length < 10) {
                          return l10n.sellGoldInquiryMessageRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AurumConsumerTheme.chipGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(l10n.sellGoldInquirySubmit),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

