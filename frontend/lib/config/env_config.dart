import 'package:flutter/foundation.dart';

import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart' as platform;

enum AppEnvironment { dev, prod }

class EnvConfig {
  final AppEnvironment environment;
  final String baseUrl;
  final Duration connectionTimeout;
  final Duration receiveTimeout;

  EnvConfig({
    required this.environment,
    required this.baseUrl,
    this.connectionTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
  });

  static String get _devBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  static final EnvConfig dev = EnvConfig(
    environment: AppEnvironment.dev,
    baseUrl: _devBaseUrl,
  );

  static final EnvConfig prod = EnvConfig(
    environment: AppEnvironment.prod,
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.agsgold.com/api/v1',
    ),
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
