import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ags_gold/features/auth/presentation/login_screen.dart';
import 'package:ags_gold/services/api_client.dart';
import '../mocks/mock_services.dart';
import 'e2e_test_helpers.dart';

void main() {
  late MockApiClient mockApi;
  late MockSecureStorage mockStorage;

  setUp(() {
    mockApi = MockApiClient();
    mockStorage = MockSecureStorage();
    registerFallbackValue(<String, dynamic>{});
    when(() => mockStorage.hasAccessToken()).thenAnswer((_) async => false);
    when(() => mockStorage.clearTokens()).thenAnswer((_) async {});
  });

  testWidgets('E2E login flow: login -> dashboard -> logout', (tester) async {
    when(() => mockApi.post('/auth/logout', data: any(named: 'data')))
        .thenAnswer((_) async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn({'message': 'Successfully logged out'});
      return response;
    });
    when(() => mockStorage.getRefreshToken())
        .thenAnswer((_) async => 'e2e-refresh-token');

    await pumpE2eApp(tester, mockApi: mockApi, mockStorage: mockStorage);
    expect(find.byType(LoginScreen), findsOneWidget);

    await completeLogin(tester, mockApi, mockStorage);
    expect(find.byType(DashboardScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loginButton')), findsOneWidget);
    verify(() => mockStorage.clearTokens()).called(1);
    verify(
      () => mockApi.post('/auth/logout', data: any(named: 'data')),
    ).called(1);
  });
}
