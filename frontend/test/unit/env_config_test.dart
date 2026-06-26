import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/config/env_config.dart';

void main() {
  group('EnvConfig Tests', () {
    test('Default active environment is AppEnvironment.dev', () {
      final config = EnvConfig.active;
      expect(config.environment, AppEnvironment.dev);
      expect(config.baseUrl, contains('8000'));
    });

    test('EnvConfig dev has correct defaults', () {
      final devConfig = EnvConfig.dev;
      expect(devConfig.environment, AppEnvironment.dev);
      expect(devConfig.connectionTimeout.inSeconds, 15);
      expect(devConfig.receiveTimeout.inSeconds, 15);
    });

    test('EnvConfig prod has correct defaults', () {
      final prodConfig = EnvConfig.prod;
      expect(prodConfig.environment, AppEnvironment.prod);
      expect(prodConfig.baseUrl, EnvConfig.hostedApiBaseUrl);
    });
  });
}
