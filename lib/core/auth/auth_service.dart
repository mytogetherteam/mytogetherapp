import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'user_model.dart';
import '../../features/auth/data/models/user_location_model.dart';
import '../notifications/notification_service.dart';
import 'jwt_utils.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  // Non-sensitive user data stays in SharedPreferences
  static const _keyUserId = 'user_id';
  static const _keyUsername = 'username';
  static const _keyEmail = 'user_email';
  static const _keyFullName = 'user_full_name';
  static const _keyRole = 'user_role';
  static const _keyUserLocations = 'user_locations';
  static const _keyUserProfile = 'user_profile';

  // Secure storage for tokens only
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _accessToken;
  String? _refreshToken;
  UserModel? _currentUser;
  List<UserLocationModel>? _userLocations;
  bool _initialized = false;

  // Mutex: only one refresh request runs at a time.
  // Other callers await the same future instead of firing duplicate requests.
  Completer<String?>? _refreshCompleter;

  /// Called when the session is cleared due to token expiry or explicit logout.
  /// Wire this up in app.dart or wherever navigation is available.
  void Function()? onSessionExpired;

  /// Call once at app startup in main()
  Future<void> initialize() async {
    if (_initialized) return;

    // Read tokens from secure storage
    try {
      _accessToken = await _secureStorage.read(key: _keyAccessToken);
      _refreshToken = await _secureStorage.read(key: _keyRefreshToken);
    } catch (e) {
      // Keystore might be corrupted due to reinstall or debug app
      await _secureStorage.deleteAll();
      _accessToken = null;
      _refreshToken = null;
    }

    // Read non-sensitive profile data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getInt(_keyUserId);
    final username = prefs.getString(_keyUsername);
    final email = prefs.getString(_keyEmail);
    final fullName = prefs.getString(_keyFullName);
    final role = prefs.getString(_keyRole);

    if (userId != null && username != null && email != null) {
      _currentUser = UserModel(
        id: userId,
        username: username,
        email: email,
        fullName: fullName ?? '',
        role: role ?? 'USER',
      );
    }

    final locationsJson = prefs.getString(_keyUserLocations);
    if (locationsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(locationsJson);
        _userLocations = decoded.map((e) => UserLocationModel.fromJson(e)).toList();
      } catch (_) {
        _userLocations = null;
      }
    }

    final profileJson = prefs.getString(_keyUserProfile);
    if (profileJson != null && _currentUser != null) {
      try {
        final Map<String, dynamic> decodedProfile = json.decode(profileJson);
        _currentUser = UserModel.fromJson(decodedProfile);
      } catch (_) {}
    }

    _initialized = true;
  }

  bool get isLoggedIn => _accessToken != null && _accessToken!.isNotEmpty;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  UserModel? get currentUser => _currentUser;
  List<UserLocationModel>? get userLocations => _userLocations;

  int? get defaultLocationId {
    if (_userLocations == null || _userLocations!.isEmpty) return null;
    return _userLocations!.first.id;
  }

  bool get isTokenNearlyExpired {
    if (_accessToken == null) return true;
    // Check if it expires in less than 60 seconds
    return JwtUtils.isExpired(_accessToken!, offsetSeconds: 60);
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required UserModel user,
    List<UserLocationModel>? userLocations,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _currentUser = user;
    _userLocations = userLocations;

    // Store tokens securely
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);

    // Store non-sensitive profile data in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, user.id);
    await prefs.setString(_keyUsername, user.username);
    await prefs.setString(_keyEmail, user.email);
    await prefs.setString(_keyFullName, user.fullName);
    await prefs.setString(_keyRole, user.role);
    await prefs.setString(_keyUserProfile, json.encode(user.toJson()));
    if (userLocations != null) {
      await prefs.setString(_keyUserLocations, json.encode(userLocations.map((e) => e.toJson()).toList()));
    } else {
      await prefs.remove(_keyUserLocations);
    }

    // Register FCM token for the new session if permission is already granted.
    // Native permission request is now handled by MainNavigationScreen rationale modal.
    await NotificationService().registerDevice();
  }

  Future<void> clearSession({bool navigate = true}) async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;

    // Clear tokens from secure storage
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);

    // Clear remaining profile data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Navigate to login screen if a callback is registered
    if (navigate && onSessionExpired != null) {
      onSessionExpired!();
    }
  }

  void updateAccessToken(String newToken) {
    _accessToken = newToken;
    _secureStorage.write(key: _keyAccessToken, value: newToken);
  }

  /// Updates the locally cached profile after a successful profile edit.
  Future<void> updateCurrentUser(UserModel user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, user.username);
    await prefs.setString(_keyEmail, user.email);
    await prefs.setString(_keyFullName, user.fullName);
    await prefs.setString(_keyUserProfile, json.encode(user.toJson()));
  }

  Future<void> updateTokens(String accessToken, String? refreshToken) async {
    _accessToken = accessToken;
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
      await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
    }
  }

  /// Refreshes the access token. If a refresh is already in flight,
  /// all concurrent callers wait for the same result instead of sending
  /// duplicate requests (which would invalidate a single-use refresh token).
  Future<String?> performRefresh(Dio dio) async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return null;
    }

    // If a refresh is already running, wait for it and return the same result
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();
    try {
      final response = await dio.post(
        '${ApiClient.apiPrefix}/user/auth/refresh',
        data: {'refreshToken': _refreshToken},
      );

      String? newToken;
      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          newToken = data['token'] as String? ?? data['accessToken'] as String? ?? '';
          final newRefreshToken = data['refreshToken'] as String?;
          if (newToken.isNotEmpty) {
            await updateTokens(newToken, newRefreshToken);
          } else {
            newToken = null;
          }
        }
      }

      _refreshCompleter!.complete(newToken);
      return newToken;
    } catch (e) {
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      // Reset so the next expiry can start a fresh refresh cycle
      _refreshCompleter = null;
    }
  }
}
