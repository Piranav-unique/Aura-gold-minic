import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/presentation/login_screen.dart';
import 'package:ags_gold/features/auth/presentation/providers/app_audience_provider.dart';
import 'package:ags_gold/l10n/app_localizations.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

class _FixedEndUserAudience extends AppAudienceNotifier {
  @override
  AppAudience? build() => AppAudience.endUser;
}

void main() {
  testWidgets('Login rejects a different mobile when device is bound', (
    tester,
  ) async {
    final mockDeviceAuth = MockDeviceAuthStorage();
    const boundMobile = '9876543210';

    when(
      () => mockDeviceAuth.getRegisteredMobile(),
    ).thenAnswer((_) async => boundMobile);
    when(
      () => mockDeviceAuth.getOrCreateDeviceId(),
    ).thenAnswer((_) async => '11111111-1111-4111-8111-111111111111');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthStorageProvider.overrideWithValue(mockDeviceAuth),
          appAudienceProvider.overrideWith(() => _FixedEndUserAudience()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('OTP will be sent'), findsOneWidget);
    expect(find.byKey(const Key('goToSignupLink')), findsNothing);
    expect(find.byKey(const Key('mobileField')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('mobileField')), '9123456789');
    expect(find.text('9123456789'), findsOneWidget);
  });
}
