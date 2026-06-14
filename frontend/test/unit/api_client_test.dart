// test/unit/api_client_test.dart
// Unit tests for ApiException class hierarchy and ApiClient error surfaces.
// We test exception classes directly and the types of errors they produce.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
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

  setUp(() {
    mockStorage = MockSecureStorage();
    when(
      () => mockStorage.getAccessToken(),
    ).thenAnswer((_) async => 'test_token');
  });

  group('ApiException class hierarchy', () {
    test('NetworkException has correct default message', () {
      final ex = NetworkException();
      expect(ex.message, contains('Connection error'));
      expect(ex.toString(), contains('Connection error'));
      expect(ex.statusCode, isNull);
    });

    test('NetworkException accepts a custom message', () {
      final ex = NetworkException('Custom network error');
      expect(ex.message, 'Custom network error');
    });

    test(
      'UnauthorizedException has correct default message and status code',
      () {
        final ex = UnauthorizedException();
        expect(ex.message, contains('Session expired'));
        expect(ex.statusCode, 401);
      },
    );

    test('UnauthorizedException accepts a custom message', () {
      final ex = UnauthorizedException('Token invalid');
      expect(ex.message, 'Token invalid');
      expect(ex.statusCode, 401);
    });

    test('ForbiddenException has correct default message and status code', () {
      final ex = ForbiddenException();
      expect(ex.message, contains('permission'));
      expect(ex.statusCode, 403);
    });

    test('ForbiddenException accepts a custom message', () {
      final ex = ForbiddenException('Custom forbidden');
      expect(ex.message, 'Custom forbidden');
      expect(ex.statusCode, 403);
    });

    test('NotFoundException has correct default message and status code', () {
      final ex = NotFoundException();
      expect(ex.message, contains('not found'));
      expect(ex.statusCode, 404);
    });

    test('NotFoundException accepts a custom message', () {
      final ex = NotFoundException('User not found');
      expect(ex.message, 'User not found');
      expect(ex.statusCode, 404);
    });

    test('ServerException has correct default message and status code', () {
      final ex = ServerException();
      expect(ex.message, contains('Server error'));
      expect(ex.statusCode, 500);
    });

    test('ServerException accepts a custom message', () {
      final ex = ServerException('DB connection failed');
      expect(ex.message, 'DB connection failed');
      expect(ex.statusCode, 500);
    });

    test('ValidationException stores errors map', () {
      final errors = {'email': 'invalid format', 'password': 'too short'};
      final ex = ValidationException('Validation failed', errors);
      expect(ex.message, 'Validation failed');
      expect(ex.statusCode, 422);
      expect(ex.errors, errors);
      expect(ex.toString(), 'Validation failed');
    });

    test('ValidationException allows null errors map', () {
      final ex = ValidationException('Required field missing');
      expect(ex.errors, isNull);
    });

    test('UnknownApiException stores message and status code', () {
      final ex = UnknownApiException('Unexpected error', 418);
      expect(ex.message, 'Unexpected error');
      expect(ex.statusCode, 418);
      expect(ex.toString(), 'Unexpected error');
    });

    test('UnknownApiException allows null status code', () {
      final ex = UnknownApiException('Something failed');
      expect(ex.statusCode, isNull);
    });

    test('all exceptions extend ApiException', () {
      expect(NetworkException(), isA<ApiException>());
      expect(UnauthorizedException(), isA<ApiException>());
      expect(ForbiddenException(), isA<ApiException>());
      expect(NotFoundException(), isA<ApiException>());
      expect(ServerException(), isA<ApiException>());
      expect(ValidationException('err'), isA<ApiException>());
      expect(UnknownApiException('err'), isA<ApiException>());
    });

    test('all exceptions implement Exception', () {
      expect(NetworkException(), isA<Exception>());
      expect(UnauthorizedException(), isA<Exception>());
      expect(ForbiddenException(), isA<Exception>());
    });
  });

  group('ApiClient with mock HTTP adapter', () {
    late Dio dio;
    late DioAdapter dioAdapter;
    late ApiClient client;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
      dioAdapter = DioAdapter(
        dio: dio,
        matcher: const FullHttpRequestMatcher(),
      );
      client = ApiClient(
        storageService: mockStorage,
        config: _testConfig(),
        testDio: dio,
      );
    });

    test('GET request returns data on 200', () async {
      dioAdapter.onGet(
        '/test',
        (server) => server.reply(200, {'result': 'ok'}),
      );

      final response = await client.get('/test');
      expect(response.statusCode, 200);
      expect((response.data as Map)['result'], 'ok');
    });

    test('POST request sends body and returns 201', () async {
      dioAdapter.onPost(
        '/items',
        (server) => server.reply(201, {'id': 'new-item'}),
        data: {'name': 'Item A'},
      );

      final response = await client.post('/items', data: {'name': 'Item A'});
      expect(response.statusCode, 201);
      expect((response.data as Map)['id'], 'new-item');
    });

    test('PUT request sends update and returns 200', () async {
      dioAdapter.onPut(
        '/items/1',
        (server) => server.reply(200, {'id': '1', 'name': 'Updated'}),
        data: {'name': 'Updated'},
      );

      final response = await client.put('/items/1', data: {'name': 'Updated'});
      expect(response.statusCode, 200);
    });

    test('DELETE request returns 204', () async {
      dioAdapter.onDelete('/items/1', (server) => server.reply(204, null));

      final response = await client.delete('/items/1');
      expect(response.statusCode, 204);
    });

    test('401 response throws UnauthorizedException', () async {
      dioAdapter.onGet(
        '/protected',
        (server) => server.reply(401, {'detail': 'Unauthorized'}),
      );

      expect(
        () => client.get('/protected'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('403 response throws ForbiddenException', () async {
      dioAdapter.onGet(
        '/admin',
        (server) => server.reply(403, {'detail': 'Forbidden'}),
      );

      expect(() => client.get('/admin'), throwsA(isA<ForbiddenException>()));
    });

    test('404 response throws NotFoundException', () async {
      dioAdapter.onGet(
        '/missing',
        (server) => server.reply(404, {'detail': 'Not Found'}),
      );

      expect(() => client.get('/missing'), throwsA(isA<NotFoundException>()));
    });

    test('422 response throws ValidationException', () async {
      dioAdapter.onPost(
        '/validate',
        (server) => server.reply(422, {
          'detail': 'Validation failed',
          'errors': {'email': 'invalid'},
        }),
        data: {'email': 'bad'},
      );

      expect(
        () => client.post('/validate', data: {'email': 'bad'}),
        throwsA(isA<ValidationException>()),
      );
    });

    test('500 response throws ServerException', () async {
      dioAdapter.onGet(
        '/crash',
        (server) => server.reply(500, {'detail': 'Internal Server Error'}),
      );

      expect(() => client.get('/crash'), throwsA(isA<ServerException>()));
    });

    test('GET with query parameters passes them correctly', () async {
      dioAdapter.onGet(
        '/users',
        (server) => server.reply(200, []),
        queryParameters: {'skip': 0, 'limit': 10},
      );

      final response = await client.get(
        '/users',
        queryParameters: {'skip': 0, 'limit': 10},
      );
      expect(response.statusCode, 200);
    });

    test('Authorization header is set from access token', () async {
      dioAdapter.onGet('/me', (server) => server.reply(200, {'id': 'user1'}));

      await client.get('/me');
      verify(
        () => mockStorage.getAccessToken(),
      ).called(greaterThanOrEqualTo(1));
    });
  });
}
