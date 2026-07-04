import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Shared Google Maps / Places API key used across map widgets and HTTP calls.
class GoogleMapsConfig {
  GoogleMapsConfig._();

  static String get apiKey {
    try {
      final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (key != null && key.isNotEmpty && key != 'YOUR_NEW_API_KEY_HERE') {
        return key;
      }
    } catch (_) {
      // DotEnv not loaded (e.g. tests)
    }
    return '';
  }

  /// Places text search / autocomplete (paid). Off until billing is enabled.
  static const bool placesSearchEnabled = false;
}
