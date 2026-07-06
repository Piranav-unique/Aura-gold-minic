import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/kyc_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/pending_trade_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/kyc_aadhaar_mobile_card.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/kyc_verified_success_view.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/core/logging/app_event_log.dart';

class KycVerificationScreen extends ConsumerStatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  ConsumerState<KycVerificationScreen> createState() =>
      _KycVerificationScreenState();
}

class _KycVerificationScreenState extends ConsumerState<KycVerificationScreen> {
  final _aadhaarFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _panFormKey = GlobalKey<FormState>();

  final _aadhaarController = TextEditingController();
  final _otpController = TextEditingController();
  final _panController = TextEditingController();

  int _stage = 1;
  bool _otpSent = false;
  String? _referenceId;
  String? _pendingAadhaar;
  bool _isLoading = false;
  String? _errorMessage;
  String? _registeredMobileMasked;
  KycGovernmentProfile? _verifiedProfile;

  static const _kycRefKey = 'kyc_aadhaar_reference_id';
  static const _kycOtpSentKey = 'kyc_aadhaar_otp_sent';
  static const _kycAadhaarKey = 'kyc_aadhaar_pending';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreOtpSession();
      final status = ref.read(kycStatusProvider);
      status.whenData((details) {
        if (details.registeredMobileMasked != null &&
            details.registeredMobileMasked!.isNotEmpty) {
          _registeredMobileMasked = details.registeredMobileMasked;
        }
        _syncStageFromStatus(details);
      });
    });
  }

  Future<void> _restoreOtpSession() async {
    final prefs = await SharedPreferences.getInstance();
    final refId = prefs.getString(_kycRefKey);
    final otpSent = prefs.getBool(_kycOtpSentKey) ?? false;
    final aadhaar = prefs.getString(_kycAadhaarKey);
    if (!mounted || refId == null || !otpSent) return;
    if (aadhaar == null || aadhaar.length != 12) {
      await _persistOtpSession(sent: false);
      return;
    }
    setState(() {
      _referenceId = refId;
      _otpSent = true;
      _pendingAadhaar = aadhaar;
      _aadhaarController.text = aadhaar;
    });
  }

  Future<void> _persistOtpSession({
    required bool sent,
    String? referenceId,
    String? aadhaarNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (sent && referenceId != null && aadhaarNumber != null) {
      await prefs.setString(_kycRefKey, referenceId);
      await prefs.setBool(_kycOtpSentKey, true);
      await prefs.setString(_kycAadhaarKey, aadhaarNumber);
    } else {
      await prefs.remove(_kycRefKey);
      await prefs.setBool(_kycOtpSentKey, false);
      await prefs.remove(_kycAadhaarKey);
    }
  }

  String _friendlyKycError(String message) {
    if (message.toLowerCase().contains('source unavailable')) {
      return 'UIDAI is temporarily unavailable. Wait a minute, then tap '
          'Verify again — or request a new OTP.';
    }
    if (message.contains('aadhaar_number') ||
        message.toLowerCase().contains('string should have at least 12')) {
      return 'Aadhaar number was lost from this session. Tap '
          '"Change Aadhaar number" and enter it again.';
    }
    if (message.toLowerCase().contains('does not match') ||
        message.toLowerCase().contains('unable to confirm the mobile')) {
      return context.l10n.kycMobileMismatchError;
    }
    if (message.toLowerCase().contains('already verified')) {
      return 'Aadhaar is already verified. Continue with PAN linking below.';
    }
    if (message.toLowerCase().contains('complete aadhaar verification')) {
      return 'Aadhaar OTP was not saved on the server. Tap "Back to Aadhaar '
          'verification", request a new OTP, and verify again.';
    }
    return message;
  }

  int _effectiveStage(KycStatusDetails? details) {
    if (details != null) {
      if (details.status == KycStatus.verified) return 3;
      if (details.status.aadhaarComplete) return 2;
      return 1;
    }
    return _otpSent ? 1 : _stage.clamp(1, 2);
  }

  void _syncStageFromStatus(KycStatusDetails details) {
    if (!mounted) return;
    if (details.status == KycStatus.aadhaarVerified) {
      setState(() {
        _stage = 2;
        _otpSent = false;
        _referenceId = null;
        _pendingAadhaar = null;
        _errorMessage = null;
      });
      _persistOtpSession(sent: false);
    } else if (details.status == KycStatus.verified) {
      setState(() {
        _stage = 3;
        _verifiedProfile = details.profile;
        _errorMessage = null;
      });
    } else if (details.status == KycStatus.notStarted ||
        details.status == KycStatus.rejected) {
      setState(() {
        _stage = 1;
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    _otpController.dispose();
    _panController.dispose();
    super.dispose();
  }

  String get _aadhaarDigits =>
      _aadhaarController.text.replaceAll(RegExp(r'\D'), '');

  String get _effectiveAadhaarDigits {
    final fromField = _aadhaarDigits;
    if (fromField.length == 12) return fromField;
    final pending = _pendingAadhaar?.replaceAll(RegExp(r'\D'), '') ?? '';
    return pending.length == 12 ? pending : fromField;
  }

  Future<void> _sendOtp() async {
    if (!_otpSent) {
      final formState = _aadhaarFormKey.currentState;
      if (formState == null || !formState.validate()) return;
    } else if (_effectiveAadhaarDigits.length != 12) {
      setState(() {
        _errorMessage = _friendlyKycError('aadhaar_number');
        _otpSent = false;
        _referenceId = null;
        _pendingAadhaar = null;
      });
      await _persistOtpSession(sent: false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    AppEventLog.action('kyc_send_otp', data: {'resend': _otpSent});

    try {
      final aadhaar = _effectiveAadhaarDigits;
      if (aadhaar.length != 12) {
        setState(() {
          _errorMessage = _friendlyKycError('aadhaar_number');
          _otpSent = false;
          _referenceId = null;
          _pendingAadhaar = null;
        });
        await _persistOtpSession(sent: false);
        return;
      }

      final otpResult = await ref.read(kycAadhaarOtpProvider)(aadhaar);
      setState(() {
        _referenceId = otpResult.referenceId;
        _otpSent = true;
        _pendingAadhaar = aadhaar;
        _aadhaarController.text = aadhaar;
        _registeredMobileMasked = otpResult.registeredMobileMasked;
      });
      await _persistOtpSession(
        sent: true,
        referenceId: otpResult.referenceId,
        aadhaarNumber: aadhaar,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.otpSentSnack)),
        );
      }
    } on ApiException catch (e) {
      AppEventLog.action(
        'kyc_send_otp_failed',
        data: {'message': e.message},
      );
      setState(() => _errorMessage = _friendlyKycError(e.message));
    } catch (_) {
      setState(() => _errorMessage = context.l10n.unableToSendOtp);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAadhaar() async {
    final formState = _otpFormKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    AppEventLog.action('kyc_verify_aadhaar');

    try {
      final aadhaar = _effectiveAadhaarDigits;
      if (aadhaar.length != 12) {
        setState(() {
          _errorMessage = _friendlyKycError('aadhaar_number');
          _otpSent = false;
          _referenceId = null;
          _pendingAadhaar = null;
        });
        await _persistOtpSession(sent: false);
        return;
      }

      final details = await ref.read(kycAadhaarVerifyProvider)(
        referenceId: _referenceId ?? '',
        otp: _otpController.text.trim(),
        aadhaarNumber: aadhaar,
      );
      if (!mounted) return;
      if (!details.status.aadhaarComplete) {
        setState(() {
          _errorMessage = context.l10n.otpVerificationFailed;
          _otpSent = false;
          _referenceId = null;
          _pendingAadhaar = null;
        });
        await _persistOtpSession(sent: false);
        return;
      }

      setState(() {
        _stage = 2;
        _otpSent = false;
        _referenceId = null;
        _pendingAadhaar = null;
        _otpController.clear();
        _errorMessage = null;
      });
      await _persistOtpSession(sent: false);

      // Refresh cached KYC elsewhere without recreating the navigation stack.
      ref.invalidate(kycStatusProvider);
      ref.invalidate(userKycGateProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.aadhaarVerifiedContinuePan)),
      );
    } on ApiException catch (e) {
      AppEventLog.action(
        'kyc_verify_aadhaar_failed',
        data: {'message': e.message},
      );
      setState(() => _errorMessage = _friendlyKycError(e.message));
    } catch (_) {
      setState(() => _errorMessage = context.l10n.otpVerificationFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPan() async {
    final formState = _panFormKey.currentState;
    if (formState == null || !formState.validate()) return;

    final currentStatus = ref.read(kycStatusProvider).value;
    if (currentStatus != null && !currentStatus.status.aadhaarComplete) {
      setState(() {
        _errorMessage = _friendlyKycError(
          'Complete Aadhaar verification before PAN linking.',
        );
        _stage = 1;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    AppEventLog.action('kyc_verify_pan');

    try {
      final details = await ref.read(kycPanVerifyProvider)(
        _panController.text.trim().toUpperCase(),
      );
      ref.invalidate(kycStatusProvider);
      ref.invalidate(userKycGateProvider);
      await ref.read(personalDashboardProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.kycCompleteSnack)),
        );
        setState(() {
          _stage = 3;
          _verifiedProfile = details.profile;
        });
      }
    } on ApiException catch (e) {
      final message = _friendlyKycError(e.message);
      setState(() => _errorMessage = message);
      if (message.toLowerCase().contains('aadhaar otp was not saved')) {
        setState(() {
          _stage = 1;
          _otpSent = false;
        });
        ref.invalidate(kycStatusProvider);
      }
    } catch (_) {
      setState(() => _errorMessage = context.l10n.panVerificationFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _continueAfterKyc(BuildContext context) {
    final pending = ref.read(pendingTradeProvider);
    ref.read(pendingTradeProvider.notifier).clear();
    if (pending != null) {
      context.go(pending.routePath);
    } else {
      context.go('/buy-gold?metal=gold');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final statusAsync = ref.watch(kycStatusProvider);
    final details = statusAsync.value;
    final displayStage = _effectiveStage(details);
    ref.listen(kycStatusProvider, (previous, next) {
      next.whenData(_syncStageFromStatus);
    });

    return ResponsiveNavigationWrapper(
        title: l10n.kycVerification,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepIndicator(
                    currentStage: displayStage,
                    aadhaarLabel: l10n.aadhaarOtpStep,
                    panLabel: l10n.panLinkStep,
                    confirmLabel: l10n.kycStepConfirm,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    _errorBanner(_errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  statusAsync.when(
                  loading: () => displayStage == 1
                      ? _buildAadhaarStage(
                          context,
                          theme,
                          registeredMobileMasked: _registeredMobileMasked,
                        )
                      : _buildPanStage(
                          context,
                          theme,
                          showAadhaarBanner: displayStage >= 2,
                        ),
                  error: (_, _) => displayStage == 1
                      ? _buildAadhaarStage(context, theme)
                      : _buildPanStage(
                          context,
                          theme,
                          showAadhaarBanner: false,
                        ),
                  data: (details) {
                    final stage = _effectiveStage(details);
                    if (details.status == KycStatus.verified) {
                      final profile =
                          _verifiedProfile ?? details.profile;
                      if (profile != null && profile.hasIdentity) {
                        final pending = ref.watch(pendingTradeProvider);
                        final primaryLabel = pending != null
                            ? (pending.isBuy ? l10n.buyGold : l10n.sellGold)
                            : l10n.buyGold;

                        return KycVerifiedSuccessView(
                          profile: profile,
                          primaryActionLabel: primaryLabel,
                          onPrimaryAction: () => _continueAfterKyc(context),
                          onSecondaryAction: pending != null
                              ? () {
                                  ref
                                      .read(pendingTradeProvider.notifier)
                                      .clear();
                                  context.go('/user-dashboard');
                                }
                              : null,
                          secondaryActionLabel: pending != null
                              ? l10n.backToDashboard
                              : null,
                        );
                      }
                    }
                    if (stage == 2 && details.status.aadhaarComplete) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (details.profile?.aadhaarLinkedMobileMasked !=
                                  null &&
                              details
                                  .profile!
                                  .aadhaarLinkedMobileMasked!
                                  .isNotEmpty)
                            KycAadhaarMobileCard(
                              mobileMasked:
                                  details.profile!.aadhaarLinkedMobileMasked!,
                            ),
                          if (details.profile?.aadhaarLinkedMobileMasked !=
                                  null &&
                              details
                                  .profile!
                                  .aadhaarLinkedMobileMasked!
                                  .isNotEmpty)
                            const SizedBox(height: 20),
                          Text(
                            l10n.kycStage2Subtitle,
                            style: TextStyle(
                              color: AurumConsumerTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.panHelper,
                            style: TextStyle(
                              color: AurumConsumerTheme.textMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildPanStage(
                            context,
                            theme,
                            aadhaarLast4: details.aadhaarLast4,
                            showAadhaarBanner: true,
                          ),
                        ],
                      );
                    }
                    return stage == 1
                        ? _buildAadhaarStage(
                            context,
                            theme,
                            aadhaarLast4: details.aadhaarLast4,
                            registeredMobileMasked:
                                details.registeredMobileMasked ??
                                    _registeredMobileMasked,
                          )
                        : _buildPanStage(
                            context,
                            theme,
                            aadhaarLast4: details.aadhaarLast4,
                            showAadhaarBanner: false,
                          );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAadhaarStage(
    BuildContext context,
    ThemeData theme, {
    String? aadhaarLast4,
    String? registeredMobileMasked,
  }) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_otpSent) ...[
          Text(
            l10n.kycStep1VerifyAadhaar,
            style: TextStyle(
              color: AurumConsumerTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.kycAadhaarOtpInstruction,
            style: TextStyle(
              color: AurumConsumerTheme.textMuted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (registeredMobileMasked != null &&
              registeredMobileMasked.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.kycRegisteredMobileHint(registeredMobileMasked),
              style: TextStyle(
                color: AurumConsumerTheme.chipGold,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Form(
            key: _aadhaarFormKey,
            child: TextFormField(
              controller: _aadhaarController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: InputDecoration(
                hintText: l10n.aadhaarHint,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.length != 12) {
                  return l10n.aadhaarInvalid;
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _sendOtp,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.sendOtp),
            ),
          ),
        ] else ...[
          Text(
            l10n.otpSentToMobile(
              aadhaarLast4 != null
                  ? l10n.otpSentEnding(aadhaarLast4)
                  : '',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _otpFormKey,
            child: _field(
              label: l10n.enterOtp,
              child: TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  hintText: l10n.otpHint,
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().length != 6) {
                    return l10n.otpInvalid;
                  }
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        await _persistOtpSession(sent: false);
                        if (!mounted) return;
                        setState(() {
                          _otpSent = false;
                          _referenceId = null;
                          _pendingAadhaar = null;
                          _otpController.clear();
                        });
                      },
                child: Text(l10n.changeAadhaarNumber),
              ),
              const Spacer(),
              TextButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: Text(l10n.resendOtp),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _verifyAadhaar,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(_isLoading ? l10n.verifying : l10n.verifyAadhaar),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPanStage(
    BuildContext context,
    ThemeData theme, {
    String? aadhaarLast4,
    bool showAadhaarBanner = true,
  }) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAadhaarBanner) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    aadhaarLast4 != null
                        ? l10n.aadhaarVerifiedLast4(aadhaarLast4)
                        : l10n.aadhaarVerified,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Form(
          key: _panFormKey,
            child: _field(
              label: l10n.panNumber,
              child: TextFormField(
                controller: _panController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
                decoration: InputDecoration(
                  hintText: l10n.panHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                  helperText: l10n.panHelper,
                ),
                validator: (v) {
                  final pan = (v ?? '').trim().toUpperCase();
                  if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
                    return l10n.panInvalid;
                  }
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _stage = 1;
                      _otpSent = false;
                      _referenceId = null;
                      _pendingAadhaar = null;
                      _otpController.clear();
                    }),
            child: Text(l10n.backToAadhaarVerification),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _verifyPan,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_outlined),
              label: Text(_isLoading ? l10n.verifying : l10n.verifyPanLink),
          ),
        ),
      ],
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStage;
  final String aadhaarLabel;
  final String panLabel;
  final String confirmLabel;

  const _StepIndicator({
    required this.currentStage,
    required this.aadhaarLabel,
    required this.panLabel,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepChip(
          step: 1,
          label: aadhaarLabel,
          active: currentStage == 1,
          done: currentStage > 1,
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 22, left: 8, right: 8),
            color: currentStage > 1
                ? AurumConsumerTheme.chipGold
                : AurumConsumerTheme.border,
          ),
        ),
        _StepChip(
          step: 2,
          label: panLabel,
          active: currentStage == 2,
          done: currentStage > 2,
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 22, left: 8, right: 8),
            color: currentStage > 2
                ? AurumConsumerTheme.chipGold
                : AurumConsumerTheme.border,
          ),
        ),
        _StepChip(
          step: 3,
          label: confirmLabel,
          active: currentStage == 3,
          done: currentStage >= 3,
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final int step;
  final String label;
  final bool active;
  final bool done;

  const _StepChip({
    required this.step,
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AurumConsumerTheme.liveGreen
        : active
            ? AurumConsumerTheme.chipGold
            : AurumConsumerTheme.textMuted;

    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: active || done
              ? color.withValues(alpha: 0.2)
              : AurumConsumerTheme.surfaceElevated,
          child: done
              ? Icon(Icons.check, size: 16, color: color)
              : Text(
                  '$step',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
