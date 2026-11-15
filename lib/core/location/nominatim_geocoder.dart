import 'package:dio/dio.dart';

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
        // Request English names first so we get "Lumpini Ville Ramkhamhaeng 44"
        // instead of "ลุมพินี วิลล์ รามคำแหง 44" or "แขวงคลองจั่น".
        'Accept-Language': 'en, th;q=0.8',
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
      final category = data['category']?.toString() ?? '';
      final osmName = data['name']?.toString().trim() ?? '';
      final itemLat = double.tryParse(data['lat']?.toString() ?? '') ?? lat;
      final itemLon = double.tryParse(data['lon']?.toString() ?? '') ?? lon;

      // Distance check: If the returned OSM feature is > 50 meters from the pin,
      // it is a distant landmark/condo and must NOT be used as the pin's building name.
      final distKm = PlaceResult.haversine(lat, lon, itemLat, itemLon);
      final isDistant = distKm > 0.05;

      // Priority: building/condo keys (only if within 50m) > road > fallback
      String name = _bestName(address, osmName, category, ignoreBuildings: isDistant)
          ?? displayName.split(',').first.trim();

      String finalDisplay = displayName;
      if (isDistant) {
        // Strip the distant building name if it prefixes the address string
        final rawBuilding = _bestName(address, osmName, category, ignoreBuildings: false);
        if (rawBuilding != null && rawBuilding.isNotEmpty) {
          if (finalDisplay.startsWith('$rawBuilding,')) {
            finalDisplay = finalDisplay.substring(rawBuilding.length + 1).trim();
          } else if (finalDisplay.startsWith(rawBuilding)) {
            finalDisplay = finalDisplay.substring(rawBuilding.length).trim();
            if (finalDisplay.startsWith(',')) {
              finalDisplay = finalDisplay.substring(1).trim();
            }
          }
        }
      }

      return PlaceResult(
        placeId: data['place_id']?.toString() ?? '',
        name: name,
        displayName: finalDisplay,
        lat: itemLat,
        lon: itemLon,
        type: data['type']?.toString(),
        distanceKm: distKm,
      );
    } catch (e) {
      return null;
    }
  }

  /// OpenStreetMap Nominatim forward search — 100% free search fallback
  static Future<List<PlaceResult>> search(String query, {double? lat, double? lon}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final params = <String, dynamic>{
        'q': trimmed,
        'format': 'jsonv2',
        'addressdetails': 1,
        'limit': 10,
        'countrycodes': 'th,mm',
      };
      if (lat != null && lon != null) {
        // Bias search towards user's current location (+/- 0.5 degrees ~55km)
        params['viewbox'] = '${lon - 0.5},${lat + 0.5},${lon + 0.5},${lat - 0.5}';
      }

      final response = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: params,
      );

      final list = response.data;
      if (list == null || list.isEmpty) return [];

      return list.map((item) {
        final data = item as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};
        final displayName = data['display_name']?.toString().trim() ?? '';
        final category = data['category']?.toString() ?? '';
        final osmName = data['name']?.toString().trim() ?? '';
        final name = _bestName(address, osmName, category)
            ?? displayName.split(',').first.trim();
        final itemLat = double.tryParse(data['lat']?.toString() ?? '') ?? 0;
        final itemLon = double.tryParse(data['lon']?.toString() ?? '') ?? 0;

        return PlaceResult(
          placeId: data['place_id']?.toString() ?? '',
          name: name,
          displayName: displayName,
          lat: itemLat,
          lon: itemLon,
          type: data['type']?.toString(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns the best human-readable short name for a place.
  ///
  /// Priority order (matching what Grab/Google shows):
  /// 1. Building / condo / amenity keys in the address object
  /// 2. The OSM `name` field when the feature is NOT a road or boundary
  /// 3. Road / street name
  /// 4. Sub-district / district
  static String? _bestName(
    Map<String, dynamic> address,
    String osmName,
    String category, {
    bool ignoreBuildings = false,
  }) {
    if (!ignoreBuildings) {
      // 1. Building / establishment / POI address keys
      for (final key in [
        'building',
        'condominium',
        'apartments',
        'residential',
        'house_name',
        'amenity',
        'shop',
        'leisure',
        'hotel',
        'office',
        'tourism',
        'commercial',
        'neighbourhood',
      ]) {
        final value = address[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }

      // 2. OSM element name when it is a named building/POI (not a road or boundary)
      if (osmName.isNotEmpty &&
          category != 'highway' &&
          category != 'boundary' &&
          category != 'place') {
        return osmName;
      }
    }

    // 3. Street / road
    for (final key in ['road', 'pedestrian', 'footway', 'street']) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    // 4. Administrative area (last resort)
    for (final key in ['quarter', 'suburb', 'city_district', 'village', 'town', 'city']) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }
}
