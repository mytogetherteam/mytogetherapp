import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'locale_controller.dart';
import 'translations/en_translations.dart';
import 'translations/mm_translations.dart';
import 'translations/th_translations.dart';

/// Static UI string translations keyed by a dotted string id.
///
/// To add a new string: add the key to each language map in
/// `translations/{en,mm,th}_translations.dart` and use it via
/// `context.tr('your.key')` or `LocaleController.instance.tr('your.key')`.
///
/// Missing keys fall back to English, then to the raw key so problems are
/// visible during development rather than crashing.
class AppTranslations {
  AppTranslations._();

  static String translate(String key, AppLanguage language) {
    final table = _all[language] ?? _en;
    return table[key] ?? _en[key] ?? key;
  }

  static const Map<AppLanguage, Map<String, String>> _all = {
    AppLanguage.en: _en,
    AppLanguage.mm: _mm,
    AppLanguage.th: _th,
  };

  // ---------------------------------------------------------------------------
  // The per-language tables live in translations/*.dart so this file stays small
  // and editing one language does not touch the others.
  // ---------------------------------------------------------------------------
  static const Map<String, String> _en = kEnTranslations;
  static const Map<String, String> _mm = kMmTranslations;
  static const Map<String, String> _th = kThTranslations;
}

/// Convenience access from any widget. Because the root [MaterialApp] is
/// rebuilt whenever [LocaleController] changes, widgets using `context.tr(...)`
/// re-render automatically on language switch.
extension LocalizationX on BuildContext {
  String tr(String key) => LocaleController.instance.tr(key);

  String trArgs(String key, Map<String, String> params) =>
      LocaleController.instance.trArgs(key, params);

  AppLanguage get appLanguage => LocaleController.instance.language;

  String localized({String? en, String? mm, String? th}) =>
      LocaleController.instance.localized(en: en, mm: mm, th: th);

  String relativeTime(DateTime date, {String olderFormat = 'MMM d'}) =>
      LocaleController.instance.relativeTime(date, olderFormat: olderFormat);

  String countdown(Duration remaining) =>
      LocaleController.instance.countdown(remaining);

  String localizedStatus(String status) =>
      LocaleController.instance.localizedStatus(status);
}

