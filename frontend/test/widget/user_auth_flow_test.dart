import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ags_gold/features/auth/presentation/signup_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/user_dashboard_screen.dart';
import 'package:ags_gold/l10n/app_localizations.dart';
import 'package:ags_gold/main.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';
import '../test_helpers/auth_dashboard_overrides.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SignupScreen renders registration form', (tester) async {
    final mockDeviceAuth = MockDeviceAuthStorage();
    when(() => mockDeviceAuth.getRegisteredMobile()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthStorageProvider.overrideWithValue(mockDeviceAuth),
        ],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SignupScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('signupButton')), findsOneWidget);
    expect(find.byKey(const Key('verifyMobileButton')), findsOneWidget);
    expect(find.byKey(const Key('verifyOtpButton')), findsOneWidget);
    expect(find.byKey(const Key('otpField')), findsOneWidget);
    expect(find.byKey(const Key('goToLoginLink')), findsOneWidget);
  });

  testWidgets('Signup shows error when Sign Up tapped without OTP verify', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockDeviceAuth = MockDeviceAuthStorage();
    when(() => mockDeviceAuth.getRegisteredMobile()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthStorageProvider.overrideWithValue(mockDeviceAuth),
        ],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SignupScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('signupButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signupButton')));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.text('Name is required.'), findsWidgets);

    await tester.enterText(find.byKey(const Key('nameField')), 'Test User');
    await tester.enterText(find.byKey(const Key('mobileField')), '9876543210');
    await tester.ensureVisible(find.byKey(const Key('signupButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signupButton')));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
    expect(
      find.text('Tap Send OTP to receive a code on your mobile number.'),
      findsOneWidget,
    );
  });

  testWidgets('User flow: login lands on user dashboard', (tester) async {
    final mockApi = MockApiClient();
    final mockStorage = MockSecureStorage();
    final mockDeviceAuth = MockDeviceAuthStorage();

    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);
    when(() => mockDeviceAuth.getRegisteredMobile()).thenAnswer((_) async => null);
    when(
      () => mockDeviceAuth.getOrCreateDeviceId(),
    ).thenAnswer((_) async => '11111111-1111-4111-8111-111111111111');
    when(
      () => mockDeviceAuth.saveRegisteredMobile(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});

    final mockLoginResponse = MockResponse<Map<String, dynamic>>();
    when(() => mockLoginResponse.data).thenReturn({
      'access_token': 'user-access-token',
      'refresh_token': 'user-refresh-token',
    });
    final mockOtpSendResponse = MockResponse<Map<String, dynamic>>();
    when(() => mockOtpSendResponse.data).thenReturn({'message': 'ok'});
    when(
      () => mockApi.post('/auth/login/otp/send', data: any(named: 'data')),
    ).thenAnswer((_) async => mockOtpSendResponse);
    when(
      () => mockApi.post('/auth/login/mobile', data: any(named: 'data')),
    ).thenAnswer((_) async => mockLoginResponse);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          secureStorageProvider.overrideWithValue(mockStorage),
          deviceAuthStorageProvider.overrideWithValue(mockDeviceAuth),
          ...userDashboardTestOverrides,
        ],
        child: const AGSGoldApp(),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    if (find.byKey(const Key('endUserCard')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('endUserCard')));
      await tester.pumpAndSettle();
    }

    if (find.byKey(const Key('goToLoginLink')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('goToLoginLink')));
      await tester.pumpAndSettle();
    }

    await tester.enterText(
      find.byKey(const Key('mobileField')),
      '9876543210',
    );
    await tester.tap(find.byKey(const Key('sendLoginOtpButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('loginOtpField')), '123456');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();

    expect(find.byType(UserDashboardScreen), findsOneWidget);
  });
}
