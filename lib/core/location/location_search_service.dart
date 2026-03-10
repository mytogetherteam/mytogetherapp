import 'package:dio/dio.dart';
import 'dart:math';

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

/// Service for searching places using the Google Maps APIs.
class LocationSearchService {
  static final LocationSearchService instance = LocationSearchService._internal();
  LocationSearchService._internal();

  static const String _apiKey = 'AIzaSyDeKocCUJZ7ocLBB8ZelixW2Cr1tMiwapM';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://maps.googleapis.com/maps/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Forward geocode: search for places by query using Google Places Autocomplete API.
  Future<List<PlaceResult>> searchPlaces(String query, {double? lat, double? lon}) async {
    if (query.trim().isEmpty) return [];

    try {
      final params = <String, dynamic>{
        'input': query,
        'key': _apiKey,
        'components': 'country:th', // STRICTLY RESTRICT TO THAILAND
        'language': 'en',
      };

      // Bias results towards user's current location if available
      if (lat != null && lon != null) {
        params['location'] = '$lat,$lon';
        params['radius'] = 50000; // 50km radius bias
      }

      final response = await _dio.get('/place/autocomplete/json', queryParameters: params);

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final predictions = response.data['predictions'] as List<dynamic>? ?? [];
        
        // We use Place API for search autocomplete. 
        // Note: It doesn't return lat/lon natively, we'll map what we have.
        // We could fetch details for each, but that is 1 API call per result (expensive).
        return predictions
            .map((e) => PlaceResult.fromGooglePlace(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Pre-fetches the details (including lat/lon) for a specific place_id if it's missing them.
  Future<PlaceResult?> getPlaceDetails(PlaceResult place) async {
    if (place.lat != 0 && place.lon != 0) return place; // Already has coordinates
    
    try {
      final response = await _dio.get('/place/details/json', queryParameters: {
        'place_id': place.placeId,
        'key': _apiKey,
        'fields': 'geometry,name,formatted_address,type',
      });

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final result = response.data['result'] as Map<String, dynamic>;
        final geometry = result['geometry'] as Map<String, dynamic>? ?? {};
        final location = geometry['location'] as Map<String, dynamic>? ?? {};
        
        final lat = double.tryParse(location['lat']?.toString() ?? '') ?? 0;
        final lon = double.tryParse(location['lng']?.toString() ?? '') ?? 0;

        return PlaceResult(
          placeId: place.placeId,
          name: place.name, // Keep autocomplete's clean short name
          displayName: place.displayName,
          lat: lat,
          lon: lon,
          type: place.type,
          distanceKm: place.distanceKm,
        );
      }
    } catch (_) {}
    return place;
  }

  /// Reverse geocode: get full address string and components from coordinates.
  Future<PlaceResult?> reverseGeocode(double lat, double lon) async {
    try {
      final response = await _dio.get('/geocode/json', queryParameters: {
        'latlng': '$lat,$lon',
        'key': _apiKey,
        'language': 'en',
      });

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
           return PlaceResult.fromGoogleGeocode(results.first as Map<String, dynamic>, userLat: lat, userLon: lon);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
