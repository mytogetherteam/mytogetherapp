import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_search_service.dart';

/// Singleton that fetches and caches the device's current position and address.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Bangkok fallback — only used when GPS is unavailable.
  static const double defaultLat = 13.7563;
  static const double defaultLon = 100.5018;

  Position? _cachedPosition;
  String? _currentAddress;
  bool _cachedIsFallback = false;
  bool _locationPermissionPrompted = false;

  Position? get cachedPosition =>
      _cachedIsFallback ? null : _cachedPosition;
  bool get hasRealPosition => _cachedPosition != null && !_cachedIsFallback;
  double get lat => _cachedPosition?.latitude ?? defaultLat;
  double get lon => _cachedPosition?.longitude ?? defaultLon;
  String? get currentAddress => _currentAddress;

  void clearCache() {
    _cachedPosition = null;
    _cachedIsFallback = false;
    _currentAddress = null;
  }

  Future<Position> getCurrentPosition({
    bool requestPermissionIfDenied = false,
    bool forceRefresh = false,
    bool highAccuracy = false,
  }) async {
    if (!forceRefresh && _cachedPosition != null && !_cachedIsFallback) {
      return _cachedPosition!;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(Duration(seconds: kIsWeb ? 5 : 4));
      if (!serviceEnabled) return _useFallback();

      var permission = await Geolocator.checkPermission()
          .timeout(Duration(seconds: kIsWeb ? 5 : 4));
      if (permission == LocationPermission.denied) {
        if (requestPermissionIfDenied && !_locationPermissionPrompted) {
          _locationPermissionPrompted = true;
          permission = await Geolocator.requestPermission()
              .timeout(Duration(seconds: kIsWeb ? 10 : 8));
        } else {
          return _useFallback();
        }
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _useFallback();
      }

      if (!forceRefresh && !kIsWeb) {
        final last = await Geolocator.getLastKnownPosition()
            .timeout(const Duration(seconds: 3));
        if (last != null && _isAcceptableAccuracy(last, highAccuracy)) {
          _storePosition(last, isFallback: false);
          await _reverseGeocode(last.latitude, last.longitude)
              .timeout(const Duration(seconds: 8));
          return last;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _buildLocationSettings(highAccuracy: highAccuracy),
      ).timeout(Duration(seconds: kIsWeb ? 18 : 15));

      _storePosition(pos, isFallback: false);
      await _reverseGeocode(pos.latitude, pos.longitude)
          .timeout(const Duration(seconds: 8));
      return pos;
    } catch (_) {
      return _useFallback();
    }
  }

  LocationSettings _buildLocationSettings({required bool highAccuracy}) {
    final accuracy =
        highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium;
    final timeLimit = Duration(seconds: kIsWeb ? 15 : 12);

    if (kIsWeb) {
      return WebSettings(
        accuracy: accuracy,
        timeLimit: timeLimit,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
          distanceFilter: 0,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
          distanceFilter: 0,
        );
      default:
        return LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        );
    }
  }

  bool _isAcceptableAccuracy(Position position, bool highAccuracy) {
    if (highAccuracy) return position.accuracy <= 100;
    return position.accuracy <= 500 || position.accuracy <= 0;
  }

  void _storePosition(Position position, {required bool isFallback}) {
    _cachedPosition = position;
    _cachedIsFallback = isFallback;
    if (isFallback) {
      _currentAddress = null;
    }
  }

  Future<void> _reverseGeocode(double latitude, double longitude) async {
    if (_currentAddress != null) return;
    try {
      final result =
          await LocationSearchService.instance.reverseGeocode(latitude, longitude);
      if (result != null) {
        _currentAddress = result.displayName;
      }
    } catch (_) {}
  }

  Future<Position> _useFallback() {
    _storePosition(
      Position(
        latitude: defaultLat,
        longitude: defaultLon,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
      isFallback: true,
    );
    return Future.value(_cachedPosition!);
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
