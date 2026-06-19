Future<bool> isWebNotificationGranted() async => false;

Future<bool> requestWebNotificationPermission() async => false;

Future<void> showWebNotification({
  required String title,
  required String body,
  bool isPayment = false,
}) async {}

Future<void> playWebNotificationSound({bool isPayment = false}) async {}
