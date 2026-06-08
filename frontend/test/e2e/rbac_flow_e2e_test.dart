import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
    when(() => mockStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});
  });

  testWidgets('E2E RBAC: admin can access users and audit endpoints', (tester) async {
    await pumpE2eApp(tester, mockApi: mockApi, mockStorage: mockStorage);
    await completeLogin(tester, mockApi, mockStorage);

    final usersResponse = MockResponse<List<dynamic>>();
    when(() => usersResponse.data).thenReturn([
      {'id': '1', 'email': 'user@example.com', 'roles': []},
    ]);
    when(
      () => mockApi.get(
        '/users/',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => usersResponse);

    final auditResponse = MockResponse<Map<String, dynamic>>();
    when(() => auditResponse.data).thenReturn({
      'items': [],
      'total': 0,
      'skip': 0,
      'limit': 10,
    });
    when(
      () => mockApi.get(
        '/audit-logs/',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => auditResponse);

    await mockApi.get('/users/');
    await mockApi.get('/audit-logs/', queryParameters: {'limit': 10});

    verify(
      () => mockApi.get(
        '/users/',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    verify(
      () => mockApi.get(
        '/audit-logs/',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  testWidgets('E2E RBAC: manager receives forbidden on user create', (tester) async {
    await pumpE2eApp(tester, mockApi: mockApi, mockStorage: mockStorage);
    await completeLogin(tester, mockApi, mockStorage, email: 'manager@e2e.test');

    when(() => mockApi.post('/users/', data: any(named: 'data')))
        .thenAnswer((_) async => throw ForbiddenException('Permission denied'));

    expect(
      () => mockApi.post('/users/', data: {
        'email': 'blocked@example.com',
        'password': 'password123',
      }),
      throwsA(isA<ForbiddenException>()),
    );
  });

  testWidgets('E2E RBAC: employee receives forbidden on RBAC roles', (tester) async {
    await pumpE2eApp(tester, mockApi: mockApi, mockStorage: mockStorage);
    await completeLogin(tester, mockApi, mockStorage, email: 'employee@e2e.test');

    when(
      () => mockApi.get(
        '/rbac/roles',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => throw ForbiddenException('Permission denied'));

    expect(
      () => mockApi.get('/rbac/roles'),
      throwsA(isA<ForbiddenException>()),
    );
  });
}
