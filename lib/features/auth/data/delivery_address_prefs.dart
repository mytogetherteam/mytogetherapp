import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/guest_auth_guard.dart';
import 'models/user_location_model.dart';
import 'repositories/user_location_repository.dart';

/// One-time client flag: user has completed first delivery address setup.
class DeliveryAddressPrefs {
  DeliveryAddressPrefs._();

  static const String _keyCompleted = 'delivery_address_setup_completed';

  static Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCompleted) ?? false;
  }

  static Future<void> setCompletedSetup(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompleted, value);
  }

  static bool hasSavedAddress(Iterable<UserLocationModel> locations) =>
      locations.any((l) => l.id > 0);

  /// Signed-in users with no saved backend address must add one before delivery.
  static Future<bool> requiresForcedSetup() async {
    if (GuestAuthGuard.isGuest) return false;
    if (await hasCompletedSetup()) return false;

    final locations =
        await UserLocationRepository.instance.getRawLocations();
    if (hasSavedAddress(locations)) {
      await setCompletedSetup(true);
      return false;
    }
    return true;
  }
}
