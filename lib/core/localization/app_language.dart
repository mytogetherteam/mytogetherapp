import 'package:flutter/widgets.dart';

/// Supported app languages.
///
/// [code] matches the suffix used by the backend multilingual fields
/// (e.g. `nameEn` / `nameMm` / `nameTh`).
enum AppLanguage {
  en('en', 'English', 'English'),
  mm('mm', 'Myanmar', 'မြန်မာ'),
  th('th', 'Thai', 'ไทย');

  const AppLanguage(this.code, this.englishName, this.nativeName);

  /// Short code: `en`, `mm`, `th`.
  final String code;

  /// Name in English (e.g. "Myanmar").
  final String englishName;

  /// Name in its own script (e.g. "မြန်မာ").
  final String nativeName;

  /// Resolve a stored/string code back to an [AppLanguage].
  /// Falls back to [AppLanguage.mm] for unknown values.
  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.mm;
    final normalized = code.toLowerCase();
    for (final lang in AppLanguage.values) {
      if (lang.code == normalized) return lang;
    }
    // Tolerate common ISO variants.
    switch (normalized) {
      case 'my':
      case 'mya':
      case 'bur':
        return AppLanguage.mm;
      case 'tha':
        return AppLanguage.th;
      default:
        return AppLanguage.mm;
    }
  }

  /// Material/Cupertino [Locale] (uses ISO `my` for Myanmar).
  Locale get locale => Locale(this == AppLanguage.mm ? 'my' : code);
}
