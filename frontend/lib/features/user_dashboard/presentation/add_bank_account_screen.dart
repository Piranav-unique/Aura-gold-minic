import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/bank_account_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/services/api_client.dart';

class AddBankAccountScreen extends ConsumerStatefulWidget {
  const AddBankAccountScreen({super.key});

  @override
  ConsumerState<AddBankAccountScreen> createState() =>
      _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends ConsumerState<AddBankAccountScreen> {
  final _holderController = TextEditingController();
  final _accountController = TextEditingController();
  final _otpController = TextEditingController();

  String? _bankCode;
  String? _bankLabel;
  String? _state;
  String? _district;
  String? _branch;
  String? _ifsc;
  String _accountType = 'savings';
  bool _otpSent = false;
  bool _loading = false;
  String? _error;
  String? _infoMessage;

  @override
  void dispose() {
    _holderController.dispose();
    _accountController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool get _formComplete =>
      _holderController.text.trim().isNotEmpty &&
      _accountController.text.trim().length >= 9 &&
      _ifsc != null &&
      _ifsc!.isNotEmpty &&
      _bankLabel != null &&
      _branch != null;

  Future<void> _sendBankOtp() async {
    final l10n = context.l10n;
    if (!_formComplete) {
      setState(() {
        _error =
            'Fill account holder name, account number, and select bank through branch.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _infoMessage = null;
    });

    try {
      final result = await ref.read(bankLinkProvider)(
        accountHolderName: _holderController.text.trim(),
        accountNumber: _accountController.text.trim(),
        ifsc: _ifsc!,
        bankName: _bankLabel!,
        branchName: _branch!,
        accountType: _accountType,
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _infoMessage = result.mobileLast4 != null
            ? l10n.bankLinkOtpSentToMobile(result.mobileLast4!)
            : l10n.bankLinkOtpSent;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.unableToSendOtp);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtpAndLink() async {
    final l10n = context.l10n;
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = l10n.otpInvalid);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(bankLinkVerifyProvider)(otp: otp);
      ref.invalidate(bankAccountsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bankAccountConnected)),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.otpVerificationFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPicker({
    required String title,
    required List<_PickerOption> options,
    required ValueChanged<_PickerOption> onPick,
    bool searchable = false,
  }) async {
    final picked = await showModalBottomSheet<_PickerOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AurumConsumerTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _SearchablePickerSheet(
        title: title,
        options: options,
        searchable: searchable,
      ),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final banksAsync = ref.watch(ifscBanksProvider);
    final statesAsync =
        _bankCode == null ? null : ref.watch(ifscStatesProvider(_bankCode!));
    final districtsAsync = (_bankCode == null || _state == null)
        ? null
        : ref.watch(ifscDistrictsProvider((bank: _bankCode!, state: _state!)));
    final branchesAsync =
        (_bankCode == null || _state == null || _district == null)
            ? null
            : ref.watch(ifscBranchesProvider((
                bank: _bankCode!,
                state: _state!,
                district: _district!,
              )));

    return ResponsiveNavigationWrapper(
        title: l10n.bankAccounts,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            AurumSurfaceCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.9),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.bankAccountsInfo,
                      style: TextStyle(
                        color: AurumConsumerTheme.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.addBankAccount,
              style: TextStyle(
                color: AurumConsumerTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.addBankAccountSheetSubtitle,
              style: TextStyle(
                color: AurumConsumerTheme.textMuted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            _BankLinkStepIndicator(otpSent: _otpSent, l10n: l10n),
            const SizedBox(height: 20),
            _field(
              label: l10n.accountHolderName,
              child: TextField(
                key: const Key('bankHolderField'),
                controller: _holderController,
                textCapitalization: TextCapitalization.words,
                readOnly: _otpSent,
                decoration: InputDecoration(
                  hintText: l10n.accountHolderName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _field(
              label: l10n.accountNumber,
              child: TextField(
                key: const Key('bankAccountNumberField'),
                controller: _accountController,
                keyboardType: TextInputType.number,
                readOnly: _otpSent,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: l10n.accountNumber,
                  prefixIcon: const Icon(Icons.account_balance_outlined),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.findIfscCode,
              style: TextStyle(
                color: AurumConsumerTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            _IfscSelectField(
              label: l10n.chooseBank,
              value: _bankLabel,
              hint: l10n.selectBank,
              enabled: !_otpSent,
              loading: banksAsync.isLoading,
              errorText: banksAsync.hasError
                  ? 'Could not load banks. Tap to retry.'
                  : null,
              onTap: banksAsync.hasError
                  ? () => ref.invalidate(ifscBanksProvider)
                  : banksAsync.whenOrNull(
                      data: (banks) => () {
                        if (banks.isEmpty) {
                          setState(() => _error = 'No banks available.');
                          return;
                        }
                        final options = banks.entries
                            .map((e) => _PickerOption(code: e.key, label: e.value))
                            .toList()
                          ..sort((a, b) => a.label.compareTo(b.label));
                        _openPicker(
                          title: l10n.chooseBank,
                          options: options,
                          searchable: true,
                          onPick: (item) => setState(() {
                            _bankCode = item.code;
                            _bankLabel = item.label;
                            _state = null;
                            _district = null;
                            _branch = null;
                            _ifsc = null;
                          }),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            _IfscSelectField(
              label: l10n.searchByState,
              value: _state,
              hint: l10n.selectState,
              enabled: !_otpSent && _bankCode != null,
              loading: statesAsync?.isLoading ?? false,
              onTap: statesAsync?.whenOrNull(
                data: (states) => () {
                  _openPicker(
                    title: l10n.searchByState,
                    options: states
                        .map((s) => _PickerOption(code: s, label: s))
                        .toList(),
                    searchable: true,
                    onPick: (item) => setState(() {
                      _state = item.label;
                      _district = null;
                      _branch = null;
                      _ifsc = null;
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _IfscSelectField(
              label: l10n.searchByDistrict,
              value: _district,
              hint: l10n.selectDistrict,
              enabled: !_otpSent && _state != null,
              loading: districtsAsync?.isLoading ?? false,
              onTap: districtsAsync?.whenOrNull(
                data: (districts) => () {
                  _openPicker(
                    title: l10n.searchByDistrict,
                    options: districts
                        .map((d) => _PickerOption(code: d, label: d))
                        .toList(),
                    searchable: true,
                    onPick: (item) => setState(() {
                      _district = item.label;
                      _branch = null;
                      _ifsc = null;
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _IfscSelectField(
              label: l10n.searchByBranch,
              value: _branch,
              hint: l10n.selectBranch,
              enabled: !_otpSent && _district != null,
              loading: branchesAsync?.isLoading ?? false,
              onTap: branchesAsync?.whenOrNull(
                data: (branches) => () {
                  _openPicker(
                    title: l10n.searchByBranch,
                    options: branches
                        .map(
                          (b) => _PickerOption(
                            code: b.branch,
                            label: b.branch,
                            extra: b.ifsc,
                          ),
                        )
                        .toList(),
                    searchable: true,
                    onPick: (item) => setState(() {
                      _branch = item.label;
                      _ifsc = item.extra;
                    }),
                  );
                },
              ),
            ),
            if (_ifsc != null && _ifsc!.isNotEmpty) ...[
              const SizedBox(height: 12),
              AurumSurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        '${l10n.ifscCode}: $_ifsc',
                        style: TextStyle(
                          color: AurumConsumerTheme.chipGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _IfscSelectField(
              label: l10n.accountType,
              value: _accountType == 'savings'
                  ? l10n.savingsAccount
                  : l10n.currentAccount,
              hint: l10n.savingsAccount,
              enabled: !_otpSent,
              leading: const Icon(Icons.savings_outlined, size: 20),
              onTap: () {
                _openPicker(
                  title: l10n.accountType,
                  options: [
                    _PickerOption(code: 'savings', label: l10n.savingsAccount),
                    _PickerOption(code: 'current', label: l10n.currentAccount),
                  ],
                  onPick: (item) => setState(() => _accountType = item.code),
                );
              },
            ),
            if (_otpSent) ...[
              const SizedBox(height: 24),
              AurumSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.sms_outlined,
                      color: AurumConsumerTheme.liveGreen,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _infoMessage ?? l10n.bankLinkOtpSent,
                        style: TextStyle(
                          color: AurumConsumerTheme.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.enterOtp,
                style: TextStyle(
                  color: AurumConsumerTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.bankAccountsOtpNote,
                style: TextStyle(
                  color: AurumConsumerTheme.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('bankOtpField'),
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: l10n.otpHint,
                  counterText: '',
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _sendBankOtp,
                  child: Text(l10n.resendOtp),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('verifyBankOtpButton'),
                onPressed: _loading ? null : _verifyOtpAndLink,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.confirmBankLink),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            if (_infoMessage != null && !_otpSent) ...[
              const SizedBox(height: 12),
              Text(
                _infoMessage!,
                style: TextStyle(
                  color: AurumConsumerTheme.liveGreen,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!_otpSent)
              FilledButton(
                key: const Key('verifyBankDetailsButton'),
                onPressed: _loading || !_formComplete ? null : _sendBankOtp,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.sendBankOtp),
              ),
          ],
        ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AurumConsumerTheme.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _BankLinkStepIndicator extends StatelessWidget {
  final bool otpSent;
  final AppLocalizations l10n;

  const _BankLinkStepIndicator({required this.otpSent, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _step(
          step: 1,
          label: l10n.bankLinkStepDetails,
          active: !otpSent,
          done: otpSent,
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 22, left: 8, right: 8),
            color: otpSent
                ? AurumConsumerTheme.chipGold
                : AurumConsumerTheme.border,
          ),
        ),
        _step(
          step: 2,
          label: l10n.bankLinkStepOtp,
          active: otpSent,
          done: false,
        ),
      ],
    );
  }

  Widget _step({
    required int step,
    required String label,
    required bool active,
    required bool done,
  }) {
    final color = done
        ? AurumConsumerTheme.liveGreen
        : active
            ? AurumConsumerTheme.chipGold
            : AurumConsumerTheme.textMuted;

    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: active || done
              ? color.withValues(alpha: 0.2)
              : AurumConsumerTheme.surfaceElevated,
          child: done
              ? Icon(Icons.check, size: 14, color: color)
              : Text(
                  '$step',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: active || done
                ? AurumConsumerTheme.textPrimary
                : AurumConsumerTheme.textMuted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _PickerOption {
  final String code;
  final String label;
  final String? extra;

  const _PickerOption({
    required this.code,
    required this.label,
    this.extra,
  });
}

class _IfscSelectField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final bool enabled;
  final bool loading;
  final String? errorText;
  final VoidCallback? onTap;
  final Widget? leading;

  const _IfscSelectField({
    required this.label,
    required this.value,
    required this.hint,
    required this.enabled,
    this.loading = false,
    this.errorText,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final display = (value == null || value!.isEmpty) ? hint : value!;
    final isPlaceholder = value == null || value!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AurumConsumerTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (errorText != null) ...[
          Text(
            errorText!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
          ),
          const SizedBox(height: 4),
        ],
        Material(
          color: enabled
              ? AurumConsumerTheme.surfaceElevated
              : AurumConsumerTheme.surfaceElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled && !loading ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AurumConsumerTheme.border),
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    IconTheme(
                      data: IconThemeData(
                        color: AurumConsumerTheme.textMuted.withValues(
                          alpha: enabled ? 1 : 0.5,
                        ),
                        size: 20,
                      ),
                      child: leading!,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      display,
                      style: TextStyle(
                        color: isPlaceholder
                            ? AurumConsumerTheme.textMuted.withValues(
                                alpha: enabled ? 0.7 : 0.4,
                              )
                            : AurumConsumerTheme.textPrimary.withValues(
                                alpha: enabled ? 1 : 0.6,
                              ),
                        fontWeight:
                            isPlaceholder ? FontWeight.w500 : FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AurumConsumerTheme.textMuted.withValues(
                        alpha: enabled ? 1 : 0.4,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchablePickerSheet extends StatefulWidget {
  final String title;
  final List<_PickerOption> options;
  final bool searchable;

  const _SearchablePickerSheet({
    required this.title,
    required this.options,
    required this.searchable,
  });

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.searchable && _query.isNotEmpty
        ? widget.options
            .where(
              (o) => o.label.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList()
        : widget.options;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            if (widget.searchable) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return ListTile(
                    title: Text(item.label),
                    subtitle: item.extra != null && item.extra!.isNotEmpty
                        ? Text(item.extra!)
                        : null,
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
