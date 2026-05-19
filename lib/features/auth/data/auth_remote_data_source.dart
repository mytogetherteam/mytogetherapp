import 'package:dio/dio.dart';
import 'models/auth_models.dart';
import 'models/user_location_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/auth/user_model.dart';
import '../../../core/auth/auth_service.dart';

class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource() : _dio = ApiClient().dio;

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/auth/login',
      data: request.toJson(),
    );
    final responseData = response.data;
    if (responseData['success'] == false) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: Response(
          requestOptions: response.requestOptions,
          statusCode: 401,
          data: responseData,
        ),
      );
    }
    final data = responseData['data'];
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/auth/register',
      data: request.toJson(),
    );
    final responseData = response.data;
    if (responseData['success'] == false) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: Response(
          requestOptions: response.requestOptions,
          statusCode: 400,
          data: responseData,
        ),
      );
    }
    final data = responseData['data'];
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<String> refreshToken(String refreshToken) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return data['token'] as String? ?? data['accessToken'] as String? ?? '';
  }

  Future<void> logout({String? token}) async {
    try {
      final t = token ?? AuthService().refreshToken;
      await _dio.post('${ApiClient.apiPrefix}/auth/logout', data: {'refreshToken': t ?? ''});
    } catch (_) {}
  }

  Future<UserModel> getUserProfile() async {
    final response = await _dio.get('${ApiClient.apiPrefix}/users/profile');
    final data = response.data['data'];
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<UserLocationModel>> getUserLocations() async {
    // Bypass missing backend endpoint to prevent persistent 404 errors in console
    return [];
  }
}
