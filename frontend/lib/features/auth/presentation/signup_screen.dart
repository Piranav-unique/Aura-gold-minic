import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/domain/login_route_args.dart';
import 'package:ags_gold/features/auth/presentation/providers/app_audience_provider.dart';
import 'package:ags_gold/features/referral/domain/referral_summary.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/core/utils/paste_aware_formatters.dart';
import 'package:ags_gold/core/utils/email_validator.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final String? initialReferralCode;
  final int? initialReferralSchemeGrams;

  const SignupScreen({
    super.key,
    this.initialReferralCode,
    this.initialReferralSchemeGrams,
  });

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  late final TextEditingController _referralController;

  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _acceptedTerms = false;
  bool _attemptedSubmit = false;
  String? _errorMessage;
  String? _otpFieldError;
  String? _otpMessage;

  ButtonStyle get _inlineFilledButtonStyle => FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );

  @override
  void initState() {
    super.initState();
    String initialCode = widget.initialReferralCode?.trim().toUpperCase() ?? '';
    if (initialCode.isNotEmpty) {
      final parsed = ParsedReferralCode.parse(initialCode);
      if (parsed != null && !parsed.hasValidTier && widget.initialReferralSchemeGrams != null) {
        initialCode = '${parsed.baseCode}-${widget.initialReferralSchemeGrams}G';
      } else if (parsed != null && parsed.hasValidTier) {
        initialCode = parsed.fullTierCode;
      }
    }
    _referralController = TextEditingController(text: initialCode);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(appAudienceProvider.notifier).setAudience(AppAudience.endUser);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  String _normalizeMobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return digits;
  }

  String _signupPasswordFor(String mobile) => 'Ag$mobile!x';

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _showSignupError(String message) {
    setState(() {
      _errorMessage = message;
      _otpMessage = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _showErrorSnackBar(message);
  }

  Future<void> _sendOtp() async {
    final mobile = _normalizeMobile(_mobileController.text.trim());
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      setState(() {
        _errorMessage = 'Enter a valid 10-digit mobile number first.';
      });
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
      _otpFieldError = null;
      _otpMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).sendSignupOtp(mobile);
      if (mounted) {
        setState(() {
          _otpSent = true;
          _otpVerified = false;
          _otpMessage = 'OTP sent to +91 $mobile. Check your SMS from AURUS.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
        _showErrorSnackBar(e.message);
      }
    } catch (_) {
      if (mounted) {
        const msg = 'Could not send OTP. Please try again.';
        setState(() {
          _errorMessage = msg;
        });
        _showErrorSnackBar(msg);
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpSent) {
      const msg = 'Tap Send OTP on your mobile number first.';
      setState(() {
        _errorMessage = msg;
        _otpFieldError = msg;
      });
      _showErrorSnackBar(msg);
      return;
    }

    final mobile = _normalizeMobile(_mobileController.text.trim());
    final otp = _otpController.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      setState(() {
        _errorMessage = 'Enter a valid 10-digit mobile number.';
      });
      return;
    }
    if (otp.length != 6) {
      const msg = 'Enter the 6-digit OTP from SMS.';
      setState(() {
        _errorMessage = msg;
        _otpFieldError = msg;
      });
      _showErrorSnackBar(msg);
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
      _otpFieldError = null;
      _otpMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).verifySignupOtp(
            mobileNumber: mobile,
            otp: otp,
          );
      if (mounted) {
        setState(() {
          _otpVerified = true;
          _otpFieldError = null;
          _otpMessage = 'Mobile number verified. Accept terms and tap Sign Up.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        final lower = e.message.toLowerCase();
        final msg = (lower.contains('invalid otp') ||
                lower.contains('incorrect otp') ||
                lower.contains('wrong otp') ||
                lower.contains('not match') ||
                lower.contains('mismatch'))
            ? context.l10n.loginOtpIncorrect
            : e.message;
        setState(() {
          _otpVerified = false;
          _errorMessage = msg;
          _otpFieldError = msg;
        });
        _showErrorSnackBar(msg);
      }
    } catch (_) {
      if (mounted) {
        const msg = 'Could not verify OTP. Please try again.';
        setState(() {
          _otpVerified = false;
          _errorMessage = msg;
          _otpFieldError = msg;
        });
        _showErrorSnackBar(msg);
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifyingOtp = false);
      }
    }
  }

  Future<void> _handleSignup() async {
    FocusScope.of(context).unfocus();
    setState(() => _attemptedSubmit = true);

    final l10n = context.l10n;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final mobile = _normalizeMobile(_mobileController.text.trim());

    _formKey.currentState?.validate();

    if (name.length < 2) {
      _showSignupError(l10n.fullNameRequired);
      return;
    }

    final emailError = validateUserEmail(email);
    if (emailError != null) {
      _showSignupError(emailError);
      return;
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      _showSignupError(l10n.mobileNumberRequired);
      return;
    }

    if (!_otpSent) {
      _showSignupError(
        'Tap Send OTP to receive a code on your mobile number.',
      );
      return;
    }

    if (!_otpVerified) {
      _showSignupError(
        'Enter the OTP from SMS and tap Verify before signing up.',
      );
      return;
    }

    if (!_acceptedTerms) {
      _showSignupError(l10n.mustAcceptDigiGoldTerms);
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showSignupError(l10n.enterSixDigitOtp);
      return;
    }

    final rawReferral = _referralController.text.trim();
    ParsedReferralCode? parsedReferral;
    if (rawReferral.isNotEmpty) {
      parsedReferral = ParsedReferralCode.parse(rawReferral);
      if (parsedReferral == null || !parsedReferral.hasValidTier) {
        _showSignupError(
          'Enter a valid plan referral code ending in -1G, -5G, or -10G (e.g. ${parsedReferral?.baseCode ?? "CODE"}-1G).',
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final mobile = _normalizeMobile(_mobileController.text.trim());
      await ref.read(authNotifierProvider.notifier).register(
            name: _nameController.text.trim(),
            mobileNumber: mobile,
            otp: _otpController.text.trim(),
            email: email,
            password: _signupPasswordFor(mobile),
            referralCode: parsedReferral?.baseCode,
            referralSchemeGrams: parsedReferral?.schemeGrams,
          );
      await ref.read(deviceAuthStorageProvider).saveRegisteredMobile(mobile);
      await ref
          .read(deviceAuthStorageProvider)
          .markPendingTrustedFirstLogin();
      if (mounted) {
        context.go(
          '/login',
          extra: LoginRouteArgs(
            successMessage:
                'Account created! Tap Sign In — no OTP needed this time.',
            mobile: mobile,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Sign up failed. Please check your connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _buildSignupForm(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_add_outlined,
                    size: 100,
                    color: AppTheme.primaryGold,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.joinAurum,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.signUpMobileOtpSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildSignupForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Form(
      key: _formKey,
      autovalidateMode: _attemptedSubmit
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ResponsiveLayout.isMobile(context)) ...[
            const Center(
              child: Icon(
                Icons.person_add_outlined,
                size: 64,
                color: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            context.l10n.createAccount,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.signUpMobileOtpSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null) _messageBox(_errorMessage!, isError: true),
          if (_otpMessage != null) _messageBox(_otpMessage!, isError: false),
          if (_errorMessage != null || _otpMessage != null)
            const SizedBox(height: 16),
          _labeledField(
            label: context.l10n.referralCodeOptional,
            child: TextFormField(
              controller: _referralController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Plan code (e.g. ABCD1234-1G, -5G, or -10G)',
                prefixIcon: Icon(Icons.card_giftcard_outlined),
              ),
            ),
          ),
          if (_referralController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final parsed =
                    ParsedReferralCode.parse(_referralController.text);
                final tierGrams = parsed?.schemeGrams;
                if (tierGrams == 1 || tierGrams == 5 || tierGrams == 10) {
                  final rewardText = tierGrams == 10
                      ? '10g Gold Scheme Code Applied • Deposit min. ₹2,000 to unlock ₹550 gold coupon.'
                      : (tierGrams == 5
                          ? '5g Gold Scheme Code Applied • Deposit min. ₹1,000 to unlock ₹350 gold coupon.'
                          : '1g Gold Scheme Code Applied • Deposit min. ₹100 to unlock ₹150 gold coupon.');
                  return Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E5B34).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF1E5B34).withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: Color(0xFF1E5B34),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rewardText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E5B34),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryGold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Enter the plan-specific referral code ending in -1G, -5G, or -10G (e.g. ${parsed?.baseCode ?? "CODE"}-1G).',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          _labeledField(
            label: l10n.fullName,
            child: TextFormField(
              key: const Key('nameField'),
              controller: _nameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: l10n.yourName,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return l10n.fullNameRequired;
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          _labeledField(
            label: 'Gmail Address (@gmail.com)',
            child: TextFormField(
              key: const Key('emailField'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'name@gmail.com',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: validateUserEmail,
            ),
          ),
          const SizedBox(height: 16),
          _labeledField(
            label: l10n.mobileNumber,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('mobileField'),
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [PasteAwarePhoneFormatter()],
                    decoration: InputDecoration(
                      hintText: l10n.tenDigitMobile,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.mobileNumberRequired;
                      }
                      final mobile = _normalizeMobile(value.trim());
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
                        return l10n.sellGoldInquiryMobileRequired;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('verifyMobileButton'),
                  style: _inlineFilledButtonStyle,
                  onPressed: _isSendingOtp ? null : _sendOtp,
                  child: _isSendingOtp
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.sendOtp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _labeledField(
            label: l10n.enterOtp,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('otpField'),
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    maxLength: 6,
                    readOnly: _otpVerified,
                    inputFormatters: [PasteAwareOtpFormatter()],
                    onChanged: (_) {
                      if (_otpVerified || _otpFieldError != null) {
                        setState(() {
                          _otpVerified = false;
                          _otpFieldError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: l10n.otpFromSms,
                      prefixIcon: Icon(
                        _otpVerified
                            ? Icons.verified_outlined
                            : Icons.sms_outlined,
                      ),
                      counterText: '',
                      errorText: _otpFieldError,
                      suffixIcon: _otpVerified
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                    validator: (value) {
                      if (!_otpSent) return null;
                      if (!_otpVerified &&
                          (value == null || value.trim().length != 6)) {
                        return l10n.enterSixDigitOtp;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('verifyOtpButton'),
                  style: _inlineFilledButtonStyle,
                  onPressed: (_isVerifyingOtp || _otpVerified) ? null : _verifyOtp,
                  child: _isVerifyingOtp
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_otpVerified ? l10n.verified : l10n.verify),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildTermsAcceptance(theme),
          const SizedBox(height: 28),
          ElevatedButton(
            key: const Key('signupButton'),
            onPressed: _isLoading ? null : _handleSignup,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(l10n.signUpButton),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              key: const Key('goToLoginLink'),
              onPressed: () => context.go('/login'),
              child: Text(l10n.alreadyHaveAccountSignIn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsAcceptance(ThemeData theme) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              key: const Key('acceptTermsCheckbox'),
              value: _acceptedTerms,
              activeColor: AppTheme.primaryGold,
              onChanged: (value) {
                setState(() => _acceptedTerms = value ?? false);
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.agreeToDigiGoldTerms,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: TextButton(
            onPressed: () => context.push('/terms-and-conditions'),
            child: Text(l10n.viewTermsAndConditions),
          ),
        ),
      ],
    );
  }

  Widget _messageBox(String message, {required bool isError}) {
    final color = isError ? Colors.redAccent : Colors.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  Widget _labeledField({required String label, required Widget child}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
