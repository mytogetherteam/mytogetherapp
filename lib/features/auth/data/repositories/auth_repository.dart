import 'package:dio/dio.dart';
import '../auth_remote_data_source.dart';
import '../models/auth_models.dart';
import '../models/user_location_model.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/media/picked_image.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/auth/user_model.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../../core/auth/session_realtime.dart';
import 'user_location_repository.dart';

class AuthRepository {
  static final AuthRepository instance = AuthRepository._internal();
  AuthRepository._internal();

  final AuthRemoteDataSource _dataSource = AuthRemoteDataSource();

  Future<void> login({required String phone, required String pin}) async {
    try {
      final response = await _dataSource.login(
        LoginRequest(phone: phone, pin: pin),
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
      await SessionRealtime.bootstrap();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> register({
    required String idToken,
    required String pin,
    String? name,
    String? email,
  }) async {
    try {
      final response = await _dataSource.register(
        RegisterRequest(idToken: idToken, pin: pin, name: name, email: email),
      );
      
      AuthService().updateAccessToken(response.token);
      
      final profile = await _dataSource.getUserProfile();
      final locations = await _dataSource.getUserLocations();

      await _saveSession(response, profile: profile, locations: locations);
      await SessionRealtime.bootstrap();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<bool> checkPhoneExists(String phone) async {
    try {
      return await _dataSource.checkPhoneExists(phone);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> resetPassword({required String phone, required String idToken, required String newPin}) async {
    try {
      await _dataSource.resetPassword(idToken: idToken, newPin: newPin);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> logout() async {
    try {
      if (AuthService().isLoggedIn) {
        await NotificationService().unregisterDevice();
        await _dataSource.logout();
      }
    } catch (_) {
      // Ignore network errors on logout.
      // Main goal is ensuring the user is locally logged out.
    } finally {
      NotificationRepository().setUnreadCount(0);
      await AuthService().clearSession(navigate: false);
      UserLocationRepository.instance.clearCachedLocationsForSignOut();
      await UserLocationRepository.instance.ensureSessionCurrentLocationFromDevice(
        requestPermissionIfDenied: false,
      );
    }
  }

  /// Updates the current user's profile and refreshes the cached session.
  /// When [profilePhoto] is provided, the new photo is uploaded in the
  /// same request (backend: PUT /api/user/profile multipart `profilePhoto`).
  Future<UserModel> updateProfile({
    String? name,
    String? username,
    String? phone,
    String? email,
    String? address,
    PickedImage? profilePhoto,
  }) async {
    try {
      final updated = await _dataSource.updateUserProfile(
        name: name,
        username: username,
        phone: phone,
        email: email,
        address: address,
        profilePhoto: profilePhoto,
      );
      await AuthService().updateCurrentUser(updated);
      return updated;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  /// Uploads a new profile photo, then refreshes the cached session so the
  /// avatar updates everywhere it's shown.
  Future<UserModel> updateAvatar(PickedImage image) async {
    try {
      final updated = await _dataSource.uploadAvatar(image);
      await AuthService().updateCurrentUser(updated);
      return updated;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> deleteAccount({required String password}) async {
    try {
      await NotificationService().unregisterDevice();
      await _dataSource.deleteAccount(password: password);
    } on DioException catch (e) {
      throw _parseError(e);
    } finally {
      NotificationRepository().setUnreadCount(0);
      await AuthService().clearSession(navigate: false);
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
    String? details;
    String? message;
    if (body is Map) {
      final rawDetails = body['details'];
      details = rawDetails is List ? rawDetails.join(', ') : rawDetails?.toString();
      final rawMessage = body['message'];
      message = rawMessage is List ? rawMessage.join(', ') : rawMessage?.toString();
    }
    final text = details?.isNotEmpty == true ? details : message;

    if (statusCode == 401 || statusCode == 400) {
      return text ?? LocaleController.instance.tr('auth.invalid_credentials');
    }
    if (statusCode == 409) {
      return text ?? LocaleController.instance.tr('auth.username_exists');
    }
    if (statusCode == 429) {
      return LocaleController.instance.tr('auth.too_many_attempts');
    }
    return text ?? LocaleController.instance.tr('auth.connection_failed');
  }
}
