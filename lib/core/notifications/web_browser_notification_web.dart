import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class WebBrowserNotification {
  static String get _iconUrl =>
      Uri.base.resolve('icons/Icon-192.png').toString();

  static Future<void> show({
    required String title,
    required String body,
    String? tag,
    bool requireInteraction = false,
  }) async {
    try {
      if (web.Notification.permission != 'granted') {
        final permission =
            (await web.Notification.requestPermission().toDart).toDart;
        if (permission != 'granted') {
          debugPrint('[WebBrowserNotification] permission denied');
          return;
        }
      }

      web.Notification(
        title,
        web.NotificationOptions(
          body: body,
          icon: _iconUrl,
          badge: _iconUrl,
          tag: tag ?? '',
          requireInteraction: requireInteraction,
        ),
      );
      debugPrint('[WebBrowserNotification] shown: $title');
    } catch (e) {
      debugPrint('[WebBrowserNotification] $e');
    }
  }
}
