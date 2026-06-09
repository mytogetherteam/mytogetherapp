import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../network/websocket_service.dart';

class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;
  bool _isRefreshing = false;

  AuthInterceptor(this.dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final authService = AuthService();
    final isAuthPath = options.path.contains('/auth/');

    // Proactive refresh: if token is about to expire, refresh it BEFORE sending the request
    if (authService.isLoggedIn && authService.isTokenNearlyExpired && !isAuthPath) {
      try {
        final newToken = await authService.performRefresh(dio);
        if (newToken != null) {
          options.headers['Authorization'] = 'Bearer $newToken';
          WebSocketService().connect(force: true);
        }
      } catch (e) {
        // If proactive refresh fails (e.g. timeout), we don't log out yet.
        // We let the request proceed and handle 401/403 in onError if it happens.
      }
    }

    final token = authService.accessToken;
    if (token != null && token.isNotEmpty && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Never retry the refresh endpoint itself
    final isAuthPath = path.contains('/auth/');

    // Only attempt token refresh on 401 or 403 from non-auth endpoints
    if ((statusCode == 401 || statusCode == 403) && !isAuthPath) {
      if (_isRefreshing) {
        // QueuedInterceptor will handle the queuing of subsequent requests automatically
        // but we need to ensure we don't start multiple refreshes simultaneously.
      }

      _isRefreshing = true;
      try {
        final newToken = await AuthService().performRefresh(dio);
        
        if (newToken != null && newToken.isNotEmpty) {
          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newToken';
          
          WebSocketService().connect(force: true);
          
          final retryResponse = await dio.fetch(retryOptions);
          handler.resolve(retryResponse);
          return;
        } else {
          // Explicit fail (no token returned but no exception)
          await AuthService().clearSession();
          handler.next(err);
          return;
        }
      } catch (e) {
        // Refresh failed. Check if it's a structural failure (401/403) or network/server failure.
        if (e is DioException) {
          final refreshStatus = e.response?.statusCode;
          if (refreshStatus == 401 || refreshStatus == 403) {
            // Only clear session if the refresh token itself is invalid
            await AuthService().clearSession();
          }
        }
        // For timeouts, 500s during refresh, we keep the session but fail the current request.
        handler.next(err);
        return;
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}


