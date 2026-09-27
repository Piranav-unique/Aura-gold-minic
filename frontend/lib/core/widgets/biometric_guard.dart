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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAuthenticate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final paused = _pausedAt;
      if (paused != null) {
        final elapsed = DateTime.now().difference(paused);
        // Lock after 45 seconds in the background
        if (elapsed.inSeconds > 45) {
          setState(() {
            _isUnlocked = false;
          });
          _checkAndAuthenticate();
        }
      }
    }
  }

  Future<void> _checkAndAuthenticate() async {
    final authState = ref.read(authNotifierProvider).value;
    final isBiometricEnabled = ref.read(biometricLockEnabledProvider);

    if (authState != AuthStatus.authenticated || !isBiometricEnabled) {
      if (!_isUnlocked) {
        setState(() {
          _isUnlocked = true;
        });
      }
      return;
    }

    if (_isUnlocked || _isAuthenticating) return;

    _isAuthenticating = true;
    final service = ref.read(biometricServiceProvider);
    final success = await service.authenticate(
      localizedReason: 'Scan fingerprint or Face ID to unlock AGS Gold',
    );
    _isAuthenticating = false;

    if (mounted) {
      setState(() {
        _isUnlocked = success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).value;
    final isBiometricEnabled = ref.watch(biometricLockEnabledProvider);

    // If not authenticated or biometric lock is disabled, render child directly
    if (authState != AuthStatus.authenticated || !isBiometricEnabled || _isUnlocked) {
      return widget.child;
    }

    // Otherwise show the secure biometric lock screen
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
                  onPressed: _checkAndAuthenticate,
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
