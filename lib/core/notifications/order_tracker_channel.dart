import 'dart:io';
import 'package:flutter/services.dart';

class OrderTrackerChannel {
  static const MethodChannel _channel =
      MethodChannel('com.mytogether/order_tracker');

  static Future<void> startOrUpdateTracker({
    required String shopName,
    String? shopLogoUrl,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startTracker', {
        'shopName': shopName,
        'shopLogoUrl': shopLogoUrl ?? '',
      });
    } on PlatformException catch (e) {
      print("Failed to start/update tracker: '${e.message}'.");
    }
  }

  static Future<void> stopTracker() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopTracker');
    } on PlatformException catch (e) {
      print("Failed to stop tracker: '${e.message}'.");
    }
  }
}
