import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'dart:io';

class SecurityCheck {
  /// Checks for root/jailbreak and instantly kills the app if detected.
  static Future<void> ensureDeviceIsSecure() async {
    // Android emulators are flagged as rooted; allow local debug runs.
    if (kDebugMode) return;

    try {
      final bool jailbroken = await FlutterJailbreakDetection.jailbroken;
      // Kept for the optional production developer-mode block below.
      // ignore: unused_local_variable
      final bool developerMode = await FlutterJailbreakDetection.developerMode;

      if (jailbroken) {
        // App is running on a rooted/jailbroken device
        // Immediately terminate to prevent unauthorized memory access or token theft.
        exit(0);
      }
      
      // We can optionally block developer mode on production builds
      // if (developerMode && const bool.fromEnvironment('dart.vm.product')) {
      //   exit(0);
      // }
    } on PlatformException {
      // Ignore exception to let the app continue if the platform isn't supported (e.g. web/desktop)
    }
  }
}
