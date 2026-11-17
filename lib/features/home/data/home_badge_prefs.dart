import 'package:shared_preferences/shared_preferences.dart';

class HomeBadgePrefs {
  static const String keyHasSeenHomeBadges = 'has_seen_home_category_badges';
  static const String keyIsFirstTimeHomeBadges = 'is_first_time_home_badges';
  static const String keyVisitedOtherServices = 'has_visited_other_services_badge';
  static const String keyVisitedCurrency = 'has_visited_currency_badge';
  static const String keyVisitedVisa = 'has_visited_visa_badge';
  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';

  /// Called when a user completes onboarding or registers, marking them as a first-time user
  /// eligible to see the home category badges on their first visit.
  static Future<void> markEligibleForFirstTimeBadges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsFirstTimeHomeBadges, true);
  }

  /// Check whether the home category badges should be displayed.
  /// Only returns true if the user is a first-time user (e.g. just completed onboarding
  /// or fresh install) and hasn't yet completed their first home badge view.
  static Future<bool> shouldShowHomeBadges() async {
    final prefs = await SharedPreferences.getInstance();

    final bool? hasSeenHomeBadges = prefs.getBool(keyHasSeenHomeBadges);
    if (hasSeenHomeBadges == true) {
      return false;
    }

    final bool isFirstTimeFromOnboarding =
        prefs.getBool(keyIsFirstTimeHomeBadges) ?? false;
    if (isFirstTimeFromOnboarding) {
      return true;
    }

    final bool hasSeenOnboarding =
        prefs.getBool(_keyHasSeenOnboarding) ?? false;
    // If user already completed onboarding before this feature was introduced
    // (and was never marked as a first-time user for these badges),
    // they are an existing/returning user. Do not show badges to them.
    if (hasSeenOnboarding) {
      await prefs.setBool(keyHasSeenHomeBadges, true);
      return false;
    }

    // Fresh install without onboarding completed yet (e.g. dev/guest direct launch)
    return true;
  }

  /// Mark the home category badges as seen so returning users won't see them again.
  static Future<void> markHomeBadgesSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasSeenHomeBadges, true);
    await prefs.setBool(keyIsFirstTimeHomeBadges, false);
  }

  static Future<bool> hasVisitedOtherServices() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyVisitedOtherServices) ?? false;
  }

  static Future<void> markVisitedOtherServices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyVisitedOtherServices, true);
  }

  static Future<bool> hasVisitedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyVisitedCurrency) ?? false;
  }

  static Future<void> markVisitedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyVisitedCurrency, true);
  }

  static Future<bool> hasVisitedVisa() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyVisitedVisa) ?? false;
  }

  static Future<void> markVisitedVisa() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyVisitedVisa, true);
  }
}
