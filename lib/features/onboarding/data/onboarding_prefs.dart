import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPrefs {
  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }

  static Future<void> setHasSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, value);
  }
}
