import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/config/env_config.dart';
import 'package:ags_gold/services/api_client.dart';
import '../mocks/mock_services.dart';

EnvConfig _testConfig() => EnvConfig(
      environment: AppEnvironment.dev,
      baseUrl: 'http://localhost:8000',
      connectionTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    );

void main() {
  late MockSecureStorage mockStorage;
  late Dio dio;
  late DioAdapter dioAdapter;
  late ApiClient client;

  setUp(() {
    mockStorage = MockSecureStorage();
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => 'test_token');

    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
    dioAdapter = DioAdapter(dio: dio, matcher: const FullHttpRequestMatcher());
    client = ApiClient(
      storageService: mockStorage,
      config: _testConfig(),
      testDio: dio,
    );
  });

  group('Backend error envelope parsing', () {
    test('401 with error.message throws UnauthorizedException', () async {
      dioAdapter.onGet(
        '/protected',
        (server) => server.reply(401, {
          'error': {
            'message': 'Token has expired',
            'type': 'AuthenticationException',
            'status_code': 401,
          },
        }),
      );

      expect(
        () => client.get('/protected'),
        throwsA(
          predicate<UnauthorizedException>(
            (e) => e.message == 'Token has expired' && e.statusCode == 401,
          ),
        ),
      );
    });

    test('403 with error.message throws ForbiddenException', () async {
      dioAdapter.onGet(
        '/admin',
        (server) => server.reply(403, {
          'error': {
            'message': "Permission 'user.create' is required",
            'type': 'ForbiddenException',
            'status_code': 403,
          },
        }),
      );

      expect(
        () => client.get('/admin'),
        throwsA(
          predicate<ForbiddenException>(
            (e) =>
                e.message.contains('user.create') && e.statusCode == 403,
          ),
        ),
      );
    });

    test('429 with error.message throws RateLimitException', () async {
      dioAdapter.onPost(
        '/auth/login',
        (server) => server.reply(429, {
          'error': {
            'message': 'Too many requests. Please try again later.',
            'type': 'RateLimitException',
            'status_code': 429,
          },
        }),
        data: {'email': 'a@b.com', 'password': 'password123'},
      );

      expect(
        () => client.post(
          '/auth/login',
          data: {'email': 'a@b.com', 'password': 'password123'},
        ),
        throwsA(
          predicate<RateLimitException>(
            (e) => e.statusCode == 429 && e.message.contains('Too many requests'),
          ),
        ),
      );
    });

    test('422 Pydantic validation throws ValidationException', () async {
      dioAdapter.onPost(
        '/users/',
        (server) => server.reply(
          422,
          {
            'detail': [
              {
                'loc': ['body', 'email'],
                'msg': 'Invalid email format',
                'type': 'value_error',
              },
            ],
          },
        ),
        data: {'email': 'bad', 'password': 'short'},
      );

      expect(
        () => client.post('/users/', data: {'email': 'bad', 'password': 'short'}),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Authorization header behavior', () {
    test('does not attach Authorization header when storage has no token', () async {
      when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);

      String? capturedAuth;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedAuth =
                options.headers[HttpHeaders.authorizationHeader] as String?;
            handler.next(options);
          },
        ),
      );

      dioAdapter.onGet('/me', (server) => server.reply(200, {'id': 'user1'}));

      await client.get('/me');
      expect(capturedAuth, isNull);
    });

    test('attaches Bearer token when storage has access token', () async {
      String? capturedAuth;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedAuth =
                options.headers[HttpHeaders.authorizationHeader] as String?;
            handler.next(options);
          },
        ),
      );

      dioAdapter.onGet('/me', (server) => server.reply(200, {'id': 'user1'}));

      await client.get('/me');
      expect(capturedAuth, 'Bearer test_token');
    });
  });

  group('RateLimitException class', () {
    test('has correct default message and status code', () {
      final ex = RateLimitException();
      expect(ex.statusCode, 429);
      expect(ex.message, contains('Too many requests'));
      expect(ex, isA<ApiException>());
    });
  });
}
