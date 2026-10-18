import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The mute choice stays on for the next video, and the next time the app opens.
class SocialPlayback {
  static final muted = ValueNotifier<bool>(false);
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      muted.value = prefs.getBool('social_video_muted') ?? false;
    } catch (_) {}
  }

  static Future<void> setMuted(bool value) async {
    muted.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('social_video_muted', value);
    } catch (_) {}
  }
}
