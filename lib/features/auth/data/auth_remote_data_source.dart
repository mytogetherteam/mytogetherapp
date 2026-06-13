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
      '${ApiClient.apiPrefix}/user/auth/login',
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
      '${ApiClient.apiPrefix}/user/auth/register',
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
      '${ApiClient.apiPrefix}/user/auth/refresh',
      data: {'refreshToken': refreshToken},
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
    final data = responseData['data'] as Map<String, dynamic>? ?? {};
    return data['token'] as String? ?? data['accessToken'] as String? ?? '';
  }

  Future<bool> checkPhoneExists(String phone) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/user/auth/check-phone',
      data: {'phone': phone},
    );
    final data = response.data['data'];
    return data['exists'] == true;
  }

  Future<void> logout() async {
    try {
      final token = AuthService().refreshToken;
      await _dio.post(
        '${ApiClient.apiPrefix}/user/auth/logout',
        data: {'refreshToken': token ?? ''},
      );
    } catch (_) {}
  }

  Future<void> deleteAccount({String? password}) async {
    // Backend: DELETE /api/user/account (UsersController.deleteAccount).
    // The endpoint ignores body fields; password is intentionally not sent.
    await _dio.delete('${ApiClient.apiPrefix}/user/account');
  }

  Future<UserModel> getUserProfile() async {
    final response = await _dio.get('${ApiClient.apiPrefix}/user/profile');
    final data = response.data['data'] ?? response.data;
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  /// Backend: PUT /api/user/profile (UsersController.updateProfile).
  /// Accepts name, username, phone, address and an optional `profilePhoto`
  /// file. When [profilePhotoPath] is provided the request is sent as
  /// multipart/form-data (matching the backend's `FileInterceptor`), otherwise
  /// a plain JSON body is used.
  Future<UserModel> updateUserProfile({
    String? name,
    String? username,
    String? phone,
    String? address,
    String? profilePhotoPath,
  }) async {
    final Response response;
    if (profilePhotoPath != null && profilePhotoPath.isNotEmpty) {
      final formData = FormData.fromMap({
        'name': ?name,
        'username': ?username,
        'phone': ?phone,
        'address': ?address,
        'profilePhoto': await _multipartFromPath(profilePhotoPath),
      });
      response = await _dio.put(
        '${ApiClient.apiPrefix}/user/profile',
        data: formData,
      );
    } else {
      response = await _dio.put(
        '${ApiClient.apiPrefix}/user/profile',
        data: {
          'name': ?name,
          'username': ?username,
          'phone': ?phone,
          'address': ?address,
        },
      );
    }
    final data = response.data['data'] ?? response.data;
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  /// Uploads only a new profile photo via `PUT /api/user/profile` (multipart
  /// `profilePhoto` field). Returns the updated profile with its fresh
  /// `avatarUrl`.
  Future<UserModel> uploadAvatar(String filePath) {
    return updateUserProfile(profilePhotoPath: filePath);
  }

  Future<MultipartFile> _multipartFromPath(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    final filename =
        'profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return MultipartFile.fromFile(
      filePath,
      filename: filename,
      contentType: DioMediaType.parse(mimeType),
    );
  }

  Future<List<UserLocationModel>> getUserLocations() async {
    try {
      final response = await _dio.get('${ApiClient.apiPrefix}/user/locations');
      final raw = response.data;
      final List<dynamic> data =
          (raw is Map && raw['data'] is List) ? (raw['data'] as List) : (raw is List ? raw : <dynamic>[]);
      return data
          .map((e) => UserLocationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
