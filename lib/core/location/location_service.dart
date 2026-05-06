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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(const Duration(seconds: 2));
      if (!serviceEnabled) return await _useFallback();

      LocationPermission permission = await Geolocator.checkPermission().timeout(const Duration(seconds: 2));
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(const Duration(seconds: 5));
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return await _useFallback();
      }

      // Try last known first (instant)
      Position? last = await Geolocator.getLastKnownPosition().timeout(const Duration(seconds: 2));
      if (last != null) {
        _cachedPosition = last;
        await _reverseGeocode(last.latitude, last.longitude).timeout(const Duration(seconds: 3));
        return last;
      }

      // Otherwise get fresh position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      ).timeout(const Duration(seconds: 6));
      _cachedPosition = pos;
      await _reverseGeocode(pos.latitude, pos.longitude).timeout(const Duration(seconds: 3));
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
