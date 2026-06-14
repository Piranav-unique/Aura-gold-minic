import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ags_gold/services/secure_storage_service.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockSecureStorage;
  late SecureStorageService service;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    service = SecureStorageService(storage: mockSecureStorage);
  });

  test('SecureStorageService - saveTokens writes tokens to storage', () async {
    when(
      () => mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async => {});

    await service.saveTokens(accessToken: 'access', refreshToken: 'refresh');

    verify(
      () => mockSecureStorage.write(key: 'access_token', value: 'access'),
    ).called(1);
    verify(
      () => mockSecureStorage.write(key: 'refresh_token', value: 'refresh'),
    ).called(1);
  });

  test('SecureStorageService - getAccessToken reads token', () async {
    when(
      () => mockSecureStorage.read(key: 'access_token'),
    ).thenAnswer((_) async => 'access');

    final token = await service.getAccessToken();

    expect(token, 'access');
  });

  test('SecureStorageService - getRefreshToken reads token', () async {
    when(
      () => mockSecureStorage.read(key: 'refresh_token'),
    ).thenAnswer((_) async => 'refresh');

    final token = await service.getRefreshToken();

    expect(token, 'refresh');
  });

  test('SecureStorageService - clearTokens deletes tokens', () async {
    when(
      () => mockSecureStorage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async => {});

    await service.clearTokens();

    verify(() => mockSecureStorage.delete(key: 'access_token')).called(1);
    verify(() => mockSecureStorage.delete(key: 'refresh_token')).called(1);
  });

  test(
    'SecureStorageService - hasAccessToken returns correct boolean',
    () async {
      when(
        () => mockSecureStorage.read(key: 'access_token'),
      ).thenAnswer((_) async => null);

      expect(await service.hasAccessToken(), isFalse);

      when(
        () => mockSecureStorage.read(key: 'access_token'),
      ).thenAnswer((_) async => 'access');

      expect(await service.hasAccessToken(), isTrue);
    },
  );
}
