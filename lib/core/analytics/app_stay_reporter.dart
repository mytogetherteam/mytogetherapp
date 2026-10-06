import 'package:dio/dio.dart';

import '../../features/auth/data/repositories/user_location_repository.dart';
import '../auth/auth_service.dart';
import '../location/location_service.dart';
import '../network/api_client.dart';

/// Reports how long the customer app stayed in the foreground, plus the
/// location the app already has, so the admin dashboard can show time in
/// the app and district. Coordinates are only sent for matching; the server
/// stores the district.
class AppStayReporter {
  static DateTime? _startedAt;

  static void markForeground() {
    _startedAt ??= DateTime.now();
  }

  static Future<void> reportAndReset() async {
    final started = _startedAt;
    _startedAt = null;
    if (started == null || !AuthService().isLoggedIn) return;

    final seconds = DateTime.now().difference(started).inSeconds;
    if (seconds < 5) return;
    final durationSeconds = seconds > 6 * 3600 ? 6 * 3600 : seconds;

    double? lat;
    double? lng;
    final position = LocationService().cachedPosition;
    if (position != null) {
      lat = position.latitude;
      lng = position.longitude;
    } else {
      final active = UserLocationRepository.instance.activeLocation;
      lat = active?.latitude;
      lng = active?.longitude;
    }

    try {
      await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/user/app-sessions',
        data: {
          'durationSeconds': durationSeconds,
          if (lat != null && lng != null) 'latitude': lat,
          if (lat != null && lng != null) 'longitude': lng,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
    } catch (_) {
      // Leaving the app must still succeed if this report fails.
    }
  }
}
