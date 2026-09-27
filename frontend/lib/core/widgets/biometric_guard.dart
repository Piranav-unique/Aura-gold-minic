import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/services/biometric_auth_service.dart';
import 'package:ags_gold/services/service_providers.dart';

class BiometricGuard extends ConsumerStatefulWidget {
  final Widget child;

  const BiometricGuard({super.key, required this.child});

  @override
  ConsumerState<BiometricGuard> createState() => _BiometricGuardState();
}

class _BiometricGuardState extends ConsumerState<BiometricGuard>
    with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isAuthenticating = false;
  DateTime? _pausedAt;
  AuthStatus? _lastAuthStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the biometric dialog itself caused the lifecycle transition, ignore it
    if (_isAuthenticating) return;

    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final paused = _pausedAt;
      _pausedAt = null;
      if (paused != null) {
        final elapsed = DateTime.now().difference(paused);
        // Lock if backgrounded for more than 2 seconds (e.g. switched apps or screen locked)
        if (elapsed.inSeconds >= 2) {
          final isEnabled = ref.read(biometricLockEnabledProvider).value ?? false;
          final isAuthenticated =
              ref.read(authNotifierProvider).value == AuthStatus.authenticated;
          if (isEnabled && isAuthenticated) {
            setState(() {
              _isUnlocked = false;
            });
            _triggerAuthentication();
          }
        }
      }
    }
  }

  Future<void> _triggerAuthentication() async {
    if (_isAuthenticating || _isUnlocked) return;

    _isAuthenticating = true;
    try {
      final service = ref.read(biometricServiceProvider);
      final success = await service.authenticate(
        localizedReason: 'Scan fingerprint, face, or enter PIN to unlock AGS Gold',
      );
      if (mounted) {
        setState(() {
          _isUnlocked = success;
        });
      }
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authNotifierProvider);
    final biometricAsync = ref.watch(biometricLockEnabledProvider);

    // Track authentication state changes (e.g. user just logged in or logged out)
    final currentAuthStatus = authAsync.value;
    if (_lastAuthStatus != currentAuthStatus) {
      if (_lastAuthStatus == AuthStatus.unauthenticated &&
          currentAuthStatus == AuthStatus.authenticated) {
        // User just logged in via OTP/password — session is freshly authenticated
        _isUnlocked = true;
      } else if (currentAuthStatus != AuthStatus.authenticated) {
        _isUnlocked = true;
      }
      _lastAuthStatus = currentAuthStatus;
    }

    // While determining initial auth state or biometric preference, render child directly
    if (authAsync.isLoading || biometricAsync.isLoading) {
      return widget.child;
    }

    final isAuthenticated = currentAuthStatus == AuthStatus.authenticated;
    final isBiometricEnabled = biometricAsync.value ?? false;

    // If user is not logged in or biometric lock is disabled, render child directly
    if (!isAuthenticated || !isBiometricEnabled) {
      return widget.child;
    }

    // If already unlocked, render child
    if (_isUnlocked) {
      return widget.child;
    }

    // Auto-prompt on frame render if not already authenticating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isAuthenticating && !_isUnlocked && mounted) {
        _triggerAuthentication();
      }
    });

    // Show the styled lock screen
    return Scaffold(
      backgroundColor: AppTheme.ctaBlack,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.goldGradient,
                    boxShadow: AppTheme.goldGlowShadow,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 52,
                    color: AppTheme.ctaBlack,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'AGS Gold Locked',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Verify your identity using fingerprint, face unlock, or device PIN to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 36),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.ctaBlack,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _triggerAuthentication,
                  icon: const Icon(Icons.lock_open_rounded, size: 20),
                  label: const Text(
                    'Unlock App',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
