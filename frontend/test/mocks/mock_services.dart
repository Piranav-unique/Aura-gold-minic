import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:ags_gold/services/interfaces/secure_storage.dart';
import 'package:ags_gold/services/api_client.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

class MockApiClient extends Mock implements ApiClient {}

class MockResponse<T> extends Mock implements Response<T> {}
