import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:ags_gold/services/interfaces/secure_storage.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/features/auth/domain/device_auth_storage.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

class MockDeviceAuthStorage extends Mock implements IDeviceAuthStorage {}

class MockApiClient extends Mock implements ApiClient {}

class MockResponse<T> extends Mock implements Response<T> {}
