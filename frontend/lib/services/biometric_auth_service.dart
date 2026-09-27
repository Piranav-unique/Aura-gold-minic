import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kBiometricEnabledKey = 'ags_biometric_lock_enabled';

final biometricServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

final biometricLockEnabledProvider =
    AsyncNotifierProvider<BiometricLockNotifier, bool>(() {
  return BiometricLockNotifier();
});

class BiometricLockNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(biometricServiceProvider).isBiometricEnabled();
  }

  Future<bool> toggle(bool enable) async {
    if (enable) {
      final success = await ref.read(biometricServiceProvider).authenticate(
            localizedReason:
                'Scan your fingerprint, face, or enter device PIN to enable lock',
          );
      if (!success) {
        return false;
      }
    }
    await ref.read(biometricServiceProvider).setBiometricEnabled(enable);
    state = AsyncData(enable);
    return true;
  }
}

class BiometricAuthService {
  final LocalAuthentication _auth;

  BiometricAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported || canCheck;
    } on PlatformException {
      return true; // Let authenticate() handle device verification
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricEnabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabledKey, enabled);
  }

  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access your AGS Gold account',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric authentication unexpected error: $e');
      return false;
    }
  }
}
