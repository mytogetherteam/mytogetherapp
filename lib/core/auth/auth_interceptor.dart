import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../network/websocket_service.dart';
import '../../app.dart';
import '../../features/auth/presentation/screens/auth_entry_page.dart';

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
          final refreshStatus = e.response?.statusCode;
          if (refreshStatus == 401 || refreshStatus == 403) {
            // Refresh token itself is invalid/expired — force logout
            await _forceLogout();
          }
          // For network errors (5xx, timeout) during refresh, keep session
          // but fail the current request gracefully
        } else {
          await _forceLogout();
        }
        handler.next(err);
        return;
      }
    }
    handler.next(err);
  }

  /// Clears all local session data and navigates the user back to the login screen.
  Future<void> _forceLogout() async {
    await AuthService().clearSession();
    final nav = App.navigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthEntryPage()),
        (route) => false,
      );
    }
  }
}
