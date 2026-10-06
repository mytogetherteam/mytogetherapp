import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_translations.dart';
import 'language_policy_client.dart';

/// Holds the currently selected [AppLanguage] for the whole app and
/// notifies listeners (e.g. the root [MaterialApp]) when it changes.
///
/// Usage:
///   final lang = LocaleController.instance.language;
///   final label = LocaleController.instance.tr('profile.edit_profile');
///   final name = LocaleController.instance.localized(en: ..., mm: ..., th: ...);
class LocaleController extends ChangeNotifier {
  LocaleController._internal();

  static final LocaleController instance = LocaleController._internal();

  static const String _prefsKey = 'app_language';

  AppLanguage _language = AppLanguage.mm;
  AppLanguage get language => _language;

  bool _initialized = false;
  Timer? _policyTimer;
  int _policyGeneration = 0;
  static const String _forceTokenKey = 'language_force_token';
  static const String _beforeForceKey = 'language_before_force';

  /// Load the persisted language, then apply the admin language switch.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _language = AppLanguage.fromCode(prefs.getString(_prefsKey) ?? AppLanguage.mm.code);
    } catch (_) {
      _language = AppLanguage.mm;
    }
    _initialized = true;
    await refreshLanguagePolicy();
    _policyTimer ??= Timer.periodic(const Duration(seconds: 45), (_) {
      refreshLanguagePolicy();
    });
  }

  /// When an admin turns this app's switch on, remember the current language
  /// and set Thai. People can change it afterward. Turning the switch off
  /// restores the language from before that switch was turned on.
  /// A failed request leaves the current language alone.
  Future<void> refreshLanguagePolicy() async {
    final generation = ++_policyGeneration;
    final push = await LanguagePolicyClient.fetch('customer');
    if (generation != _policyGeneration || push == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _policyGeneration) return;
      if (!push.enabled) {
        await _restoreLanguage(prefs);
        return;
      }
      final token = push.at;
      if (token == null || token.isEmpty) return;
      if (prefs.getString(_forceTokenKey) == token) return;
      if (prefs.getString(_beforeForceKey) == null) {
        await prefs.setString(
          _beforeForceKey,
          prefs.getString(_prefsKey) ?? _language.code,
        );
      }
      if (_language != AppLanguage.th) {
        _language = AppLanguage.th;
        notifyListeners();
      }
      await prefs.setString(_prefsKey, AppLanguage.th.code);
      await prefs.setString(_forceTokenKey, token);
    } catch (_) {}
  }

  Future<void> _restoreLanguage(SharedPreferences prefs) async {
    final before = prefs.getString(_beforeForceKey);
    if (before == null) return;
    final restored = AppLanguage.fromCode(before);
    if (_language != restored) {
      _language = restored;
      notifyListeners();
    }
    await prefs.setString(_prefsKey, restored.code);
    await prefs.remove(_beforeForceKey);
    await prefs.remove(_forceTokenKey);
  }

  /// Change the active language and persist it.
  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, language.code);
    } catch (_) {
      // Persisting is best-effort; the in-memory value already updated the UI.
    }
  }

  /// Translate a static UI string [key] to the current language.
  String tr(String key) => AppTranslations.translate(key, _language);

  /// Translate [key] and replace `{placeholder}` tokens from [params].
  String trArgs(String key, Map<String, String> params) {
    var result = tr(key);
    for (final entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  /// Pick the value for an API entity that exposes per-language variants.
  ///
  /// Falls back gracefully when the preferred language value is missing:
  /// preferred -> English -> Myanmar -> Thai -> empty string.
  String localized({String? en, String? mm, String? th}) {
    String? pick;
    switch (_language) {
      case AppLanguage.en:
        pick = en;
        break;
      case AppLanguage.mm:
        pick = mm;
        break;
      case AppLanguage.th:
        pick = th;
        break;
    }
    final candidates = [pick, en, mm, th];
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return '';
  }

  /// Localize a "time ago" string for [date] relative to now.
  ///
  /// Returns "Just now" / "5m ago" / "3h ago" / "2d ago" in the active
  /// language, falling back to a formatted absolute date (via [olderFormat],
  /// default `MMM d`) once the difference exceeds a week.
  String relativeTime(DateTime date, {String olderFormat = 'MMM d'}) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return tr('common.just_now');
    if (diff.inMinutes < 60) {
      return trArgs('time.minutes_ago', {'count': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return trArgs('time.hours_ago', {'count': '${diff.inHours}'});
    }
    if (diff.inDays < 7) {
      return trArgs('time.days_ago', {'count': '${diff.inDays}'});
    }
    return DateFormat(olderFormat).format(date);
  }

  /// Localize a countdown such as "3 hr 52 min" for [remaining].
  ///
  /// Minutes are rounded up so a countdown never reads "0 min" while time is
  /// still left. Returns an empty string once [remaining] runs out.
  String countdown(Duration remaining) {
    if (remaining <= Duration.zero) return '';
    final totalMinutes = (remaining.inSeconds / 60).ceil();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return trArgs('time.duration_m', {'m': '$minutes'});
    if (minutes == 0) return trArgs('time.duration_h', {'h': '$hours'});
    return trArgs('time.duration_hm', {'h': '$hours', 'm': '$minutes'});
  }

  /// Localize an order status that the backend only sends in English.
  ///
  /// The backend exposes a stable status enum (e.g. `PENDING`, `DELIVERED`)
  /// plus an English-only `statusLabel`. We map the enum to a localized label
  /// here so order status follows the active language. Unknown values fall back
  /// to [fallback] (typically the English `statusLabel`) or the raw value.
  String localizedOrderStatus(String? statusEnum, {String? fallback}) {
    final key = statusEnum?.trim().toUpperCase();
    if (key == null || key.isEmpty) return fallback ?? '';
    const enumKeys = <String, String>{
      'PENDING': 'order.status.pending',
      'AWAITING_APPROVAL': 'order.status.awaiting_approval',
      'PAYMENT_SLIP_REQUESTED': 'order.status.waiting_payment',
      'PAYMENT_UPLOADED': 'order.status.awaiting_approval',
      'PAYMENT_CHECKING': 'order.status.awaiting_approval',
      'PAYMENT_VERIFIED': 'order.status.payment_verified',
      'PAID': 'order.status.payment_verified',
      'CONFIRMED': 'order.status.confirmed',
      'COOKING': 'order.status.cooking',
      'PREPARING': 'order.status.cooking',
      'REVISED': 'order.status.revised',
      'ON_THE_WAY': 'order.status.on_the_way',
      'DELIVERING': 'order.status.on_the_way',
      'SHIPPED': 'order.status.on_the_way',
      'DELIVERED': 'order.status.delivered',
      'COMPLETED': 'order.status.delivered',
      'READY_FOR_PICKUP': 'order.status.ready_for_pickup',
      'PICKED_UP': 'order.status.picked_up',
      'CANCELED': 'order.status.canceled',
      'CANCELLED': 'order.status.canceled',
    };
    final translationKey = enumKeys[key];
    if (translationKey == null) return fallback ?? statusEnum!;
    final translated = tr(translationKey);
    // If the key is missing from the table, `tr` returns the key itself.
    if (translated == translationKey) return fallback ?? statusEnum!;
    return translated;
  }

  /// Localize an open/closed shop status string coming from the data layer.
  ///
  /// Recognized English values map to the active language; anything else is
  /// returned unchanged so unexpected backend values stay visible.
  String localizedStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'open':
      case 'open now':
        return tr('common.open');
      case 'closed':
        return tr('common.closed');
      default:
        return status;
    }
  }

  /// Like [localized] but returns [fallback] when no variant is available.
  ///
  /// Use this for DTO getters so the displayed value re-resolves live on a
  /// language switch (the root [MaterialApp] rebuilds), while still honoring a
  /// pre-resolved/static [fallback] for manually constructed instances.
  String localizedOr(
    String fallback, {
    String? en,
    String? mm,
    String? th,
  }) {
    final value = localized(en: en, mm: mm, th: th);
    return value.isNotEmpty ? value : fallback;
  }
}
