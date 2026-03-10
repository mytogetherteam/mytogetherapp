import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'user_model.dart';
import '../../features/auth/data/models/user_location_model.dart';
import '../notifications/notification_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyUsername = 'username';
  static const _keyEmail = 'user_email';
  static const _keyFullName = 'user_full_name';
  static const _keyRole = 'user_role';
  static const _keyUserLocations = 'user_locations';
  static const _keyUserProfile = 'user_profile';

  String? _accessToken;
  String? _refreshToken;
  UserModel? _currentUser;
  List<UserLocationModel>? _userLocations;
  bool _initialized = false;

  /// Call once at app startup in main()
  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_keyAccessToken);
    _refreshToken = prefs.getString(_keyRefreshToken);

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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setInt(_keyUserId, user.id);
    await prefs.setString(_keyUsername, user.username);
    await prefs.setString(_keyEmail, user.email);
    await prefs.setString(_keyFullName, user.fullName);
    await prefs.setString(_keyRole, user.role);
    
    // Save full profile and locations
    await prefs.setString(_keyUserProfile, json.encode(user.toJson()));
    if (userLocations != null) {
      await prefs.setString(_keyUserLocations, json.encode(userLocations.map((e) => e.toJson()).toList()));
    } else {
      await prefs.remove(_keyUserLocations);
    }

    // Register FCM token for the new session
    await NotificationService().registerDevice();
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Wipes all local preferences, essentially clearing all simple caches
  }

  void updateAccessToken(String newToken) {
    _accessToken = newToken;
    SharedPreferences.getInstance().then((p) => p.setString(_keyAccessToken, newToken));
  }

  Future<void> updateTokens(String accessToken, String? refreshToken) async {
    _accessToken = accessToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
      await prefs.setString(_keyRefreshToken, refreshToken);
    }
  }

  Future<String?> performRefresh(Dio dio) async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return null;
    }

    try {
      final response = await dio.post(
        '${ApiClient.apiPrefix}/auth/refresh',
        data: {'refreshToken': _refreshToken},
        options: Options(headers: {'Authorization': ''}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        final newToken = data['token'] as String? ?? data['accessToken'] as String? ?? '';
        final newRefreshToken = data['refreshToken'] as String?;
        
        if (newToken.isNotEmpty) {
          await updateTokens(newToken, newRefreshToken);
          return newToken;
        }
      }
    } catch (e) {
      // Refresh failed
      return null;
    }
    return null;
  }
}
