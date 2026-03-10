import 'package:dio/dio.dart';
import 'models/auth_models.dart';
import 'models/user_location_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/auth/user_model.dart';

class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource() : _dio = ApiClient().dio;

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/auth/login',
      data: request.toJson(),
    );
    final data = response.data['data'];
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/auth/register',
      data: request.toJson(),
    );
    final data = response.data['data'];
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

  Future<void> logout() async {
    await _dio.post('${ApiClient.apiPrefix}/auth/logout');
  }

  Future<UserModel> getUserProfile() async {
    final response = await _dio.get('${ApiClient.apiPrefix}/user/profile');
    final data = response.data['data'];
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<UserLocationModel>> getUserLocations() async {
    final response = await _dio.get('${ApiClient.apiPrefix}/user-locations');
    final List<dynamic> data = response.data['data'];
    return data.map((e) => UserLocationModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
