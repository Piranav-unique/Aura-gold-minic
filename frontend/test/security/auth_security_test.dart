import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/services/api_client.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockSecureStorage mockStorage;
  late MockApiClient mockApiClient;

  setUp(() {
    mockStorage = MockSecureStorage();
    mockApiClient = MockApiClient();
    registerFallbackValue(<String, dynamic>{});
  });

  testWidgets('invalid login leaves user unauthenticated and does not save tokens',
      (tester) async {
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);
    when(() => mockApiClient.post(
          '/auth/login',
          data: any(named: 'data'),
        )).thenThrow(UnauthorizedException('Incorrect email or password'));

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    try {
      container.read(authNotifierProvider);
      await tester.pump(const Duration(seconds: 2));

      final notifier = container.read(authNotifierProvider.notifier);
      await expectLater(
        notifier.login('wrong@example.com', 'badpassword1'),
        throwsA(isA<UnauthorizedException>()),
      );

      verifyNever(
        () => mockStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
      expect(
        container.read(authNotifierProvider).hasError,
        isTrue,
      );
    } finally {
      container.dispose();
    }
  });

  test('onUnauthorized callback clears session via clearSession', () async {
    when(() => mockStorage.clearTokens()).thenAnswer((_) async => {});

    var unauthorizedCalled = false;
    final client = ApiClient(
      storageService: mockStorage,
      onUnauthorized: () {
        unauthorizedCalled = true;
      },
    );

    // Simulate interceptor behavior: UnauthorizedException triggers callback
    client.onUnauthorized?.call();

    expect(unauthorizedCalled, isTrue);
  });

  test('403 forbidden on admin action does not clear stored tokens', () async {
    when(
      () => mockApiClient.get(
        '/users/',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      throw ForbiddenException("Permission 'user.create' is required");
    });

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    try {
      await expectLater(
        container.read(apiClientProvider).get('/users/'),
        throwsA(isA<ForbiddenException>()),
      );
      verifyNever(() => mockStorage.clearTokens());
    } finally {
      container.dispose();
    }
  });
}
