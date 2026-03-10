import 'package:geolocator/geolocator.dart';
import 'location_search_service.dart';

/// Singleton that fetches and caches the device's current position and address.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Bangkok fallback
  static const double defaultLat = 13.7563;
  static const double defaultLon = 100.5018;

  Position? _cachedPosition;
  String? _currentAddress;

  Position? get cachedPosition => _cachedPosition;
  double get lat => _cachedPosition?.latitude ?? defaultLat;
  double get lon => _cachedPosition?.longitude ?? defaultLon;
  String? get currentAddress => _currentAddress;

  Future<Position> getCurrentPosition() async {
    if (_cachedPosition != null) return _cachedPosition!;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return await _useFallback();

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return await _useFallback();
      }

      // Try last known first (instant)
      Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _cachedPosition = last;
        await _reverseGeocode(last.latitude, last.longitude);
        return last;
      }

      // Otherwise get fresh position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _cachedPosition = pos;
      await _reverseGeocode(pos.latitude, pos.longitude);
      return pos;
    } catch (_) {
      return await _useFallback();
    }
  }

  Future<void> _reverseGeocode(double latitude, double longitude) async {
    if (_currentAddress != null) return;
    try {
      final result = await LocationSearchService.instance.reverseGeocode(latitude, longitude);
      if (result != null) {
        _currentAddress = result.displayName;
      }
    } catch (_) {}
  }

  Future<Position> _useFallback() async {
    return Position(
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
    );
  }
}
