// test/unit/providers_test.dart
// Tests for state notifiers and provider state management logic

import 'package:flutter/material.dart';
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
    SharedPreferences.setMockInitialValues({});
    mockStorage = MockSecureStorage();
    mockApiClient = MockApiClient();
  });

  group('ThemeModeNotifier', () {
    test('initial state is ThemeMode.system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('setThemeMode changes theme mode', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });

  group('UsersSearchQueryNotifier', () {
    test('initial state is empty string', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(usersSearchQueryProvider), '');
    });

    test('state can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(usersSearchQueryProvider.notifier).state = 'john';
      expect(container.read(usersSearchQueryProvider), 'john');
    });
  });

  group('UsersIsActiveFilterNotifier', () {
    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(usersIsActiveFilterProvider), isNull);
    });

    test('can be set to true and false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(usersIsActiveFilterProvider.notifier).state = true;
      expect(container.read(usersIsActiveFilterProvider), true);

      container.read(usersIsActiveFilterProvider.notifier).state = false;
      expect(container.read(usersIsActiveFilterProvider), false);

      container.read(usersIsActiveFilterProvider.notifier).state = null;
      expect(container.read(usersIsActiveFilterProvider), isNull);
    });
  });

  group('UsersIsSuperuserFilterNotifier', () {
    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(usersIsSuperuserFilterProvider), isNull);
    });

    test('state can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(usersIsSuperuserFilterProvider.notifier).state = true;
      expect(container.read(usersIsSuperuserFilterProvider), true);
    });
  });

  group('UsersRoleIdFilterNotifier', () {
    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(usersRoleIdFilterProvider), isNull);
    });

    test('state can be updated to a role id string', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(usersRoleIdFilterProvider.notifier).state = 'role-123';
      expect(container.read(usersRoleIdFilterProvider), 'role-123');
    });
  });

  group('UsersLimitNotifier', () {
    test('initial state is 50', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(usersLimitProvider), 50);
    });

    test('state can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(usersLimitProvider.notifier).state = 100;
      expect(container.read(usersLimitProvider), 100);
    });
  });

  group('UsersSkipNotifier', () {
    test('initial state is 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(usersSkipProvider), 0);
    });

    test('state can be updated for pagination', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(usersSkipProvider.notifier).state = 50;
      expect(container.read(usersSkipProvider), 50);
    });
  });

  group('AuthNotifier - core state transitions', () {
    testWidgets(
      'initial state is loading, resolves to unauthenticated when no token',
      (tester) async {
        when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(mockStorage),
            apiClientProvider.overrideWithValue(mockApiClient),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(authNotifierProvider),
          isA<AsyncLoading<AuthStatus>>(),
        );

        await tester.pump(const Duration(seconds: 2));

        final state = container.read(authNotifierProvider);
        expect(state.value, AuthStatus.unauthenticated);
      },
    );

    testWidgets('resolves to authenticated when token exists', (tester) async {
      when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => true);

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(mockStorage),
          apiClientProvider.overrideWithValue(mockApiClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(authNotifierProvider);
      await tester.pump(const Duration(seconds: 2));

      expect(
        container.read(authNotifierProvider).value,
        AuthStatus.authenticated,
      );
    });

    testWidgets('clearSession clears tokens and sets unauthenticated', (
      tester,
    ) async {
      when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => true);
      when(() => mockStorage.clearTokens()).thenAnswer((_) async => {});

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(mockStorage),
          apiClientProvider.overrideWithValue(mockApiClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(authNotifierProvider);
      await tester.pump(const Duration(seconds: 2));

      await container.read(authNotifierProvider.notifier).clearSession();

      expect(
        container.read(authNotifierProvider).value,
        AuthStatus.unauthenticated,
      );
      verify(() => mockStorage.clearTokens()).called(1);
    });

    testWidgets('login failure rethrows and stores error', (tester) async {
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
      addTearDown(container.dispose);

      container.read(authNotifierProvider);
      await tester.pump(const Duration(seconds: 2));

      final notifier = container.read(authNotifierProvider.notifier);

      expect(
        () => notifier.login('bad@email.com', 'wrong'),
        throwsA(isA<UnauthorizedException>()),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(authNotifierProvider).hasError, isTrue);
    });

    testWidgets('logout proceeds without server call when no refresh token', (
      tester,
    ) async {
      when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => true);
      when(() => mockStorage.getRefreshToken()).thenAnswer((_) async => null);
      when(() => mockStorage.clearTokens()).thenAnswer((_) async => {});

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(mockStorage),
          apiClientProvider.overrideWithValue(mockApiClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(authNotifierProvider);
      await tester.pump(const Duration(seconds: 2));

      await container.read(authNotifierProvider.notifier).logout();

      expect(
        container.read(authNotifierProvider).value,
        AuthStatus.unauthenticated,
      );
      verify(() => mockStorage.clearTokens()).called(1);
      verifyNever(() => mockApiClient.post(any(), data: any(named: 'data')));
    });
  });
}
