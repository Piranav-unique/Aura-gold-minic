// test/widget/login_screen_test.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/auth/presentation/login_screen.dart';
import 'package:ags_gold/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/main.dart';
import '../mocks/mock_services.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(const MethodChannel(''));
  });

  testWidgets('LoginScreen renders and displays validation errors', (WidgetTester tester) async {
    final mockApi = MockApiClient();
    final mockStorage = MockSecureStorage();

    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          secureStorageProvider.overrideWithValue(mockStorage),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify initial components
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign In'), findsOneWidget);

    // Tap login button to trigger validation
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();

    // Verify validation messages are displayed
    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);

    // Enter invalid email
    await tester.enterText(find.byKey(const Key('emailField')), 'invalid-email');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('LoginScreen successful login redirects using AGSGoldApp', (WidgetTester tester) async {
    final mockApi = MockApiClient();
    final mockStorage = MockSecureStorage();
    const testEmail = 'user@example.com';
    const testPassword = 'Password123';
    const fakeToken = 'fake-jwt-token';

    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);
    when(() => mockStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async => {});

    final mockResponse = MockResponse<Map<String, dynamic>>();
    when(() => mockResponse.data).thenReturn({
      'access_token': fakeToken,
      'refresh_token': 'fake-refresh-token',
    });

    // Use a Completer to halt execution during API call and verify the loading indicator
    final completer = Completer<MockResponse<Map<String, dynamic>>>();
    when(() => mockApi.post('/auth/login', data: any(named: 'data')))
        .thenAnswer((_) => completer.future);

    // Mock audit logs request triggered on dashboard
    final mockLogsResponse = MockResponse<List<dynamic>>();
    when(() => mockLogsResponse.data).thenReturn([]);
    when(() => mockApi.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => mockLogsResponse);

    // Build the full app with route integration
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          secureStorageProvider.overrideWithValue(mockStorage),
        ],
        child: const AGSGoldApp(),
      ),
    );

    // Splash screen is displayed first
    await tester.pump();
    // Wait for the 2-second Splash delay in AuthNotifier to resolve
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Now we should be on LoginScreen
    expect(find.byKey(const Key('loginButton')), findsOneWidget);

    // Input email and password
    await tester.enterText(find.byKey(const Key('emailField')), testEmail);
    await tester.enterText(find.byKey(const Key('passwordField')), testPassword);

    // Tap sign in
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump(); // start login request

    // Verify loading indicator is displayed
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the API call
    completer.complete(mockResponse);
    await tester.pump(); // process the completed future
    await tester.pumpAndSettle(); // wait for routing navigation to complete

    // Verify redirection to Dashboard
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
