import 'dart:math' as math;

/// Great-circle distance helpers shared by restaurant and menu feeds.
class GeoDistance {
  GeoDistance._();

  static const String defaultDeliveryEta = '20-30 min';

  /// Show a confirm dialog when delivery distance exceeds this (km).
  /// GrabFood long-distance is typically up to ~10 km.
  static const double distanceConfirmThresholdKm = 10.0;

  /// Delivery ETA label from straight-line distance (matches feed DTOs).
  static String deliveryEtaFromKm(double distanceKm) {
    if (distanceKm <= 0) return defaultDeliveryEta;
    var minTime = (distanceKm * 2.0).round();
    if (minTime < 1) minTime = 1;
    final maxTime = minTime + 5;
    return '$minTime-$maxTime min';
  }

  /// Haversine distance in kilometers.
  static double haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Applies a standard 1.4x detour factor to straight-line distance to estimate driving distance.
  static double estimatedRoutingKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return haversineKm(lat1, lon1, lat2, lon2) * 1.4;
  }

  static double? tryParseCoord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// Prefer a positive API distance; otherwise compute from shop coordinates.
  static double? resolveDistanceKm({
    required double originLat,
    required double originLon,
    double? apiDistanceKm,
    double? shopLat,
    double? shopLon,
  }) {
    if (apiDistanceKm != null && apiDistanceKm > 0) return apiDistanceKm;
    if (shopLat == null || shopLon == null) return apiDistanceKm;
    return estimatedRoutingKm(originLat, originLon, shopLat, shopLon);
  }

  static double? shopDistanceFromJson(
    Map<String, dynamic> json, {
    required double originLat,
    required double originLon,
  }) {
    final shopMap =
        json['shop'] is Map<String, dynamic> ? json['shop'] as Map<String, dynamic> : null;

    final rawDistance = json['distanceKm'] ??
        shopMap?['distanceKm'] ??
        json['shopDistanceKm'];
    double? apiDistanceKm;
    if (rawDistance is num) {
      apiDistanceKm = rawDistance.toDouble();
    } else if (rawDistance != null) {
      apiDistanceKm = double.tryParse(rawDistance.toString());
    }

    final shopLat = tryParseCoord(shopMap?['latitude'] ?? json['shopLatitude']);
    final shopLon = tryParseCoord(shopMap?['longitude'] ?? json['shopLongitude']);

    return resolveDistanceKm(
      originLat: originLat,
      originLon: originLon,
      apiDistanceKm: apiDistanceKm,
      shopLat: shopLat,
      shopLon: shopLon,
    );
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
