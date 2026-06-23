import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../network/websocket_service.dart';

class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;

  AuthInterceptor(this.dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final authService = AuthService();
    final path = options.path;

    // Paths that never need an Authorization header
    final isAuthPath = path.contains('/auth/refresh') ||
        path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/check-phone');

    // Proactive refresh: if token is about to expire, refresh it BEFORE sending
    if (authService.isLoggedIn && authService.isTokenNearlyExpired && !isAuthPath) {
      try {
        final newToken = await authService.performRefresh(dio);
        if (newToken != null) {
          options.headers['Authorization'] = 'Bearer $newToken';
          WebSocketService().reconnectIfTokenChanged(newToken);
        }
      } catch (e) {
        // Proactive refresh failed — let request proceed; handle 401 in onError.
      }
    }

    // Attach current token for protected routes only
    if (!isAuthPath) {
      final token = authService.accessToken;
      if (token != null && token.isNotEmpty && !options.headers.containsKey('Authorization')) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Never retry auth endpoints themselves to avoid infinite loops
    final isAuthEndpoint = path.contains('/auth/');

    if ((statusCode == 401 || statusCode == 403) && !isAuthEndpoint) {
      try {
        final newToken = await AuthService().performRefresh(dio);

        if (newToken != null && newToken.isNotEmpty) {
          // Retry the original failed request with the new token
          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newToken';

          WebSocketService().reconnectIfTokenChanged(newToken);

          final retryResponse = await dio.fetch(retryOptions);
          handler.resolve(retryResponse);
          return;
        } else {
          // Refresh returned no token (refresh token probably expired on server)
          await _forceLogout();
          handler.next(err);
          return;
        }
      } catch (e) {
        if (e is DioException) {
          // Check if the error came from the refresh request itself
          final isFromRefresh = e.requestOptions.path.contains('/auth/refresh');
          final responseStatus = e.response?.statusCode;
          
          if (isFromRefresh && (responseStatus == 401 || responseStatus == 403)) {
            // Refresh token itself is invalid/expired — force logout
            await _forceLogout();
          }
          // For other network errors or if the RETRIED request failed again,
          // just pass the error down without logging out.
        } else {
          await _forceLogout();
        }
        handler.next(err);
        return;
      }
    }
    handler.next(err);
  }

  /// Clears all local session data but DOES NOT force navigation,
  /// so the user is not abruptly kicked out of their current screen
  /// when resuming from the background.
  Future<void> _forceLogout() async {
    await AuthService().clearSession(navigate: false);
  }
}
