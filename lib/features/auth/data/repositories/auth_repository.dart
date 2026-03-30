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
    // MOCK LOGIN: Skip API calls and allow any credentials
    print('[MOCK] Logging in with any credentials...');
    
    final mockResponse = AuthResponse(
      token: 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock_refresh_token',
      id: 123,
      username: usernameOrEmail.split('@')[0],
      email: usernameOrEmail.contains('@') ? usernameOrEmail : 'mock@mytogether.com',
      fullName: 'Together User',
      role: 'USER',
    );

    final mockUser = UserModel(
      id: mockResponse.id,
      username: mockResponse.username,
      email: mockResponse.email,
      fullName: mockResponse.fullName,
      role: mockResponse.role,
    );

    // Ensure the mock token is set globally
    AuthService().updateAccessToken(mockResponse.token);

    // Save session locally to enable navigation to main app
    await _saveSession(mockResponse, profile: mockUser, locations: []);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    // MOCK REGISTER: Skip API calls and allow any registration
    print('[MOCK] Registering and logging in...');
    
    final mockResponse = AuthResponse(
      token: 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock_refresh_token',
      id: DateTime.now().millisecondsSinceEpoch,
      username: username,
      email: email,
      fullName: fullName,
      role: 'USER',
    );

    final mockUser = UserModel(
      id: mockResponse.id,
      username: mockResponse.username,
      email: mockResponse.email,
      fullName: mockResponse.fullName,
      role: mockResponse.role,
    );

    AuthService().updateAccessToken(mockResponse.token);
    await _saveSession(mockResponse, profile: mockUser, locations: []);
  }

  Future<void> logout() async {
    // MOCK LOGOUT: Skip API call and clear local session only
    print('[MOCK] Logging out locally...');
    await AuthService().clearSession();
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
