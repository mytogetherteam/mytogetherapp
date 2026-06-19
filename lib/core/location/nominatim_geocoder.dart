import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'location_search_service.dart';

/// OpenStreetMap Nominatim reverse geocoder — free fallback when Google fails.
class NominatimGeocoder {
  NominatimGeocoder._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {
        'User-Agent': 'MyTogetherApp/1.0 (delivery location picker)',
      },
    ),
  );

  static Future<PlaceResult?> reverseGeocode(double lat, double lon) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'format': 'jsonv2',
          'addressdetails': 1,
        },
      );

      final data = response.data;
      if (data == null) return null;

      final displayName = data['display_name']?.toString().trim();
      if (displayName == null || displayName.isEmpty) return null;

      final address = data['address'] as Map<String, dynamic>? ?? {};
      final name = _shortName(address) ?? displayName.split(',').first.trim();

      return PlaceResult(
        placeId: data['place_id']?.toString() ?? '',
        name: name,
        displayName: displayName,
        lat: double.tryParse(data['lat']?.toString() ?? '') ?? lat,
        lon: double.tryParse(data['lon']?.toString() ?? '') ?? lon,
        type: data['type']?.toString(),
      );
    } catch (e) {
      debugPrint('NOMINATIM REVERSE GEOCODE FAILED: $e');
      return null;
    }
  }

  static String? _shortName(Map<String, dynamic> address) {
    for (final key in [
      'road',
      'pedestrian',
      'footway',
      'neighbourhood',
      'suburb',
      'city',
      'town',
      'village',
    ]) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
