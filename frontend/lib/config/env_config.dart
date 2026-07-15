import 'package:flutter/foundation.dart';

import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart' as platform;

enum AppEnvironment { dev, prod }

class EnvConfig {
  /// Hosted backend on Railway (used by default on Android / release builds).
  static const String hostedApiBaseUrl =
      'https://aura-gold-minic-production.up.railway.app/api/v1';
  static const String adminMobileNumber = String.fromEnvironment(
    'ADMIN_MOBILE_NUMBER',
    defaultValue: '9943795005',
  );

  final AppEnvironment environment;
  final String baseUrl;
  final String adminNumber;
  final Duration connectionTimeout;
  final Duration receiveTimeout;

  EnvConfig({
    required this.environment,
    required this.baseUrl,
    required this.adminNumber,
    this.connectionTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
  });

  static String get _devBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && platform.isAndroid) {
      // Local backend: flutter run --dart-define=API_HOST=<your-pc-lan-ip>
      const host = String.fromEnvironment('API_HOST');
      if (host.isNotEmpty) {
        return 'http://$host:8000/api/v1';
      }
      return hostedApiBaseUrl;
    }
    return 'http://localhost:8000/api/v1';
  }

  static final EnvConfig dev = EnvConfig(
    environment: AppEnvironment.dev,
    baseUrl: _devBaseUrl,
    adminNumber: adminMobileNumber,
  );

  static final EnvConfig prod = EnvConfig(
    environment: AppEnvironment.prod,
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: hostedApiBaseUrl,
    ),
    adminNumber: adminMobileNumber,
  );

  static EnvConfig get active {
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    switch (env) {
      case 'prod':
        return prod;
      case 'dev':
      default:
        return dev;
    }
  }
}
