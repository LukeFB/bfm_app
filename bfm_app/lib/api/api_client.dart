import 'dart:developer';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'package:bfm_app/auth/token_store.dart';
import 'package:bfm_app/services/debug_log.dart';

/// Thrown when the backend returns 401 so callers can redirect to login.
class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Unauthorized']);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Thrown when the backend returns 429 and all retries are exhausted.
class RateLimitedException implements Exception {
  final Duration? retryAfter;
  const RateLimitedException([this.retryAfter]);

  @override
  String toString() {
    final wait = retryAfter != null ? ' (retry after ${retryAfter!.inSeconds}s)' : '';
    return 'Rate limited by the server$wait. Please wait a moment and try again.';
  }
}

/// Pre-configured [Dio] instance for the Moni backend.
///
/// Reads the JWT from [TokenStore] on every request and injects the
/// `Authorization` header. Handles 401 (unauthorized) and 429 (rate limit)
/// responses with automatic retry + exponential backoff.
class ApiClient {
  static const _maxRetries = 3;
  static const _baseBackoff = Duration(seconds: 2);
  ApiClient({required TokenStore tokenStore, Dio? dio})
      : _tokenStore = tokenStore,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://moni.luminateone.dev/api/v1',
              headers: {'Accept': 'application/json'},
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.extra['_startTime'] = DateTime.now().millisecondsSinceEpoch;
        final path = options.path;
        final isPublic = path.contains('/auth/login') ||
            path.contains('/auth/register');
        if (!isPublic) {
          final token = await _tokenStore.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final start = response.requestOptions.extra['_startTime'] as int?;
        if (start != null) {
          final ms = DateTime.now().millisecondsSinceEpoch - start;
          final method = response.requestOptions.method;
          final path = response.requestOptions.path;
          final status = response.statusCode;
          log('API $method $path → $status (${ms}ms)');
          DebugLog.instance.api(method, path, status, ms);
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        final start = error.requestOptions.extra['_startTime'] as int?;
        final status = error.response?.statusCode;

        if (start != null) {
          final ms = DateTime.now().millisecondsSinceEpoch - start;
          final method = error.requestOptions.method;
          final path = error.requestOptions.path;
          log('API $method $path → ${status ?? 'timeout'} (${ms}ms)');
          DebugLog.instance.api(method, path, status, ms);
        }

        if (status == 401) {
          return handler.reject(DioException(
            requestOptions: error.requestOptions,
            error: const UnauthorizedException(),
            type: DioExceptionType.badResponse,
            response: error.response,
          ));
        }

        if (status == 429) {
          final attempt = error.requestOptions.extra['_retryCount'] as int? ?? 0;

          if (attempt >= _maxRetries) {
            final retryAfter = _parseRetryAfter(error.response);
            return handler.reject(DioException(
              requestOptions: error.requestOptions,
              error: RateLimitedException(retryAfter),
              type: DioExceptionType.badResponse,
              response: error.response,
            ));
          }

          final waitDuration = _retryDelay(error.response, attempt);
          final msg = '429 on ${error.requestOptions.path} – '
              'waiting ${waitDuration.inSeconds}s (attempt ${attempt + 1}/$_maxRetries)';
          log(msg);
          DebugLog.instance.add('RATE', msg);
          await Future.delayed(waitDuration);

          final opts = error.requestOptions;
          opts.extra['_retryCount'] = attempt + 1;
          try {
            final response = await _dio.fetch(opts);
            return handler.resolve(response);
          } on DioException catch (e) {
            return handler.reject(e);
          }
        }

        return handler.next(error);
      },
    ));
  }

  final TokenStore _tokenStore;
  final Dio _dio;

  Dio get dio => _dio;

  /// Computes the delay before retrying. Prefers the server's Retry-After
  /// header when present, otherwise falls back to exponential backoff.
  static Duration _retryDelay(Response? response, int attempt) {
    final serverDelay = _parseRetryAfter(response);
    if (serverDelay != null) return serverDelay;
    final seconds = _baseBackoff.inSeconds * math.pow(2, attempt);
    return Duration(seconds: seconds.toInt());
  }

  static Duration? _parseRetryAfter(Response? response) {
    final header = response?.headers.value('retry-after');
    if (header == null) return null;
    final seconds = int.tryParse(header);
    if (seconds != null) return Duration(seconds: seconds);
    return null;
  }
}
