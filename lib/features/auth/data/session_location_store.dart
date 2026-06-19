import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the session "current location" address locally until the backend
/// accepts full address fields on saved locations.
class SessionLocationData {
  final double latitude;
  final double longitude;
  final String address;

  const SessionLocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      };

  factory SessionLocationData.fromJson(Map<String, dynamic> json) {
    return SessionLocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address']?.toString() ?? '',
    );
  }
}

class SessionLocationStore {
  SessionLocationStore._();

  static const _prefsKey = 'session_delivery_location';

  static Future<void> save({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(
        SessionLocationData(
          latitude: latitude,
          longitude: longitude,
          address: trimmed,
        ).toJson(),
      ),
    );
  }

  static Future<SessionLocationData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return SessionLocationData.fromJson(Map<String, dynamic>.from(map));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Returns a stored address when the pin is within [maxMeters] of [lat]/[lon].
  static Future<String?> addressNear(
    double lat,
    double lon, {
    double maxMeters = 150,
  }) async {
    final stored = await load();
    if (stored == null || stored.address.trim().isEmpty) return null;
    if (_distanceMeters(stored.latitude, stored.longitude, lat, lon) <= maxMeters) {
      return stored.address.trim();
    }
    return null;
  }

  static double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final rLat1 = _toRad(lat1);
    final rLat2 = _toRad(lat2);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
