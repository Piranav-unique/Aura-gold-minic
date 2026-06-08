import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:ags_gold/config/env_config.dart';
import 'package:ags_gold/services/interfaces/secure_storage.dart';

const _kContentType = 'Content-Type';
const _kAccept = 'Accept';
const _kAuthorization = 'Authorization';

// Custom API Exceptions
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException([String? message])
    : super(
        message ?? 'Connection error. Please check your internet connection.',
      );
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String? message])
    : super(message ?? 'Session expired. Please log in again.', 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException([String? message])
    : super(
        message ?? 'You do not have permission to perform this action.',
        403,
      );
}

class NotFoundException extends ApiException {
  NotFoundException([String? message])
    : super(message ?? 'Requested resource not found.', 404);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;
  ValidationException(String message, [this.errors]) : super(message, 422);
}

class ServerException extends ApiException {
  ServerException([String? message])
    : super(message ?? 'Server error. Please try again later.', 500);
}

class RateLimitException extends ApiException {
  RateLimitException([String? message])
    : super(
        message ?? 'Too many requests. Please try again later.',
        429,
      );
}

class UnknownApiException extends ApiException {
  UnknownApiException(super.message, [super.statusCode]);
}

class ApiClient {
  late final Dio _dio;
  final ISecureStorage storageService;
  final VoidCallback? onUnauthorized;

  ApiClient({
    required this.storageService,
    this.onUnauthorized,
    EnvConfig? config,
    Dio? testDio,
  }) {
    if (testDio != null) {
      _dio = testDio;
    } else {
      final activeConfig = config ?? EnvConfig.active;

      _dio = Dio(
        BaseOptions(
          baseUrl: activeConfig.baseUrl,
          connectTimeout: activeConfig.connectionTimeout,
          receiveTimeout: activeConfig.receiveTimeout,
          headers: {
            _kContentType: 'application/json',
            _kAccept: 'application/json',
          },
        ),
      );

      if (kDebugMode) {
        _dio.interceptors.add(
          LogInterceptor(
            requestBody: true,
            responseBody: true,
            logPrint: (obj) => debugPrint('[API] $obj'),
          ),
        );
      }
    }

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers[_kAuthorization] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          final appException = _handleDioException(error);
          if (appException is UnauthorizedException) {
            onUnauthorized?.call();
          }
          return handler.next(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: appException,
            ),
          );
        },
      ),
    );
  }

  ApiException _handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkException();

      case DioExceptionType.badResponse:
        final response = error.response;
        if (response == null) {
          return UnknownApiException('No response received from server.');
        }

        final statusCode = response.statusCode;
        final responseData = response.data;
        final errorMessage = _extractErrorMessage(responseData);

        switch (statusCode) {
          case 401:
            return UnauthorizedException(
              errorMessage.isNotEmpty ? errorMessage : null,
            );
          case 403:
            return ForbiddenException(
              errorMessage.isNotEmpty ? errorMessage : null,
            );
          case 404:
            return NotFoundException(
              errorMessage.isNotEmpty ? errorMessage : null,
            );
          case 429:
            return RateLimitException(
              errorMessage.isNotEmpty ? errorMessage : null,
            );
          case 422:
            Map<String, dynamic>? errors;
            if (responseData is Map && responseData.containsKey('errors')) {
              errors = responseData['errors'] as Map<String, dynamic>?;
            }
            return ValidationException(
              errorMessage.isNotEmpty ? errorMessage : 'Validation failed.',
              errors,
            );
          default:
            if (statusCode != null && statusCode >= 500) {
              return ServerException(
                errorMessage.isNotEmpty ? errorMessage : null,
              );
            }
            return UnknownApiException(
              errorMessage.isNotEmpty
                  ? errorMessage
                  : 'Server returned status $statusCode',
              statusCode,
            );
        }

      case DioExceptionType.cancel:
        return UnknownApiException('Request was cancelled.');

      case DioExceptionType.unknown:
      default:
        return UnknownApiException(
          error.message ?? 'An unknown network error occurred.',
        );
    }
  }

  String _extractErrorMessage(dynamic responseData) {
    if (responseData is! Map) {
      return '';
    }

    final error = responseData['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }

    if (responseData['detail'] != null) {
      return responseData['detail'].toString();
    }

    return '';
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw e.error as ApiException;
    }
  }

  Future<Response<List<int>>> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<List<int>>(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw e.error as ApiException;
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw e.error as ApiException;
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw e.error as ApiException;
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw e.error as ApiException;
    }
  }
}
