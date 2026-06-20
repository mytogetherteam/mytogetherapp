import 'payment_alert_sound.dart';
import 'web_browser_notification.dart';
import 'web_push_helper.dart';

Future<bool> isWebNotificationGranted() async {
  return WebPushHelper.isPermissionGranted();
}

Future<bool> requestWebNotificationPermission() async {
  await PaymentAlertSound.prepareForUserInteraction();
  return WebPushHelper.isPermissionGranted();
}

Future<void> showWebNotification({
  required String title,
  required String body,
  bool isPayment = false,
}) async {
  await WebBrowserNotification.show(
    title: title,
    body: body,
    tag: isPayment ? 'payment' : null,
    requireInteraction: isPayment,
  );

  if (isPayment) {
    await playWebNotificationSound(isPayment: true);
  }
}

Future<void> playWebNotificationSound({bool isPayment = false}) async {
  if (!isPayment) return;
  await PaymentAlertSound.playLoopingAlert();
}
