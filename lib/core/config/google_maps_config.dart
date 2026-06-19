import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Shared Google Maps / Places API key used across map widgets and HTTP calls.
class GoogleMapsConfig {
  GoogleMapsConfig._();

  static const String _fallbackKey = 'AIzaSyDDp0l6jJqFbpSzfX7tBN2nsFkSY9x_5RU';

  static String get apiKey {
    try {
      final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (key != null && key.isNotEmpty && key != 'YOUR_NEW_API_KEY_HERE') {
        return key;
      }
    } catch (_) {
      // DotEnv not loaded (e.g. tests) — use fallback.
    }
    return _fallbackKey;
  }

  /// Places text search / autocomplete (paid). Off until billing is enabled.
  static const bool placesSearchEnabled = false;
}
