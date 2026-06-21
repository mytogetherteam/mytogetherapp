import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_interceptor.dart';
import '../config/env_config.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

import 'certificate_pinning.dart';

class ApiClient {
  // ───────────────────────────────────────────────────────────────────────
  // Base URL configuration (see EnvConfig — set APP_ENV=staging for local).
  // The backend (myshop_demo_api) is a NestJS server. All routes are prefixed
  // with `/api` via `app.setGlobalPrefix('api')` in main.ts.
  // ───────────────────────────────────────────────────────────────────────
  static String get baseUrl => EnvConfig.apiBaseUrl;

  /// Global API prefix used by every route on the new backend.
  /// User-facing routes live under `/api/user/...`, public routes
  /// REST endpoints for shops, menus, banners, etc. live under `/api/user/...`
  /// or other authenticated routes (the legacy public `/api/shops/*` module
  /// was removed from the backend).
  static String get apiPrefix => EnvConfig.apiPrefix;

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

    // Enforce Certificate Pinning & prevent MITM Proxy interception
    CertificatePinning.setup(_dio);

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
          logPrint: _debugLogApiResponse,
        ),
      );
    }
  }

  /// Logs API responses without splitting UTF-16 surrogate pairs or emitting
  /// U+FFFD, which can crash Flutter DevTools when decoding log strings.
  static void _debugLogApiResponse(Object object) {
    final logStr = _sanitizeLogString(object.toString());
    const int chunkSize = 800;
    const int maxTotalLength = 4000;

    final truncated = logStr.length > maxTotalLength
        ? '${logStr.substring(0, _safeSubstringEnd(logStr, 0, maxTotalLength))}… [truncated ${logStr.length - maxTotalLength} chars]'
        : logStr;

    if (truncated.length <= chunkSize) {
      debugPrint('API_RESPONSE: $truncated');
      return;
    }

    var start = 0;
    var part = 1;
    while (start < truncated.length) {
      final end = _safeSubstringEnd(
        truncated,
        start,
        start + chunkSize,
      );
      debugPrint('API_RESPONSE: [Part $part] ${truncated.substring(start, end)}');
      start = end;
      part++;
    }
  }

  /// Replaces characters that break Flutter's UTF-8 log decoder.
  static String _sanitizeLogString(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final unit = value.codeUnitAt(i);
      if (unit == 0xFFFD) {
        buffer.write('?');
        continue;
      }
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (i + 1 < value.length) {
          final next = value.codeUnitAt(i + 1);
          if (next >= 0xDC00 && next <= 0xDFFF) {
            buffer.writeCharCode(unit);
            buffer.writeCharCode(next);
            i++;
            continue;
          }
        }
        buffer.write('?');
        continue;
      }
      if (unit >= 0xDC00 && unit <= 0xDFFF) {
        buffer.write('?');
        continue;
      }
      buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  /// Returns [end] adjusted so [value.substring(start, end)] is UTF-16 safe.
  static int _safeSubstringEnd(String value, int start, int end) {
    if (end >= value.length) return value.length;
    if (end <= start) return start;

    final before = value.codeUnitAt(end - 1);
    if (before >= 0xD800 && before <= 0xDBFF) {
      return (end + 1 <= value.length) ? end + 1 : end - 1;
    }

    final at = value.codeUnitAt(end);
    if (at >= 0xDC00 && at <= 0xDFFF) {
      return end - 1;
    }

    return end;
  }

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.extra['isRetry'] == true) return false;
    return err.type != DioExceptionType.cancel &&
        err.type != DioExceptionType.badResponse &&
        (err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.sendTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            (!kIsWeb &&
                err.type == DioExceptionType.connectionError));
  }

  Future<Response> _retry(RequestOptions requestOptions) {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
      extra: {...requestOptions.extra, 'isRetry': true},
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
