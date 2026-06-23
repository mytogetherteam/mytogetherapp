/// Approximate bounding box for Thailand (mainland + common service area).
/// Used to gate location-based food feeds outside the supported region.
class ThailandBounds {
  ThailandBounds._();

  static const double minLat = 5.61;
  static const double maxLat = 20.47;
  static const double minLon = 97.34;
  static const double maxLon = 105.64;

  static bool contains(double latitude, double longitude) {
    return latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLon &&
        longitude <= maxLon;
  }
}
