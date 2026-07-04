import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';
import 'dart:io';

class SecurityCheck {
  /// Checks for root/jailbreak and instantly kills the app if detected.
  static Future<void> ensureDeviceIsSecure() async {
    // Android emulators are flagged as rooted; allow local debug runs.
    if (kDebugMode) return;

    try {
      final bool jailbroken = await SafeDevice.isJailBroken;
      final bool realDevice = await SafeDevice.isRealDevice;

      if (jailbroken && realDevice) {
        // App is running on a rooted/jailbroken physical device
        // Immediately terminate to prevent unauthorized memory access or token theft.
        exit(0);
      }
    } on PlatformException {
      // Ignore exception to let the app continue if the platform isn't supported (e.g. web/desktop)
    }
  }
}
