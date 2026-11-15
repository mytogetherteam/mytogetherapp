import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/google_maps_config.dart';
import 'google_places_client.dart';
import 'local_poi_directory.dart';
import 'native_device_geocoder.dart';
import 'nominatim_geocoder.dart';

/// Result from a Google Maps Places/Geocoding query.
class PlaceResult {
  final String placeId;
  final String name;
  final String displayName;
  final double lat;
  final double lon;
  final String? type;
  final double? distanceKm;

  const PlaceResult({
    required this.placeId,
    required this.name,
    required this.displayName,
    required this.lat,
    required this.lon,
    this.type,
    this.distanceKm,
  });

  PlaceResult copyWith({
    String? placeId,
    String? name,
    String? displayName,
    double? lat,
    double? lon,
    String? type,
    double? distanceKm,
  }) {
    return PlaceResult(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      type: type ?? this.type,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  /// Factory for Google Maps Places API (Autocomplete) results
  /// Note: Autocomplete doesn't return lat/lon directly without a details call,
  /// but we can use this for the initial list.
  factory PlaceResult.fromGooglePlace(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] as Map<String, dynamic>? ?? {};
    final mainText = structuredFormatting['main_text'] as String? ?? json['description']?.toString().split(',').first ?? '';
    final secondaryText = structuredFormatting['secondary_text'] as String? ?? json['description']?.toString() ?? '';

    return PlaceResult(
      placeId: json['place_id']?.toString() ?? '',
      name: mainText,
      displayName: secondaryText.isNotEmpty ? '$mainText, $secondaryText' : mainText,
      lat: 0, // Needs Details API call later if selected
      lon: 0, 
      type: (json['types'] as List?)?.firstOrNull?.toString(),
    );
  }

  /// Factory for Google Maps Places Text Search API results.
  factory PlaceResult.fromGoogleTextSearch(
    Map<String, dynamic> json, {
    double? userLat,
    double? userLon,
  }) {
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final location = geometry['location'] as Map<String, dynamic>? ?? {};
    final lat = double.tryParse(location['lat']?.toString() ?? '') ?? 0;
    final lon = double.tryParse(location['lng']?.toString() ?? '') ?? 0;
    final name = json['name']?.toString() ?? '';
    final address = json['formatted_address']?.toString() ?? name;

    double? distance;
    if (userLat != null && userLon != null) {
      distance = _haversine(userLat, userLon, lat, lon);
    }

    return PlaceResult(
      placeId: json['place_id']?.toString() ?? '',
      name: name,
      displayName: address,
      lat: lat,
      lon: lon,
      type: (json['types'] as List?)?.firstOrNull?.toString(),
      distanceKm: distance,
    );
  }

  /// Factory for Google Maps Geocoding API results (Reverse Geocode or specific place details)
  factory PlaceResult.fromGoogleGeocode(Map<String, dynamic> json, {double? userLat, double? userLon}) {
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final location = geometry['location'] as Map<String, dynamic>? ?? {};
    final lat = double.tryParse(location['lat']?.toString() ?? '') ?? 0;
    final lon = double.tryParse(location['lng']?.toString() ?? '') ?? 0;

    double? distance;
    if (userLat != null && userLon != null) {
      distance = _haversine(userLat, userLon, lat, lon);
    }

    final addressComponents = json['address_components'] as List<dynamic>? ?? [];
    String name = json['formatted_address']?.toString().split(',').first ?? '';
    
    // Try to find a better short name (like a route or point of interest)
    for (var comp in addressComponents) {
      final types = (comp['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      if (types.contains('route') || types.contains('point_of_interest') || types.contains('premise')) {
        name = comp['short_name']?.toString() ?? name;
        break;
      }
    }

    return PlaceResult(
      placeId: json['place_id']?.toString() ?? '',
      name: name,
      displayName: json['formatted_address'] as String? ?? '',
      lat: lat,
      lon: lon,
      type: (json['types'] as List?)?.firstOrNull?.toString(),
      distanceKm: distance,
    );
  }

  /// Factory for Google Maps Places Nearby Search API results
  factory PlaceResult.fromGoogleNearbySearch(Map<String, dynamic> json, {double? userLat, double? userLon}) {
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final location = geometry['location'] as Map<String, dynamic>? ?? {};
    final lat = double.tryParse(location['lat']?.toString() ?? '') ?? 0;
    final lon = double.tryParse(location['lng']?.toString() ?? '') ?? 0;
    final name = json['name']?.toString() ?? '';
    final vicinity = json['vicinity']?.toString() ?? name;

    double? distance;
    if (userLat != null && userLon != null) {
      distance = _haversine(userLat, userLon, lat, lon);
    }

    return PlaceResult(
      placeId: json['place_id']?.toString() ?? '',
      name: name,
      displayName: vicinity,
      lat: lat,
      lon: lon,
      type: (json['types'] as List?)?.firstOrNull?.toString(),
      distanceKm: distance,
    );
  }

  /// Create a copy with evaluated distance
  PlaceResult copyWithDistance(double userLat, double userLon) {
     return PlaceResult(
      placeId: placeId,
      name: name,
      displayName: displayName,
      lat: lat,
      lon: lon,
      type: type,
      distanceKm: _haversine(userLat, userLon, lat, lon),
    );
  }

  /// Haversine formula for distance in km
  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == 0 || lon1 == 0 || lat2 == 0 || lon2 == 0) return 0;
    
    const R = 6371.0; // Earth radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) =>
      haversine(lat1, lon1, lat2, lon2);

  static double _toRad(double deg) => deg * pi / 180;

  /// Human-readable distance string
  String get distanceLabel {
    if (distanceKm == null || distanceKm == 0) return '';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()}m';
    return '${distanceKm!.toStringAsFixed(2)}km';
  }
}

/// Service for searching places using Google Maps (REST on mobile, JS SDK on web).
class LocationSearchService {
  static final LocationSearchService instance = LocationSearchService._internal();
  LocationSearchService._internal();

  final GooglePlacesClient _client = GooglePlacesClient.instance;

  String? _sessionToken;

  /// Generates a RFC 4122 v4 UUID for Google Places API session bundling
  static String _generateSessionToken() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Start or retrieve active session token
  String _getOrCreateSessionToken() {
    return _sessionToken ??= _generateSessionToken();
  }

  /// Reset session token once a place is selected or search is cleared
  void resetSession() {
    _sessionToken = null;
  }

  static final Map<String, PlaceResult> _reverseGeocodeCache = {};

  /// Forward geocode: search places with 100% $0 cost.
  /// 1. Searches local curated POI directory (condos, landmarks) -> $0.
  /// 2. Searches OpenStreetMap Nominatim -> $0.
  Future<List<PlaceResult>> searchPlaces(String query, {double? lat, double? lon}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final results = <PlaceResult>[];

    // 1. Check Local POI Directory first ($0 cost)
    final localMatches = LocalPoiDirectory.search(trimmed, lat: lat, lon: lon);
    results.addAll(localMatches);

    // 2. OpenStreetMap Nominatim free forward search ($0 cost)
    try {
      final osmResults = await NominatimGeocoder.search(trimmed, lat: lat, lon: lon);
      for (final r in osmResults) {
        if (!results.any((x) => x.name == r.name || x.displayName == r.displayName)) {
          results.add(r);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('OSM search error: $e');
    }

    return results;
  }

  /// Pre-fetches the details (including lat/lon) for a specific place_id if it's missing them.
  /// Passes the active session token to bundle with autocomplete, then terminates the session.
  Future<PlaceResult?> getPlaceDetails(PlaceResult place) async {
    final token = _sessionToken;
    final result = await _client.getPlaceDetails(place, sessionToken: token);
    resetSession();
    return result;
  }

  Future<PlaceResult?> nearbySearch(double lat, double lon) async {
    if (kIsWeb) return null; // Fallback or implement if needed
    return _client.nearbySearch(lat, lon);
  }

  /// Reverse geocode: get full address string and components from coordinates.
  /// 100% $0 GUARANTEED ZERO COST:
  /// 1. Memory grid cache (~11m) -> $0.
  /// 2. Local POI Directory (e.g. LESTO CONDO Sukhumvit113, Niche ID) -> $0.
  /// 3. Device Native Geocoder (Apple CoreLocation on iOS, Android System Geocoder on Android) -> $0.
  /// 4. OpenStreetMap Nominatim fallback -> $0.
  /// Zero Google Places or Geocoding API billing.
  Future<PlaceResult?> reverseGeocode(double lat, double lon) async {
    // Check Local POI Directory ($0 cost) first
    final localPoi = LocalPoiDirectory.findNearby(lat, lon);

    // 1. Instant Cache check (~11 meter precision grid)
    final cacheKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
    if (_reverseGeocodeCache.containsKey(cacheKey)) {
      final cached = _reverseGeocodeCache[cacheKey]!;
      if (localPoi != null && !cached.displayName.contains(localPoi.name)) {
        final enhanced = cached.copyWith(
          name: localPoi.name,
          displayName: '${localPoi.name}, ${cached.displayName}',
        );
        _reverseGeocodeCache[cacheKey] = enhanced;
        return enhanced;
      }
      return cached;
    }

    PlaceResult? result;

    // 3. Try Device Native Geocoder (Apple CoreLocation on iOS, Android System Geocoder on Android)
    try {
      result = await NativeDeviceGeocoder.reverseGeocode(lat, lon);
    } catch (e) {
      if (kDebugMode) debugPrint('Native geocoder error: $e');
      result = null;
    }

    // 4. Try OpenStreetMap Nominatim ($0 free fallback)
    if (result == null || result.displayName.trim().isEmpty) {
      try {
        result = await NominatimGeocoder.reverseGeocode(lat, lon)
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        if (kDebugMode) debugPrint('Nominatim reverse error: $e');
        result = null;
      }
    }

    // 5. Combine with matched Local POI (e.g. "LESTO CONDO Sukhumvit113")
    if (result != null) {
      PlaceResult finalPlace = result;
      if (localPoi != null) {
        final poiName = localPoi.name;
        final rawDisplay = result.displayName.trim();
        final display = rawDisplay.contains(poiName)
            ? rawDisplay
            : '$poiName, $rawDisplay';
        finalPlace = result.copyWith(
          name: poiName,
          displayName: display,
        );
      }
      _putCache(cacheKey, finalPlace);
      return finalPlace;
    }

    // 6. If both geocoders failed but Local POI was found, return it directly
    if (localPoi != null) {
      final poiPlace = PlaceResult(
        placeId: 'local_${localPoi.name.replaceAll(' ', '_')}',
        name: localPoi.name,
        displayName: localPoi.name,
        lat: lat,
        lon: lon,
      );
      _putCache(cacheKey, poiPlace);
      return poiPlace;
    }

    return null;
  }

  static void _putCache(String key, PlaceResult place) {
    _reverseGeocodeCache[key] = place;
    if (_reverseGeocodeCache.length > 100) {
      _reverseGeocodeCache.remove(_reverseGeocodeCache.keys.first);
    }
  }
}
