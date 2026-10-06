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

  /// Short address for tight UI slots such as the food tab header.
  ///
  /// Uses the first comma-separated segment (usually street/soi) and caps length.
  static String compactAddress(String? value, {int maxLength = 32}) {
    final readable = readableAddress(value);
    if (readable == null) return '';

    final segments = readable
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    var short = readable;
    if (segments.isNotEmpty) {
      short = segments.first;
      // If the first segment is very short or just a number (e.g. "945"), 
      // include the street name (second segment) for better context
      final isNumeric = int.tryParse(short) != null;
      if ((isNumeric || short.length <= 4) && segments.length > 1) {
        short = '$short ${segments[1]}';
      }
    }

    if (short.length <= maxLength) return short;
    return '${short.substring(0, maxLength - 1).trim()}…';
  }
}
