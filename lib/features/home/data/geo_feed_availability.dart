import '../../../core/location/thailand_bounds.dart';
import '../../auth/data/repositories/user_location_repository.dart';
import 'repositories/restaurant_repository.dart';

/// Shared probe used by Home and Food tabs to decide whether location-based
/// feeds should render or the "Nothing here for now" card.
class GeoFeedAvailability {
  GeoFeedAvailability._();

  /// `true` when at least one trending/nearby probe returns data inside Thailand.
  static Future<bool> hasLocationFeeds() async {
    try {
      final coords =
          await UserLocationRepository.instance.resolveActiveCoordinates();

      if (!ThailandBounds.contains(coords.lat, coords.lon)) {
        return false;
      }

      var trendingHasData = false;
      var nearbyHasData = false;

      try {
        final trendingSection = await RestaurantRepository.instance
            .getTrendingItems(
              lat: coords.lat,
              lon: coords.lon,
              radiusKm: 10.0,
              size: 1,
            )
            .timeout(const Duration(seconds: 10));
        trendingHasData = trendingSection.items.isNotEmpty;
      } catch (_) {
        // API error — no data for this probe.
      }

      try {
        final nearbyShops = await RestaurantRepository.instance
            .getNearbyShops(
              lat: coords.lat,
              lon: coords.lon,
              radius: 10.0,
              size: 1,
            )
            .timeout(const Duration(seconds: 10));
        nearbyHasData = nearbyShops.isNotEmpty;
      } catch (_) {
        // API error — no data for this probe.
      }

      return trendingHasData || nearbyHasData;
    } catch (_) {
      return false;
    }
  }
}
