import 'package:dio/dio.dart';
import '../auth_remote_data_source.dart';
import '../models/auth_models.dart';
import '../models/user_location_model.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/user_model.dart';

class AuthRepository {
  static final AuthRepository instance = AuthRepository._internal();
  AuthRepository._internal();

  final AuthRemoteDataSource _dataSource = AuthRemoteDataSource();

  Future<void> login({required String usernameOrEmail, required String password}) async {
    try {
      final response = await _dataSource.login(
        LoginRequest(usernameOrEmail: usernameOrEmail, password: password),
      );
      
      if (response.role != 'CUSTOMER') {
        throw Exception('Access Denied: Only users can login to this app.');
      }
      
      // After login success, we must ensure the token is set for subsequent calls
      // The Dio interceptor usually handles this, but here we might need a manual set if not yet initialized
      AuthService().updateAccessToken(response.token);

      final profile = await _dataSource.getUserProfile();
      final locations = await _dataSource.getUserLocations();

      await _saveSession(response, profile: profile, locations: locations);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _dataSource.register(
        RegisterRequest(username: username, email: email, password: password, fullName: fullName),
      );
      
      AuthService().updateAccessToken(response.token);
      
      final profile = await _dataSource.getUserProfile();
      final locations = await _dataSource.getUserLocations();

      await _saveSession(response, profile: profile, locations: locations);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> logout() async {
    try {
      final token = AuthService().refreshToken;
      if (token != null && token.isNotEmpty) {
        // Fire remote logout in the background to avoid blocking the user
        _dataSource.logout(token: token).catchError((_) {});
      }
    } catch (_) {
      // Ignore errors on logout
    } finally {
      // Clear local session immediately so the user logs out instantly in the UI
      await AuthService().clearSession();
    }
  }

  Future<void> _saveSession(AuthResponse response, {UserModel? profile, List<UserLocationModel>? locations}) async {
    final user = profile ?? UserModel(
      id: response.id,
      username: response.username,
      email: response.email,
      fullName: response.fullName,
      role: response.role,
    );
    await AuthService().saveSession(
      accessToken: response.token,
      refreshToken: response.refreshToken,
      user: user,
      userLocations: locations,
    );
  }

  String _parseError(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;
    // API returns: { message, details, code, ... }
    // 'details' holds the most descriptive human-readable text
    final details = body is Map ? body['details'] as String? : null;
    final message = body is Map ? body['message'] as String? : null;
    final text = details?.isNotEmpty == true ? details : message;

    if (statusCode == 401 || statusCode == 400) {
      return text ?? 'Invalid username or password.';
    }
    if (statusCode == 409) {
      return text ?? 'Username or email already exists.';
    }
    if (statusCode == 429) {
      return 'Too many attempts. Please try again later.';
    }
    return text ?? 'Unable to connect to server. Please check your connection.';
  }
}
