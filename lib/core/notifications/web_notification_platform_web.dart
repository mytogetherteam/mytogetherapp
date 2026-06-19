// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool get _supported => html.Notification.supported == true;

Future<bool> isWebNotificationGranted() async {
  if (!_supported) return false;
  return html.Notification.permission == 'granted';
}

Future<bool> requestWebNotificationPermission() async {
  if (!_supported) return false;
  final result = await html.Notification.requestPermission();
  return result == 'granted';
}

Future<void> showWebNotification({
  required String title,
  required String body,
  bool isPayment = false,
}) async {
  if (_supported && html.Notification.permission == 'granted') {
    html.Notification(
      title,
      body: body,
      icon: '/icons/Icon-192.png',
    );
  }

  if (isPayment) {
    await playWebNotificationSound(isPayment: true);
  }
}

Future<void> playWebNotificationSound({bool isPayment = false}) async {
  if (!isPayment) return;
  try {
    final audio = html.AudioElement('/sounds/warning.mp3');
    await audio.play();
  } catch (_) {}
}
