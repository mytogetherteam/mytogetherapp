import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'location_search_service.dart';

@JS('MapsPlacesBridge.searchPlaces')
external JSPromise<JSString> _jsSearchPlaces(
  JSString query,
  JSNumber? lat,
  JSNumber? lon,
);

@JS('MapsPlacesBridge.getPlaceDetails')
external JSPromise<JSString> _jsGetPlaceDetails(
  JSString placeId,
  JSString? name,
  JSString? displayName,
);

@JS('MapsPlacesBridge.reverseGeocode')
external JSPromise<JSString> _jsReverseGeocode(
  JSNumber lat,
  JSNumber lon,
);

/// Google Maps JavaScript SDK — avoids REST CORS on Flutter web.
class GooglePlacesClient {
  GooglePlacesClient._();
  static final GooglePlacesClient instance = GooglePlacesClient._();

  Future<List<PlaceResult>> searchPlaces(
    String query, {
    double? lat,
    double? lon,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final json = await _awaitJsonString(
        _jsSearchPlaces(query.toJS, lat?.toJS, lon?.toJS),
      );
      return _parsePlaceList(json);
    } catch (e, stack) {
      debugPrint('WEB PLACES SEARCH EXCEPTION: $e\n$stack');
      return [];
    }
  }

  Future<PlaceResult?> getPlaceDetails(PlaceResult place) async {
    if (place.lat != 0 && place.lon != 0) return place;
    if (place.placeId.isEmpty) return place;

    try {
      final json = await _awaitJsonString(
        _jsGetPlaceDetails(
          place.placeId.toJS,
          place.name.toJS,
          place.displayName.toJS,
        ),
      );
      if (json == 'null') return place;
      return _parsePlace(json) ?? place;
    } catch (e, stack) {
      debugPrint('WEB PLACE DETAILS EXCEPTION: $e\n$stack');
      return place;
    }
  }

  Future<PlaceResult?> reverseGeocode(double lat, double lon) async {
    try {
      final json = await _awaitJsonString(
        _jsReverseGeocode(lat.toJS, lon.toJS),
      );
      if (json == 'null') return null;
      return _parsePlace(json);
    } catch (e, stack) {
      debugPrint('WEB REVERSE GEOCODE EXCEPTION: $e\n$stack');
      return null;
    }
  }

  Future<String> _awaitJsonString(JSPromise<JSString> promise) async {
    final JSString value = await promise.toDart;
    return value.toDart;
  }

  List<PlaceResult> _parsePlaceList(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) return [];
    return decoded
        .map((item) => _parsePlaceMap(item))
        .whereType<PlaceResult>()
        .toList(growable: false);
  }

  PlaceResult? _parsePlace(String json) {
    final decoded = jsonDecode(json);
    if (decoded == null) return null;
    return _parsePlaceMap(decoded);
  }

  PlaceResult? _parsePlaceMap(Object? raw) {
    if (raw is! Map) return null;

    final placeId = raw['placeId']?.toString() ?? '';
    final name = raw['name']?.toString() ?? '';
    final displayName = raw['displayName']?.toString() ?? name;
    final lat = double.tryParse(raw['lat']?.toString() ?? '') ?? 0;
    final lon = double.tryParse(raw['lon']?.toString() ?? '') ?? 0;
    final type = raw['type']?.toString();

    return PlaceResult(
      placeId: placeId,
      name: name,
      displayName: displayName,
      lat: lat,
      lon: lon,
      type: type,
    );
  }
}
