import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/google_maps_config.dart';
import 'location_search_service.dart';

/// Direct Google Maps REST calls — works on mobile/desktop (no browser CORS).
class GooglePlacesClient {
  GooglePlacesClient._();
  static final GooglePlacesClient instance = GooglePlacesClient._();

  static String get _apiKey => GoogleMapsConfig.apiKey;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://maps.googleapis.com/maps/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<List<PlaceResult>> searchPlaces(
    String query, {
    double? lat,
    double? lon,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final results = await Future.wait([
        _autocomplete(query, lat: lat, lon: lon),
        _textSearch(query, lat: lat, lon: lon),
      ]);
      final merged = _mergeByPlaceId([...results[0], ...results[1]]);
      if (merged.isNotEmpty) return merged;
      return _geocodeSearch(query, lat: lat, lon: lon);
    } catch (e) {
      debugPrint('PLACES API EXCEPTION: $e');
      return [];
    }
  }

  List<PlaceResult> _mergeByPlaceId(List<PlaceResult> places) {
    final seen = <String>{};
    final merged = <PlaceResult>[];
    for (final place in places) {
      if (place.placeId.isEmpty) continue;
      if (seen.add(place.placeId)) {
        merged.add(place);
      }
    }
    return merged;
  }

  Future<List<PlaceResult>> _autocomplete(
    String query, {
    double? lat,
    double? lon,
  }) async {
    final params = <String, dynamic>{
      'input': query,
      'key': _apiKey,
      'language': 'en',
    };

    if (lat != null && lon != null) {
      params['location'] = '$lat,$lon';
      params['radius'] = 50000;
    }

    final response =
        await _dio.get('/place/autocomplete/json', queryParameters: params);
    final status = response.data['status']?.toString() ?? '';

    if (status == 'OK') {
      final predictions = response.data['predictions'] as List<dynamic>? ?? [];
      return predictions
          .map((e) => PlaceResult.fromGooglePlace(e as Map<String, dynamic>))
          .toList();
    }

    if (status == 'ZERO_RESULTS') return [];
    debugPrint('PLACES AUTOCOMPLETE FAILED: ${response.data}');
    return [];
  }

  Future<PlaceResult?> nearbySearch(double lat, double lon) async {
    try {
      final response = await _dio.get('/place/nearbysearch/json', queryParameters: {
        'location': '$lat,$lon',
        'rankby': 'distance',
        'type': 'point_of_interest',
        'key': _apiKey,
        'language': 'en',
      });
      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List<dynamic>? ?? [];
        for (final r in results) {
          final res = r as Map<String, dynamic>;
          final types = (res['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          // Skip generic routes and localities, we want buildings or establishments
          if (types.contains('route') || types.contains('locality') || types.contains('political')) continue;
          
          if (types.contains('establishment') || types.contains('point_of_interest') || types.contains('premise') || types.contains('building')) {
             final place = PlaceResult.fromGoogleNearbySearch(res, userLat: lat, userLon: lon);
             if (place.distanceKm != null && place.distanceKm! > 0.05) {
               // Too far (> 50m), don't snap to it
               continue;
             }
             return place;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<PlaceResult>> _textSearch(
    String query, {
    double? lat,
    double? lon,
  }) async {
    try {
      final params = <String, dynamic>{
        'query': query,
        'key': _apiKey,
        'language': 'en',
        'region': 'th',
      };

      if (lat != null && lon != null) {
        params['location'] = '$lat,$lon';
        params['radius'] = 50000;
      }

      final response =
          await _dio.get('/place/textsearch/json', queryParameters: params);
      final status = response.data['status']?.toString() ?? '';

      if (status == 'OK') {
        final results = response.data['results'] as List<dynamic>? ?? [];
        return results
            .take(20)
            .map(
              (e) => PlaceResult.fromGoogleTextSearch(
                e as Map<String, dynamic>,
                userLat: lat,
                userLon: lon,
              ),
            )
            .toList();
      }

      if (status == 'ZERO_RESULTS') return [];
      debugPrint('PLACES TEXT SEARCH FAILED: ${response.data}');
    } catch (e) {
      debugPrint('PLACES TEXT SEARCH EXCEPTION: $e');
    }
    return [];
  }

  Future<List<PlaceResult>> _geocodeSearch(
    String query, {
    double? lat,
    double? lon,
  }) async {
    try {
      final params = <String, dynamic>{
        'address': query,
        'key': _apiKey,
        'components': 'country:th',
        'language': 'en',
      };
      if (lat != null && lon != null) {
        params['bounds'] =
            '${lat - 0.45},${lon - 0.45}|${lat + 0.45},${lon + 0.45}';
      }

      final response = await _dio.get('/geocode/json', queryParameters: params);
      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List<dynamic>? ?? [];
        return results
            .take(10)
            .map(
              (e) => PlaceResult.fromGoogleGeocode(
                e as Map<String, dynamic>,
                userLat: lat,
                userLon: lon,
              ),
            )
            .toList();
      }
      debugPrint('GEOCODE SEARCH FAILED: ${response.data}');
    } catch (e) {
      debugPrint('GEOCODE SEARCH EXCEPTION: $e');
    }
    return [];
  }

  Future<PlaceResult?> getPlaceDetails(PlaceResult place) async {
    if (place.lat != 0 && place.lon != 0) return place;

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
          name: place.name,
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
          Map<String, dynamic>? bestResult;
          for (final r in results) {
            final res = r as Map<String, dynamic>;
            final types = (res['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            if (types.contains('establishment') ||
                types.contains('point_of_interest') ||
                types.contains('premise') ||
                types.contains('building')) {
              bestResult = res;
              break;
            }
          }
          bestResult ??= results.first as Map<String, dynamic>;

          return PlaceResult.fromGoogleGeocode(
            bestResult,
            userLat: lat,
            userLon: lon,
          );
        }
      } else {
        debugPrint('REVERSE GEOCODE API FAILED: ${response.data}');
      }
      return null;
    } catch (e) {
      debugPrint('REVERSE GEOCODE EXCEPTION: $e');
      return null;
    }
  }
}
