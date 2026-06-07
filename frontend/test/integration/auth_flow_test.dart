// test/integration/auth_flow_test.dart
// End-to-end auth flow test using the real widget tree with mocked providers.
// Runs via `flutter test` (no device needed).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/main.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/kpi_provider.dart';
import 'package:ags_gold/features/dashboard/domain/kpi.dart';
import '../mocks/mock_services.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(const MethodChannel(''));
  });

  testWidgets('Full auth flow: unauthenticated -> login -> dashboard', (WidgetTester tester) async {
    final mockApi = MockApiClient();
    final mockStorage = MockSecureStorage();
    const testEmail = 'user@example.com';
    const testPassword = 'Password123';
    const fakeToken = 'fake-jwt-token';

    // Storage starts empty (unauthenticated)
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);
    when(() => mockStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});

    // Use a Completer to control when the login API call resolves
    final loginCompleter = Completer<MockResponse<Map<String, dynamic>>>();
    final mockLoginResponse = MockResponse<Map<String, dynamic>>();
    when(() => mockLoginResponse.data).thenReturn({
      'access_token': fakeToken,
      'refresh_token': 'fake-refresh-token',
    });

    when(() => mockApi.post('/auth/login', data: any(named: 'data')))
        .thenAnswer((_) => loginCompleter.future);

    // Mock any GET calls (audit logs, dashboard data, etc.)
    final mockListResponse = MockResponse<List<dynamic>>();
    when(() => mockListResponse.data).thenReturn([]);
    when(() => mockApi.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => mockListResponse);

    final mockKpis = [
      const Kpi(id: 'vault', title: 'Total Gold Vault', value: '142.84 kg'),
      const Kpi(id: 'users', title: 'Active Users', value: '24 Users'),
      const Kpi(id: 'health', title: 'System Health', value: 'Optimal'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          secureStorageProvider.overrideWithValue(mockStorage),
          kpiProvider.overrideWithValue(mockKpis),
          auditLogsProvider.overrideWithValue(const AsyncValue.data([])),
        ],
        child: const AGSGoldApp(),
      ),
    );

    // Initial pump — splash / loading state
    await tester.pump();
    // Skip the 2-second artificial splash delay in AuthNotifier
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify we are on the Login screen
    expect(find.byKey(const Key('loginButton')), findsOneWidget);

    // Enter credentials
    await tester.enterText(find.byKey(const Key('emailField')), testEmail);
    await tester.enterText(find.byKey(const Key('passwordField')), testPassword);

    // Tap Login
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump(); // start async login

    // Should show loading indicator while API call is in-flight
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the API call
    loginCompleter.complete(mockLoginResponse);
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify we navigated to Dashboard
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Verify tokens were saved
    verify(() => mockStorage.saveTokens(
          accessToken: fakeToken,
          refreshToken: 'fake-refresh-token',
        )).called(1);
  });

  testWidgets('Auth flow: already authenticated -> goes directly to dashboard', (WidgetTester tester) async {
    final mockApi = MockApiClient();
    final mockStorage = MockSecureStorage();

    // Storage has a token (authenticated)
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => true);

    final mockListResponse = MockResponse<List<dynamic>>();
    when(() => mockListResponse.data).thenReturn([]);
    when(() => mockApi.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => mockListResponse);

    final mockKpis = [
      const Kpi(id: 'vault', title: 'Total Gold Vault', value: '142.84 kg'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          secureStorageProvider.overrideWithValue(mockStorage),
          kpiProvider.overrideWithValue(mockKpis),
          auditLogsProvider.overrideWithValue(const AsyncValue.data([])),
        ],
        child: const AGSGoldApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Should go directly to Dashboard — no login screen
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byKey(const Key('loginButton')), findsNothing);
  });

  testWidgets('Login form shows validation errors on empty submit', (WidgetTester tester) async {
    final mockApi = MockApiClient();
    final mockStorage = MockSecureStorage();
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          secureStorageProvider.overrideWithValue(mockStorage),
        ],
        child: const AGSGoldApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // On login screen, tap submit without entering anything
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();

    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });
}
