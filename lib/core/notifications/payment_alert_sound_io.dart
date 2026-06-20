import 'package:flutter/foundation.dart';

/// Native platforms use local notification channels for payment alerts.
class PaymentAlertSound {
  PaymentAlertSound._();

  static bool get isPlaying => false;

  static Future<void> prepareForUserInteraction() async {}

  static void setupBackgroundAlertResume() {}

  static Future<void> handleServiceWorkerAlert({String? orderId}) async {}

  static Future<void> playLoopingAlert({String? orderId}) async {
    debugPrint('[PaymentAlertSound] playLoopingAlert is web-only');
  }

  static Future<void> stopAlert() async {}
}
