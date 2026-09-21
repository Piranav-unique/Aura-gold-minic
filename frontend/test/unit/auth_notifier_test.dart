import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  testWidgets(
    'AuthNotifier - initial state unauthenticated when no token exists',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(mockStorage),
          apiClientProvider.overrideWithValue(mockApiClient),
        ],
      );

      try {
        final status = await container.read(authNotifierProvider.future);
        expect(status, AuthStatus.unauthenticated);
        verify(() => mockStorage.hasAccessToken()).called(1);
      } finally {
        container.dispose();
      }
    },
  );

  testWidgets('AuthNotifier - initial state authenticated when token exists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => true);
    when(() => mockApiClient.get('/auth/me')).thenAnswer((_) async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn(<String, dynamic>{});
      return response;
    });
    when(() => mockApiClient.get('/profile/')).thenAnswer((_) async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn({
        'id': '1',
        'email': 'test@example.com',
        'mobile_number': '9943795005',
        'is_active': true,
        'is_superuser': false,
        'roles': <Map<String, dynamic>>[],
        'created_at': '2026-01-01T00:00:00Z',
      });
      return response;
    });

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    try {
      final status = await container.read(authNotifierProvider.future);
      expect(status, AuthStatus.authenticated);
    } finally {
      container.dispose();
    }
  });

  testWidgets(
    'AuthNotifier - login success saves tokens and transitions state',
    (tester) async {
      when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);
      when(
        () => mockStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async => {});

      final mockResponse = MockResponse<Map<String, dynamic>>();
      when(() => mockResponse.data).thenReturn({
        'access_token': 'mock_access_token',
        'refresh_token': 'mock_refresh_token',
      });

      when(
        () => mockApiClient.post('/auth/login', data: any(named: 'data')),
      ).thenAnswer((_) async => mockResponse);

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
        final future = notifier.login(
          email: 'test@example.com',
          password: 'password123',
        );

        // State transition to loading during login
        expect(
          container.read(authNotifierProvider),
          isA<AsyncLoading<AuthStatus>>(),
        );

        await future;

        expect(
          container.read(authNotifierProvider).value,
          AuthStatus.authenticated,
        );
        verify(
          () => mockStorage.saveTokens(
            accessToken: 'mock_access_token',
            refreshToken: 'mock_refresh_token',
          ),
        ).called(1);
      } finally {
        container.dispose();
      }
    },
  );

  testWidgets('AuthNotifier - login failure sets error state and rethrows', (
    tester,
  ) async {
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);
    when(
      () => mockApiClient.post('/auth/login', data: any(named: 'data')),
    ).thenThrow(UnauthorizedException('Invalid credentials'));

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
        () => notifier.login(email: 'wrong@example.com', password: 'badpassword'),
        throwsA(isA<UnauthorizedException>()),
      );

      // After failure, state should hold error
      expect(container.read(authNotifierProvider).hasError, isTrue);
    } finally {
      container.dispose();
    }
  });

  testWidgets(
    'AuthNotifier - logout clears tokens locally and calls server API',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => true);
      when(
        () => mockStorage.getRefreshToken(),
      ).thenAnswer((_) async => 'mock_refresh_token');
      when(() => mockStorage.clearTokens()).thenAnswer((_) async => {});
      when(() => mockApiClient.get('/auth/me')).thenAnswer((_) async {
        final response = MockResponse<Map<String, dynamic>>();
        when(() => response.data).thenReturn({
          'id': '1',
          'email': 'test@example.com',
          'mobile_number': '9943795005',
          'is_active': true,
          'is_superuser': false,
          'roles': <Map<String, dynamic>>[],
          'created_at': '2026-01-01T00:00:00Z',
        });
        return response;
      });

      final mockDeviceAuth = MockDeviceAuthStorage();
      when(() => mockDeviceAuth.clearRegisteredMobile())
          .thenAnswer((_) async {});
      when(() => mockDeviceAuth.clearPendingTrustedFirstLogin())
          .thenAnswer((_) async {});

      final mockResponse = MockResponse<dynamic>();
      when(
        () => mockApiClient.post('/auth/logout', data: any(named: 'data')),
      ).thenAnswer((_) async => mockResponse);

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(mockStorage),
          apiClientProvider.overrideWithValue(mockApiClient),
          deviceAuthStorageProvider.overrideWithValue(mockDeviceAuth),
        ],
      );

      try {
        // Trigger build
        container.read(authNotifierProvider);

        await tester.pump(const Duration(seconds: 2));

        final notifier = container.read(authNotifierProvider.notifier);
        await notifier.logout();

        expect(
          container.read(authNotifierProvider).value,
          AuthStatus.unauthenticated,
        );
        verify(() => mockStorage.clearTokens()).called(greaterThanOrEqualTo(1));
        verify(() => mockDeviceAuth.clearRegisteredMobile()).called(1);
        verify(() => mockDeviceAuth.clearPendingTrustedFirstLogin()).called(1);
        verify(
          () => mockApiClient.post(
            '/auth/logout',
            data: {'refresh_token': 'mock_refresh_token'},
          ),
        ).called(1);
      } finally {
        container.dispose();
      }
    },
  );
}
