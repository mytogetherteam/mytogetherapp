import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/google_maps_config.dart';
import 'google_places_client.dart';
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
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == 0 || lon1 == 0 || lat2 == 0 || lon2 == 0) return 0;
    
    const R = 6371.0; // Earth radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

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

  /// Forward geocode: search using Autocomplete + Text Search, then Geocoding fallback.
  Future<List<PlaceResult>> searchPlaces(String query, {double? lat, double? lon}) {
    if (!GoogleMapsConfig.placesSearchEnabled) return Future.value([]);
    return _client.searchPlaces(query, lat: lat, lon: lon);
  }

  /// Pre-fetches the details (including lat/lon) for a specific place_id if it's missing them.
  Future<PlaceResult?> getPlaceDetails(PlaceResult place) {
    return _client.getPlaceDetails(place);
  }

  Future<PlaceResult?> nearbySearch(double lat, double lon) async {
    if (kIsWeb) return null; // Fallback or implement if needed
    return _client.nearbySearch(lat, lon);
  }

  /// Reverse geocode: get full address string and components from coordinates.
  /// On web, Nominatim is tried first (fast, no billing). Google is the fallback.
  Future<PlaceResult?> reverseGeocode(double lat, double lon) async {
    if (kIsWeb) {
      return _reverseGeocodeWebFirst(lat, lon);
    }
    return _reverseGeocodeGoogleFirst(lat, lon);
  }

  Future<PlaceResult?> _reverseGeocodeWebFirst(double lat, double lon) async {
    try {
      final nominatim = await NominatimGeocoder.reverseGeocode(lat, lon)
          .timeout(const Duration(seconds: 6));
      if (nominatim != null && nominatim.displayName.trim().isNotEmpty) {
        return nominatim;
      }
    } catch (_) {}

    try {
      final google = await _client
          .reverseGeocode(lat, lon)
          .timeout(const Duration(seconds: 4));
      if (google != null && google.displayName.trim().isNotEmpty) {
        return google;
      }
    } catch (_) {}

    return null;
  }

  Future<PlaceResult?> _reverseGeocodeGoogleFirst(double lat, double lon) async {
    try {
      // 1. Try to snap to a nearby POI (within 30m) like Grab does
      final nearby = await nearbySearch(lat, lon).timeout(const Duration(seconds: 4));
      if (nearby != null && nearby.name.trim().isNotEmpty) {
        return nearby;
      }
    } catch (_) {}

    try {
      final google = await _client
          .reverseGeocode(lat, lon)
          .timeout(const Duration(seconds: 4));
      if (google != null && google.displayName.trim().isNotEmpty) {
        final type = google.type ?? '';
        if (google.placeId.isNotEmpty &&
            (type.contains('establishment') ||
                type.contains('point_of_interest') ||
                type.contains('premise') ||
                type.contains('building'))) {
          // If it's a POI, fetch the true name using Place Details
          // Zero lat/lon to force getPlaceDetails to actually fetch.
          final details = await getPlaceDetails(google.copyWith(lat: 0, lon: 0));
          if (details != null && details.name.trim().isNotEmpty) {
            return google.copyWith(name: details.name);
          }
        }
        return google;
      }
    } catch (_) {}

    try {
      return await NominatimGeocoder.reverseGeocode(lat, lon)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }
}
