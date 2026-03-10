import 'package:dio/dio.dart';
import 'auth_service.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  bool _isRefreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})> _requestQueue = [];

  AuthInterceptor(this.dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = AuthService().accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Never retry the refresh endpoint itself (prevents infinite loops)
    final isAuthPath = path.contains('/auth/');

    // Only attempt token refresh on 401 or 403 from non-auth endpoints
    if ((statusCode == 401 || statusCode == 403) && !isAuthPath) {
      if (_isRefreshing) {
        // Queue the request if a refresh is already in progress
        _requestQueue.add((options: err.requestOptions, handler: handler));
        return;
      }

      _isRefreshing = true;
      try {
        final newToken = await AuthService().performRefresh(dio);
        
        if (newToken != null && newToken.isNotEmpty) {
          // Retry the original request
          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newToken';
          
          // Retry queued requests
          for (final queuedRequest in _requestQueue) {
            final options = queuedRequest.options;
            options.headers['Authorization'] = 'Bearer $newToken';
            dio.fetch(options).then(
              (res) => queuedRequest.handler.resolve(res),
              onError: (e) => queuedRequest.handler.reject(e as DioException),
            );
          }
          _requestQueue.clear();

          final retryResponse = await dio.fetch(retryOptions);
          handler.resolve(retryResponse);
          return;
        } else {
          // Refresh failed or no refresh token
          await AuthService().clearSession();
          _rejectQueue(err);
          handler.next(err);
          return;
        }
      } catch (e) {
        // Refresh failed — clear session and reject current + queued requests
        await AuthService().clearSession();
        _rejectQueue(err);
        handler.next(err);
        return;
      } finally {
        _isRefreshing = false;
      }
    }
    // For all other errors (403, 500, etc.) pass through
    handler.next(err);
  }

  void _rejectQueue(DioException err) {
    for (final queuedRequest in _requestQueue) {
      queuedRequest.handler.reject(err);
    }
    _requestQueue.clear();
  }
}
