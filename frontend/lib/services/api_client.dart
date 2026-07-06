import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:ags_gold/core/logging/api_debug_log.dart';
import 'package:ags_gold/config/env_config.dart';
import 'package:ags_gold/services/interfaces/secure_storage.dart';
import 'package:ags_gold/services/api_client_transport_stub.dart'
    if (dart.library.io) 'package:ags_gold/services/api_client_transport_io.dart';

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
    : super(message ?? 'Too many requests. Please try again later.', 429);
}

class UnknownApiException extends ApiException {
  UnknownApiException(super.message, [super.statusCode]);
}

class ApiClient {
  late final Dio _dio;
  late final Dio _refreshDio;
  final ISecureStorage storageService;
  final VoidCallback? onUnauthorized;
  bool _isRefreshing = false;

  ApiClient({
    required this.storageService,
    this.onUnauthorized,
    EnvConfig? config,
    Dio? testDio,
  }) {
    if (testDio != null) {
      _dio = testDio;
      _refreshDio = testDio;
    } else {
      final activeConfig = config ?? EnvConfig.active;

      _refreshDio = Dio(
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

      configureHttpAdapters(_dio, _refreshDio, activeConfig.connectionTimeout);

      const apiLogsOnly = bool.fromEnvironment('API_LOGS_ONLY');
      if (kDebugMode && apiLogsOnly) {
        apiLog('Using API base URL: ${activeConfig.baseUrl}');
      }

      const verboseApiLogs = bool.fromEnvironment('VERBOSE_API_LOGS');
      if (kDebugMode && verboseApiLogs) {
        _dio.interceptors.add(
          LogInterceptor(
            requestBody: true,
            responseBody: true,
            logPrint: (obj) => apiLog('$obj'),
          ),
        );
      } else if (kDebugMode) {
        _dio.interceptors.add(_CompactApiLogInterceptor());
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
        onError: (DioException error, handler) async {
          final statusCode = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isAuthPath =
              path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/refresh') ||
              path.contains('/auth/logout');

          if (statusCode == 401 && !isAuthPath) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              try {
                final token = await storageService.getAccessToken();
                error.requestOptions.headers[_kAuthorization] = 'Bearer $token';
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } on DioException catch (retryError) {
                error = retryError;
              }
            }
          }

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

  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) {
      return false;
    }
    _isRefreshing = true;
    try {
      final refreshToken = await storageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      if (data == null ||
          data['access_token'] == null ||
          data['refresh_token'] == null) {
        return false;
      }

      await storageService.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
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
        final inner = error.error;
        if (isTransportLevelError(inner)) {
          return NetworkException(
            'Cannot reach the API server. Confirm it is running, bound to '
            '0.0.0.0:8000, and that your phone is on the same Wi‑Fi network '
            'as the machine hosting the backend.',
          );
        }
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

    final detail = responseData['detail'];
    if (detail is String) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) {
        return first['msg'].toString();
      }
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

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch<T>(
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

/// Logs one line per request/response so Flutter run key commands stay visible.
class _CompactApiLogInterceptor extends Interceptor {
  static String _pathWithQuery(RequestOptions options) {
    final path = options.path.isNotEmpty ? options.path : options.uri.path;
    final query = options.uri.query;
    if (query.isEmpty) return path;
    return '$path?$query';
  }

  static String _errorDetail(DioException err) {
    final data = err.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString();
      }
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
    }
    if (err.message != null && err.message!.trim().isNotEmpty) {
      return err.message!.trim();
    }
    return err.type.name;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    apiLog('${options.method} ${_pathWithQuery(options)}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    apiLog(
      '${response.statusCode} ${response.requestOptions.method} ${_pathWithQuery(response.requestOptions)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.cancel) {
      handler.next(err);
      return;
    }
    final status = err.response?.statusCode;
    apiLog(
      'ERROR ${status ?? '-'} ${err.requestOptions.method} ${_pathWithQuery(err.requestOptions)}: ${_errorDetail(err)}',
    );
    handler.next(err);
  }
}
