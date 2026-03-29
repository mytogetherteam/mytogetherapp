import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_interceptor.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'dart:io';

class ApiClient {
  static const String apiPrefix = '/api/v1/mobile';
  
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://mytogetherapi-production.up.railway.app',
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          'Content-Type': 'application/json',
          'Accept': '*/*',
        },
      ),
    );

    // Auth interceptor: attaches Bearer token and handles 401 auto-refresh
    _dio.interceptors.add(AuthInterceptor(_dio));

    // Cache interceptor
    _dio.interceptors.add(DioCacheInterceptor(
      options: CacheOptions(
        store: MemCacheStore(),
        policy: CachePolicy.request,
        maxStale: const Duration(days: 7),
        priority: CachePriority.normal,
        keyBuilder: CacheOptions.defaultCacheKeyBuilder,
        allowPostMethod: false,
      ),
    ));

    // Retry logic for transient errors
    _dio.interceptors.add(InterceptorsWrapper(
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
    ));

    // Secured Logging interceptor
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
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
            print('API_RESPONSE: $logStr');
          } else {
            print('API_RESPONSE: [Part 1] ${logStr.substring(0, chunkSize)}');
            int part = 2;
            for (int i = chunkSize; i < logStr.length; i += chunkSize) {
              int end = (i + chunkSize < logStr.length) ? i + chunkSize : logStr.length;
              print('API_RESPONSE: [Part $part] ${logStr.substring(i, end)}');
              part++;
            }
          }
        },
      ));
    }

    // DISABLING NON-CRITICAL API CALLS FOR FALLBACK TESTING
    _dio.interceptors.add(DisableApiInterceptor());
  }

  bool _shouldRetry(DioException err) {
    // Never retry if an API has been explicitly disabled
    if (err.message == 'API Disabled for Fallback Testing') return false;

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

/// A custom interceptor to block all API requests except for Auth, Orders, and Notifications.
/// This is used to force the app to rely on local fallback JSON data for other features.
class DisableApiInterceptor extends Interceptor {
  // Define whitelisted paths that ARE allowed to pass through
  static final List<String> _allowedPaths = [
    '${ApiClient.apiPrefix}/auth/',
    '${ApiClient.apiPrefix}/user/profile',
    '${ApiClient.apiPrefix}/user-locations',
    '${ApiClient.apiPrefix}/orders',
    '${ApiClient.apiPrefix}/notifications',
    '${ApiClient.apiPrefix}/cart',
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;

    // Check if the current request path matches any allowed prefix
    final isAllowed = _allowedPaths.any((allowed) => path.startsWith(allowed));

    if (isAllowed) {
      return handler.next(options);
    }

    // Block non-allowed requests with a custom error message
    // This will be caught by repository catch blocks and trigger fallback data loading
    debugPrint('[API_BLOCKER] Blocking request to: ${options.uri}');
    return handler.reject(
      DioException(
        requestOptions: options,
        message: 'API Disabled for Fallback Testing',
        type: DioExceptionType.cancel,
      ),
    );
  }
}
