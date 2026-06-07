import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/services/api_client.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockSecureStorage mockStorage;
  late MockApiClient mockApiClient;

  setUp(() {
    mockStorage = MockSecureStorage();
    mockApiClient = MockApiClient();
  });

  testWidgets('AuthNotifier - initial state unauthenticated when no token exists', (tester) async {
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    try {
      // Trigger build and timer initialization
      expect(
        container.read(authNotifierProvider),
        isA<AsyncLoading<AuthStatus>>(),
      );

      // Wait for the 2-second artificial delay to resolve
      await tester.pump(const Duration(seconds: 2));

      final state = container.read(authNotifierProvider);
      expect(state.value, AuthStatus.unauthenticated);
      verify(() => mockStorage.hasAccessToken()).called(1);
    } finally {
      container.dispose();
    }
  });

  testWidgets('AuthNotifier - initial state authenticated when token exists', (tester) async {
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => true);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    try {
      // Trigger build
      container.read(authNotifierProvider);
      
      await tester.pump(const Duration(seconds: 2));

      final state = container.read(authNotifierProvider);
      expect(state.value, AuthStatus.authenticated);
    } finally {
      container.dispose();
    }
  });

  testWidgets('AuthNotifier - login success saves tokens and transitions state', (tester) async {
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);
    when(() => mockStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async => {});

    final mockResponse = MockResponse<Map<String, dynamic>>();
    when(() => mockResponse.data).thenReturn({
      'access_token': 'mock_access_token',
      'refresh_token': 'mock_refresh_token',
    });

    when(() => mockApiClient.post(
          '/auth/login',
          data: any(named: 'data'),
        )).thenAnswer((_) async => mockResponse);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    try {
      // Trigger build
      container.read(authNotifierProvider);
      
      await tester.pump(const Duration(seconds: 2));

      final notifier = container.read(authNotifierProvider.notifier);
      final future = notifier.login('test@example.com', 'password123');

      // State transition to loading during login
      expect(container.read(authNotifierProvider), isA<AsyncLoading<AuthStatus>>());

      await future;

      expect(container.read(authNotifierProvider).value, AuthStatus.authenticated);
      verify(() => mockStorage.saveTokens(
            accessToken: 'mock_access_token',
            refreshToken: 'mock_refresh_token',
          )).called(1);
    } finally {
      container.dispose();
    }
  });

  testWidgets('AuthNotifier - login failure sets error state and rethrows', (tester) async {
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);
    when(() => mockApiClient.post(
          '/auth/login',
          data: any(named: 'data'),
        )).thenThrow(UnauthorizedException('Invalid credentials'));

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    try {
      // Trigger build
      container.read(authNotifierProvider);
      
      await tester.pump(const Duration(seconds: 2));

      final notifier = container.read(authNotifierProvider.notifier);
      
      expect(
        () => notifier.login('wrong@example.com', 'badpassword'),
        throwsA(isA<UnauthorizedException>()),
      );

      // After failure, state should hold error
      expect(container.read(authNotifierProvider).hasError, isTrue);
    } finally {
      container.dispose();
    }
  });

  testWidgets('AuthNotifier - logout clears tokens locally and calls server API', (tester) async {
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => true);
    when(() => mockStorage.getRefreshToken()).thenAnswer((_) async => 'mock_refresh_token');
    when(() => mockStorage.clearTokens()).thenAnswer((_) async => {});
    
    final mockResponse = MockResponse<dynamic>();
    when(() => mockApiClient.post(
          '/auth/logout',
          data: any(named: 'data'),
        )).thenAnswer((_) async => mockResponse);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    try {
      // Trigger build
      container.read(authNotifierProvider);
      
      await tester.pump(const Duration(seconds: 2));

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.logout();

      expect(container.read(authNotifierProvider).value, AuthStatus.unauthenticated);
      verify(() => mockStorage.clearTokens()).called(1);
      verify(() => mockApiClient.post(
            '/auth/logout',
            data: {'refresh_token': 'mock_refresh_token'},
          )).called(1);
    } finally {
      container.dispose();
    }
  });
}
