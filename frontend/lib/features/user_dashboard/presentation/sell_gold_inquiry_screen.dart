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
  bool _loading = false;
  String? _error;
  bool _prefilled = false;
  String? _selectedBankAccountId;

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

  void _ensureBankSelection(List<BankAccount> accounts) {
    if (accounts.isEmpty) {
      _selectedBankAccountId = null;
      return;
    }
    if (_selectedBankAccountId != null &&
        accounts.any((a) => a.id == _selectedBankAccountId)) {
      return;
    }
    final primary = accounts.where((a) => a.isPrimary).firstOrNull;
    _selectedBankAccountId = (primary ?? accounts.first).id;
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    final bankId = _selectedBankAccountId;
    if (bankId == null || bankId.isEmpty) {
      setState(() => _error = l10n.sellGoldNoBankLinked);
      return;
    }

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
        bankAccountId: bankId,
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

  Widget _buildPayoutBankSection(List<BankAccount> accounts) {
    final l10n = context.l10n;

    if (accounts.isEmpty) {
      return AurumSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  color: AurumConsumerTheme.chipGold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.sellGoldPayoutBankTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AurumConsumerTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sellGoldNoBankLinked,
              style: TextStyle(
                color: AurumConsumerTheme.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/bank-accounts/add'),
              icon: const Icon(Icons.add),
              label: Text(l10n.sellGoldAddBankAccount),
            ),
          ],
        ),
      );
    }

    return AurumSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sellGoldPayoutBankTitle,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AurumConsumerTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.sellGoldPayoutBankSubtitle,
            style: TextStyle(
              color: AurumConsumerTheme.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.sellGoldSelectPayoutBank,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AurumConsumerTheme.textPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...accounts.map((account) {
            return RadioListTile<String>(
              value: account.id,
              groupValue: _selectedBankAccountId,
              onChanged: (value) {
                setState(() => _selectedBankAccountId = value);
              },
              contentPadding: EdgeInsets.zero,
              title: Text(
                account.bankName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AurumConsumerTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                '${account.accountNumberMasked} · ${account.ifsc}',
                style: TextStyle(color: AurumConsumerTheme.textMuted),
              ),
              secondary: account.isPrimary
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AurumConsumerTheme.chipGold.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Primary',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            );
          }),
          if (accounts.length < maxUserBankAccounts)
            TextButton.icon(
              onPressed: () => context.push('/bank-accounts/add'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addBankAccount),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final banksAsync = ref.watch(bankAccountsProvider);
    _prefillFromDashboard();

    return ResponsiveNavigationWrapper(
      title: l10n.sellGoldInquiryTitle,
      child: banksAsync.when(
        data: (accounts) {
          _ensureBankSelection(accounts);
          return SingleChildScrollView(
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
                  _buildPayoutBankSection(accounts),
                  const SizedBox(height: 16),
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
                          onPressed: _loading || accounts.isEmpty
                              ? null
                              : _submit,
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$e', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
    );
  }
}
