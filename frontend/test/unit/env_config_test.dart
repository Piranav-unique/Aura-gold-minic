import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/config/env_config.dart';

void main() {
  group('EnvConfig Tests', () {
    // Release builds must never fall back to dev settings when ENV is not
    // passed, so the active environment defaults to prod.
    test('Default active environment is AppEnvironment.prod', () {
      final config = EnvConfig.active;
      expect(config.environment, AppEnvironment.prod);
      expect(config.baseUrl, EnvConfig.hostedApiBaseUrl);
    });

    test('EnvConfig dev has correct defaults', () {
      final devConfig = EnvConfig.dev;
      expect(devConfig.environment, AppEnvironment.dev);
      expect(devConfig.baseUrl, contains('8000'));
      expect(devConfig.connectionTimeout.inSeconds, 20);
      expect(devConfig.receiveTimeout.inSeconds, 45);
    });

    test('EnvConfig prod has correct defaults', () {
      final prodConfig = EnvConfig.prod;
      expect(prodConfig.environment, AppEnvironment.prod);
      expect(prodConfig.baseUrl, EnvConfig.hostedApiBaseUrl);
    });
  });
}
