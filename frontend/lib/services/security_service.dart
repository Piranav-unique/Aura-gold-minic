import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

class SecurityService {
  static const MethodChannel _channel =
      MethodChannel('com.agsgold.ags_gold/security');

  /// Check if the current device is rooted / jailbroken.
  Future<bool> isDeviceRooted() async {
    if (kIsWeb) return false;
    try {
      final isRooted = await _channel.invokeMethod<bool>('isRooted');
      return isRooted ?? false;
    } on PlatformException catch (e) {
      debugPrint('SecurityService root check error: $e');
      return false;
    } catch (e) {
      debugPrint('SecurityService root check unexpected error: $e');
      return false;
    }
  }

  /// Enable or disable screenshot and screen recording protection (FLAG_SECURE on Android).
  Future<void> setScreenshotProtection(bool enable) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('setSecureFlag', {'enable': enable});
    } on PlatformException catch (e) {
      debugPrint('SecurityService setScreenshotProtection error: $e');
    } catch (e) {
      debugPrint('SecurityService setScreenshotProtection unexpected error: $e');
    }
  }
}
