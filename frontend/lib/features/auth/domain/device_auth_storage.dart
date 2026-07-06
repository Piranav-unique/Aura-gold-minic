import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the mobile number and device identifier for end-user auth.
abstract class IDeviceAuthStorage {
  Future<String?> getRegisteredMobile();

  Future<void> saveRegisteredMobile(String mobile);

  Future<void> clearRegisteredMobile();

  Future<void> markPendingTrustedFirstLogin();

  Future<bool> isPendingTrustedFirstLogin();

  Future<void> clearPendingTrustedFirstLogin();

  Future<String> getOrCreateDeviceId();
}

class DeviceAuthStorage implements IDeviceAuthStorage {
  DeviceAuthStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _mobileKey = 'device_registered_mobile';
  static const _deviceIdKey = 'device_id';
  static const _pendingTrustedFirstLoginKey = 'pending_trusted_first_login';

  @override
  Future<String?> getRegisteredMobile() async {
    final value = await _storage.read(key: _mobileKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> saveRegisteredMobile(String mobile) async {
    await _storage.write(key: _mobileKey, value: mobile);
  }

  @override
  Future<void> clearRegisteredMobile() async {
    await _storage.delete(key: _mobileKey);
  }

  @override
  Future<void> markPendingTrustedFirstLogin() async {
    await _storage.write(key: _pendingTrustedFirstLoginKey, value: 'true');
  }

  @override
  Future<bool> isPendingTrustedFirstLogin() async {
    final value = await _storage.read(key: _pendingTrustedFirstLoginKey);
    return value == 'true';
  }

  @override
  Future<void> clearPendingTrustedFirstLogin() async {
    await _storage.delete(key: _pendingTrustedFirstLoginKey);
  }

  @override
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = _generateUuidV4();
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }
}

String _generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

String maskMobileNumber(String mobile) {
  final digits = mobile.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return digits;
  return 'XXXXXX${digits.substring(digits.length - 4)}';
}
