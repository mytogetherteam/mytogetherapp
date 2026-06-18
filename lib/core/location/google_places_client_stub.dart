import 'location_search_service.dart';

/// Fallback when neither io nor html is available (tests).
class GooglePlacesClient {
  GooglePlacesClient._();
  static final GooglePlacesClient instance = GooglePlacesClient._();

  Future<List<PlaceResult>> searchPlaces(
    String query, {
    double? lat,
    double? lon,
  }) async =>
      [];

  Future<PlaceResult?> getPlaceDetails(PlaceResult place) async => place;

  Future<PlaceResult?> reverseGeocode(double lat, double lon) async => null;
}
