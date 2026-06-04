import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_interceptor.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'dart:io';

class ApiClient {
  // ───────────────────────────────────────────────────────────────────────
  // Base URL configuration
  //   • Production:  https://api.mytogether.org
  //
  // The backend (myshop_demo_api) is a NestJS server. All routes are prefixed
  // with `/api` via `app.setGlobalPrefix('api')` in main.ts.
  // ───────────────────────────────────────────────────────────────────────
  static String get baseUrl {
    return 'https://api.mytogether.org';
  }

  /// Global API prefix used by every route on the new backend.
  /// User-facing routes live under `/api/user/...`, public routes
  /// (shops/foods/banners/etc.) live directly under `/api/...`.
  static const String apiPrefix = '/api';

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json', 'Accept': '*/*'},
      ),
    );

    // Auth interceptor: attaches Bearer token and handles 401 auto-refresh
    _dio.interceptors.add(AuthInterceptor(_dio));

    // Cache interceptor
    _dio.interceptors.add(
      DioCacheInterceptor(
        options: CacheOptions(
          store: MemCacheStore(),
          policy: CachePolicy.request,
          maxStale: const Duration(days: 7),
          priority: CachePriority.normal,
          keyBuilder: CacheOptions.defaultCacheKeyBuilder,
          allowPostMethod: false,
        ),
      ),
    );

    // Retry logic for transient errors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (err, handler) async {
          if (_shouldRetry(err)) {
            try {
              final response = await _retry(err.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(err);
            }
          }
          return handler.next(err);
        },
      ),
    );

    // Secured Logging interceptor
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: true,
          error: false,
          logPrint: (object) {
            final logStr = object.toString();
            const int chunkSize = 800;

            if (logStr.length <= chunkSize) {
              debugPrint('API_RESPONSE: $logStr');
            } else {
              debugPrint(
                'API_RESPONSE: [Part 1] ${logStr.substring(0, chunkSize)}',
              );
              int part = 2;
              for (int i = chunkSize; i < logStr.length; i += chunkSize) {
                int end = (i + chunkSize < logStr.length)
                    ? i + chunkSize
                    : logStr.length;
                debugPrint(
                  'API_RESPONSE: [Part $part] ${logStr.substring(i, end)}',
                );
                part++;
              }
            }
          },
        ),
      );
    }
  }

  bool _shouldRetry(DioException err) {
    return err.type != DioExceptionType.cancel &&
        err.type != DioExceptionType.badResponse &&
        (err.error is SocketException ||
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.sendTimeout ||
            err.type == DioExceptionType.receiveTimeout);
  }

  Future<Response> _retry(RequestOptions requestOptions) {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  Dio get dio => _dio;
}
