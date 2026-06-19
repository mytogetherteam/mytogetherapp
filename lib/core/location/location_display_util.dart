/// Helpers for showing human-readable addresses alongside GPS coordinates.
class LocationDisplayUtil {
  LocationDisplayUtil._();

  static final RegExp _coordinatePattern = RegExp(
    r'^-?\d+\.\d+\s*,\s*-?\d+\.\d+$',
  );

  static String formatCoordinates(
    double lat,
    double lon, {
    int fractionDigits = 5,
  }) {
    return '${lat.toStringAsFixed(fractionDigits)}, '
        '${lon.toStringAsFixed(fractionDigits)}';
  }

  static bool looksLikeCoordinates(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    return _coordinatePattern.hasMatch(trimmed);
  }

  /// Returns a displayable address, ignoring raw coordinate strings.
  static String? readableAddress(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (looksLikeCoordinates(trimmed)) return null;
    return trimmed;
  }

  /// Picks the best address from several optional fields.
  static String? firstReadableAddress(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      final readable = readableAddress(candidate);
      if (readable != null) return readable;
    }
    return null;
  }
}
