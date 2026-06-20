import 'dart:async';

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class WebPushHelper {
  static const _serviceWorkerFile = 'firebase-messaging-sw.js';
  static const _serviceWorkerScope = '/firebase-cloud-messaging-push-scope';
  static const _readyTimeout = Duration(seconds: 3);

  static Future<void> registerMessagingServiceWorker() async {
    final swContainer = web.window.navigator.serviceWorker;

    final swUrl = Uri.base.resolve(_serviceWorkerFile).toString();
    final options = web.RegistrationOptions(scope: _serviceWorkerScope);

    try {
      await swContainer.register(swUrl.toJS, options).toDart;
      debugPrint('[WebPushHelper] Registered $swUrl (scope: $_serviceWorkerScope)');
    } catch (e) {
      debugPrint('[WebPushHelper] SW registration failed: $e');
    }
  }

  /// Waits until the Firebase messaging service worker is active before FCM
  /// token registration. Never blocks indefinitely — times out after 3 seconds.
  static Future<void> ensureMessagingServiceWorkerReady() async {
    await registerMessagingServiceWorker();
    try {
      await web.window.navigator.serviceWorker.ready.toDart.timeout(_readyTimeout);
      debugPrint('[WebPushHelper] Messaging service worker ready');
    } on TimeoutException {
      debugPrint('[WebPushHelper] SW ready timed out after ${_readyTimeout.inSeconds}s');
    } catch (e) {
      debugPrint('[WebPushHelper] SW ready wait failed: $e');
    }
  }

  static Future<bool> isPermissionGranted() async {
    return web.Notification.permission == 'granted';
  }
}
