import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/config/env_config.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/domain/device_auth_storage.dart';
import 'package:ags_gold/features/auth/presentation/providers/app_audience_provider.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.successMessage, this.initialMobile});

  final String? successMessage;
  final String? initialMobile;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  String? _errorMessage;
  String? _successMessage;
  String? _otpMessage;
  String? _lockedMobile;
  bool _pendingTrustedFirstLogin = false;

  ButtonStyle get _inlineFilledButtonStyle => FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );

  @override
  void initState() {
    super.initState();
    _successMessage = widget.successMessage;
    if (widget.initialMobile != null && widget.initialMobile!.isNotEmpty) {
      _mobileController.text = widget.initialMobile!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDeviceMobile());
  }

  Future<void> _loadDeviceMobile() async {
    final deviceAuth = ref.read(deviceAuthStorageProvider);
    final stored = await deviceAuth.getRegisteredMobile();
    final pending = await deviceAuth.isPendingTrustedFirstLogin();
    if (!mounted) return;
    setState(() {
      _lockedMobile = stored;
      _pendingTrustedFirstLogin = pending;
      if (stored != null &&
          stored.isNotEmpty &&
          _mobileController.text.trim().isEmpty) {
        _mobileController.text = stored;
      }
    });
  }

  String get _normalizedAdminMobile =>
      _normalizeMobile(EnvConfig.active.adminNumber);

  bool _isAdminMobile(String mobile) => mobile == _normalizedAdminMobile;

  bool _isTrustedSignupMobile(String mobile) {
    final trusted = widget.initialMobile ?? _lockedMobile;
    if (trusted == null || trusted.isEmpty) return false;
    return mobile == _normalizeMobile(trusted);
  }

  bool get _showTrustedFirstLogin {
    if (!_pendingTrustedFirstLogin) return false;
    final mobile = _normalizeMobile(_mobileController.text.trim());
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) return false;
    if (_isAdminMobile(mobile)) return false;
    return _isTrustedSignupMobile(mobile);
  }

  bool get _showRegisteredMobileHint {
    if (_successMessage == null) return false;
    final mobile = widget.initialMobile ?? _lockedMobile;
    return mobile != null && mobile.isNotEmpty;
  }

  String? get _registeredMobileForHint =>
      widget.initialMobile ?? _lockedMobile;

  Future<void> _clearStaleDeviceRegistration() async {
    await ref.read(deviceAuthStorageProvider).clearRegisteredMobile();
    if (!mounted) return;
    setState(() => _lockedMobile = null);
  }

  bool _isNoAccountError(String message) {
    return message.toLowerCase().contains('no account found');
  }

  String _noAccountErrorMessage() => context.l10n.loginNoAccountFound;

  bool _isInvalidOtpError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('invalid otp') ||
        lower.contains('incorrect otp') ||
        (lower.contains('invalid') && lower.contains('otp'));
  }

  String _loginErrorMessage(ApiException error) {
    if (_isNoAccountError(error.message)) {
      return _noAccountErrorMessage();
    }
    if (_isInvalidOtpError(error.message)) {
      return context.l10n.loginOtpIncorrect;
    }
    return error.message;
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.successMessage != oldWidget.successMessage) {
      _successMessage = widget.successMessage;
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _normalizeMobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return digits;
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
      _otpMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).sendLoginOtp(mobile);
      if (mounted) {
        setState(() {
          _otpSent = true;
          _otpMessage = 'OTP sent to +91 $mobile. Check your SMS.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (_isNoAccountError(e.message)) {
          await _clearStaleDeviceRegistration();
        }
        setState(() {
          _errorMessage = _isNoAccountError(e.message)
              ? _noAccountErrorMessage()
              : e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not send OTP. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final mobile = _normalizeMobile(_mobileController.text.trim());
    final isAdminLogin = _isAdminMobile(mobile);

    try {
      await ref.read(appAudienceProvider.notifier).setAudience(
            isAdminLogin ? AppAudience.staffAdmin : AppAudience.endUser,
          );
      if (_showTrustedFirstLogin) {
        await ref.read(authNotifierProvider.notifier).loginWithTrustedMobile(
              mobile,
            );
      } else {
        final otp = _otpController.text.trim();
        if (otp.length != 6) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Enter the 6-digit OTP sent to your mobile.';
          });
          return;
        }
        await ref.read(authNotifierProvider.notifier).loginWithMobile(
              mobile,
              otp,
            );
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (_isNoAccountError(e.message)) {
          await _clearStaleDeviceRegistration();
        }
        setState(() => _errorMessage = _loginErrorMessage(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: _buildLoginForm(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final theme = Theme.of(context);
    final l10n = context.l10n;
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/ags_logo.png',
                      width: 320,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.secureEnterprisePortal,
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
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildLoginForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ResponsiveLayout.isMobile(context)) ...[
            Center(
              child: Image.asset(
                'assets/images/ags_logo.png',
                width: 240,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),
          ],
          Text(
            l10n.welcomeBack,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.endUserSignInSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_otpMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sms_outlined, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _otpMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_showRegisteredMobileHint || _showTrustedFirstLogin) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _showTrustedFirstLogin
                          ? 'First sign-in for '
                              '${maskMobileNumber(_registeredMobileForHint ?? _mobileController.text.trim())} '
                              'on this device — tap Sign In without OTP.'
                          : 'You signed up on this device with '
                              '${maskMobileNumber(_registeredMobileForHint!)}. '
                              'OTP will be sent to the number you enter below.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            l10n.mobileNumber,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('mobileField'),
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  textInputAction: _showTrustedFirstLogin
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onChanged: (_) {
                    setState(() {
                      if (_otpSent) {
                        _otpSent = false;
                        _otpMessage = null;
                      }
                    });
                  },
                  onFieldSubmitted: (_) {
                    if (_showTrustedFirstLogin) {
                      _handleLogin();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: l10n.tenDigitMobileLogin,
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
              if (!_showTrustedFirstLogin) ...[
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('sendLoginOtpButton'),
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
            ],
          ),
          if (!_showTrustedFirstLogin) ...[
            const SizedBox(height: 8),
            Text(
              l10n.enterOtp,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextFormField(
              key: const Key('loginOtpField'),
              controller: _otpController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onFieldSubmitted: (_) => _handleLogin(),
              decoration: InputDecoration(
                hintText: l10n.otpFromSms,
                prefixIcon: const Icon(Icons.sms_outlined),
                counterText: '',
              ),
              validator: (value) {
                if (_showTrustedFirstLogin) return null;
                if (value == null || value.trim().length != 6) {
                  return l10n.enterSixDigitOtp;
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            key: const Key('loginButton'),
            onPressed: _isLoading ? null : _handleLogin,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(l10n.signIn),
          ),
          if (_lockedMobile == null) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                key: const Key('goToSignupLink'),
                onPressed: () => context.go('/signup'),
                child: Text(l10n.dontHaveAccountSignUp),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
