import 'package:dio/dio.dart';

import 'package:bfm_app/auth/token_store.dart';

/// Thrown when the backend returns 401 so callers can redirect to login.
class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Unauthorized']);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Pre-configured [Dio] instance for the Moni backend.
///
/// Reads the JWT from [TokenStore] on every request and injects the
/// `Authorization` header. Throws [UnauthorizedException] on 401.
class ApiClient {
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
        // Don't inject auth on public endpoints (login/register)
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
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          return handler.reject(DioException(
            requestOptions: error.requestOptions,
            error: const UnauthorizedException(),
            type: DioExceptionType.badResponse,
            response: error.response,
          ));
        }
        return handler.next(error);
      },
    ));
  }

  final TokenStore _tokenStore;
  final Dio _dio;

  Dio get dio => _dio;
}
