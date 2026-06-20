import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';
import '../auth/auth_service.dart';
import 'payment_alert_sound.dart';
import 'web_browser_notification.dart';
import 'web_push_helper.dart';
import 'web_sw_message_listener.dart';
import '../../app.dart';
import '../../features/notifications/data/repositories/notification_repository.dart';
import '../../features/notifications/presentation/screens/notifications_page.dart';
import '../../features/announcements/data/models/announcement_model.dart';
import '../../features/announcements/presentation/announcement_presenter.dart';
import '../../features/cart/data/active_order_state.dart';
import '../../features/cart/data/cart_manager.dart';
import '../../features/cart/presentation/screens/order_tracking_page.dart';
import '../../features/cart/presentation/screens/awaiting_payment_page.dart';
import '../../features/cart/presentation/screens/order_status_page.dart';
import '../../features/cart/presentation/screens/order_complete_page.dart';

double _primaryFoodSubtotal(ActiveOrderState state) {
  return state.getOrder(state.orderId)?.resolvedItemSubtotal ?? 0;
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static void stopGlobalAlert() {
    PaymentAlertSound.stopAlert();
  }

  FirebaseMessaging? _fcm;
  FirebaseMessaging get fcm {
    try {
      _fcm ??= FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('Firebase Messaging not available: $e');
    }
    return _fcm!; 
  }
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _registeredFcmToken;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationClick(null); // Simple navigation for now
        },
      );

      // Create high importance channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel_v2',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Payment-request channel — high importance but normal (default) sound,
      // no looping flag so it behaves like every other notification.
      const AndroidNotificationChannel paymentChannel = AndroidNotificationChannel(
        'high_importance_channel_payment',
        'Payment Notifications',
        description: 'This channel is used for payment request notifications.',
        importance: Importance.high,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(paymentChannel);
    }

    if (kIsWeb) {
      PaymentAlertSound.setupBackgroundAlertResume();

      WebServiceWorkerMessageListener.start((data) async {
        final type = data['type']?.toString();
        if (type != 'PAYMENT_ALERT') return;

        final orderId = data['orderId']?.toString();
        final fromClick = data['fromNotificationClick'] == true;
        final title = data['title']?.toString();
        final body = data['body']?.toString();
        if (!fromClick && title != null && body != null) {
          await WebBrowserNotification.show(
            title: title,
            body: body,
            tag: orderId != null ? 'payment-$orderId' : 'payment',
            requireInteraction: true,
          );
        }
        if (!fromClick) {
          await PaymentAlertSound.handleServiceWorkerAlert(orderId: orderId);
        } else {
          NotificationService.stopGlobalAlert();
        }
        if (orderId != null && orderId.isNotEmpty && orderId != 'payment') {
          ActiveOrderState.instance.syncActiveOrder();
        }
      });
    }

    // Permissions are now requested via MainNavigationScreen rationale modal
    try {
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final String? type = message.data['type'] ?? message.data['notificationType'];
      final String? subType = message.data['subType'];
      final bool isPayment =
          type == 'PAYMENT_REMINDER' ||
          subType == 'PAYMENT_SLIP_REQUEST_ORDER';

      // 0. Admin broadcast/announcement: pop the modal globally (any screen)
      // and bump the badge. Handled here so we don't also show a banner.
      if (type == 'BROADCAST') {
        final announcement = _announcementFromMessage(message);
        if (announcement != null) {
          AnnouncementPresenter.present(announcement);
        }
        return;
      }

      // 1. Process Order Data regardless of notification display
      if (type == 'ORDER_STATUS' || isPayment) {
        _processOrderStatusMessage(message);
      }

      if (isPayment) {
        NotificationRepository().incrementCount();
        if (kIsWeb) {
          _handleWebForegroundPaymentAlert(message);
        } else {
          showLocalNotification(message);
        }
        return;
      }

      // 2. Display Notification
      // Since the backend now sends 'STANDARD' mode with a 'notification' object,
      // Firebase will NOT show a banner automatically in the foreground.
      // We manual handle it here for consistency.
      if (message.notification != null) {
        NotificationRepository().incrementCount();
        if (kIsWeb) {
          _showWebNotification(message);
        } else {
          showLocalNotification(message);
        }
      } else if (message.data.isNotEmpty && type != 'SILENT_SYNC') {
        // Fallback for data-only legacy/other pushes
        NotificationRepository().getUnreadCount();
        if (kIsWeb) {
          _showWebNotification(message);
        } else {
          showLocalNotification(message);
        }
      }
    });

    // Handle background message clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // Check if the app was opened from a terminated state via a notification
    // Add a timeout to prevent hanging the initialization if Firebase is unresponsive
    try {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage().timeout(
        const Duration(seconds: 2),
      );
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage);
      }
    } catch (_) {
      // Ignore timeout or initialization errors
    }

    await ensurePushRegistration();

    // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (AuthService().isLoggedIn) {
          _sendTokenToServer(newToken);
        }
      });
    } catch (e) {
      debugPrint('FCM listener setup failed: $e');
    }

    _isInitialized = true;
  }

  /// Ensures the FCM service worker is active and the device token is registered.
  Future<void> ensurePushRegistration() async {
    if (!kIsWeb) {
      if (AuthService().isLoggedIn) {
        await registerDevice();
      }
      return;
    }

    await WebPushHelper.ensureMessagingServiceWorkerReady();

    final settings = await fcm.getNotificationSettings();
    final granted = settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!granted) {
      debugPrint(
        '[NotificationService] Web push permission: ${settings.authorizationStatus}',
      );
      return;
    }

    if (AuthService().isLoggedIn) {
      await registerDevice();
    }
  }

  Future<void> requestPermission() async {
    try {
      if (kIsWeb) {
        await PaymentAlertSound.prepareForUserInteraction();
        await fcm.requestPermission();
        await ensurePushRegistration();
        return;
      }
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      if (AuthService().isLoggedIn) {
        await registerDevice();
      }
    } catch (e) {
      debugPrint('FCM permission request failed: $e');
    }
  }

  Future<void> registerDevice() async {
    _registerDeviceInBackground();
  }

  /// Removes the current FCM token from the backend (call before logout).
  Future<void> unregisterDevice() async {
    try {
      final token = _registeredFcmToken ??
          await FirebaseMessaging.instance
              .getToken()
              .timeout(const Duration(seconds: 5));
      if (token == null || token.isEmpty) return;

      await ApiClient().dio.delete(
        '${ApiClient.apiPrefix}/user/device-tokens',
        data: {'token': token},
      );
      if (_registeredFcmToken == token) {
        _registeredFcmToken = null;
      }
    } catch (e) {
      debugPrint('FCM token unregister failed: $e');
    }
  }

  Future<void> _registerDeviceInBackground() async {
    try {
      if (kIsWeb) {
        await WebPushHelper.ensureMessagingServiceWorkerReady();
      }

      String? token;
      if (kIsWeb) {
        final vapidKey = dotenv.env['FIREBASE_VAPID_KEY'];
        if (vapidKey != null && vapidKey.isNotEmpty) {
          token = await FirebaseMessaging.instance
              .getToken(vapidKey: vapidKey)
              .timeout(const Duration(seconds: 10));
        }
      } else {
        token = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 5));
      }
      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (_) {
      // Ignore token retrieval or registration errors
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/user/device-tokens',
        data: {
          'token': token,
          'platform': _devicePlatform,
        },
      );
      _registeredFcmToken = token;
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  String get _devicePlatform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'web';
    }
  }

  Future<void> showLocalNotification(RemoteMessage message) async {
    final String title =
        message.notification?.title ??
        message.data['title'] ??
        'New Notification';
    final String body =
        message.notification?.body ??
        message.data['body'] ??
        message.data['message'] ??
        'You have a new message';

    final String? type = message.data['type'];
    final String? subType = message.data['subType'];
    final bool isPayment =
        type == 'PAYMENT_REMINDER' ||
        subType == 'PAYMENT_SLIP_REQUEST_ORDER';

    if (kIsWeb) {
      if (isPayment) {
        await _handleWebForegroundPaymentAlert(message);
      } else {
        await _showWebNotification(message);
      }
      return;
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      isPayment ? 'high_importance_channel_payment' : 'high_importance_channel_v2',
      isPayment ? 'Payment Notifications' : 'High Importance Notifications',
      channelDescription: isPayment
          ? 'This channel is used for payment request notifications.'
          : 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
      showWhen: true,
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _localNotifications.show(
      id: (DateTime.now().millisecondsSinceEpoch % 100000), // Safe 32-bit int
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: 'item_id',
    );
  }

  /// Builds an [AnnouncementModel] from a BROADCAST push. FCM data values are
  /// strings; title/body live on the notification payload. `createdAt` isn't in
  /// the push, so we fall back to now (the list still shows the server value).
  AnnouncementModel? _announcementFromMessage(RemoteMessage message) {
    final id = int.tryParse(message.data['broadcastId']?.toString() ?? '');
    if (id == null) return null;
    final String title =
        message.notification?.title ?? message.data['title']?.toString() ?? '';
    final String body = message.notification?.body ??
        message.data['message']?.toString() ??
        message.data['body']?.toString() ??
        '';
    final String? imageUrl = message.data['imageUrl']?.toString();
    return AnnouncementModel(
      id: id,
      title: title,
      message: body,
      imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
      audience: message.data['audience']?.toString(),
      createdAt: DateTime.now(),
      isRead: false,
    );
  }

  /// Plays the payment alert sound on PWA when push permission is unavailable
  /// but the app is in the foreground (e.g. WebSocket order updates).
  Future<void> playPaymentAlert({String? orderId}) async {
    if (!kIsWeb) return;
    await PaymentAlertSound.playLoopingAlert(orderId: orderId);
  }

  void _processOrderStatusMessage(RemoteMessage message) {
    final String? refId = message.data['referenceId']?.toString();
    if (message.data['order'] != null) {
      try {
        final Map<String, dynamic> rawOrder =
            json.decode(message.data['order'] as String);
        ActiveOrderState.instance
            .updateFromSocket({'type': 'ORDER_UPDATE', 'order': rawOrder});
      } catch (_) {}
    } else if (refId != null) {
      if (ActiveOrderState.instance.orderId == refId ||
          ActiveOrderState.instance.allOrdersList
              .any((order) => order.orderId == refId)) {
        ActiveOrderState.instance.syncActiveOrder();
      }
    }
  }

  Future<void> _handleWebForegroundPaymentAlert(RemoteMessage message) async {
    final orderId = message.data['referenceId']?.toString() ??
        message.data['orderId']?.toString();
    final title =
        message.notification?.title ?? message.data['title'] ?? 'Payment Required';
    final body = message.notification?.body ??
        message.data['body'] ??
        message.data['message'] ??
        'Please upload your payment slip.';

    await WebBrowserNotification.show(
      title: title,
      body: body,
      tag: orderId != null ? 'payment-$orderId' : 'payment',
      requireInteraction: true,
    );
    await PaymentAlertSound.playLoopingAlert(orderId: orderId);
  }

  Future<void> _showWebNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title'] ?? 'New Notification';
    final body = message.notification?.body ??
        message.data['body'] ??
        message.data['message'] ??
        'You have a new message';

    await WebBrowserNotification.show(
      title: title,
      body: body,
      tag: message.messageId,
    );
  }

  void _handleNotificationClick(RemoteMessage? message) {
    final String? type = message?.data['type'] ?? message?.data['notificationType'];

    // Tapping a broadcast push (from background/terminated) opens the modal.
    if (message != null && type == 'BROADCAST') {
      final announcement = _announcementFromMessage(message);
      if (announcement != null) {
        // Not a fresh foreground arrival — reconcile count, don't double-bump.
        AnnouncementPresenter.present(announcement, isNewArrival: false);
      }
      return;
    }

    if (message != null && type == 'ORDER_STATUS') {
      try {
        final String? refId = message.data['referenceId']?.toString();
        
        if (message.data['order'] != null) {
          final Map<String, dynamic> rawOrder = json.decode(message.data['order'] as String);
          ActiveOrderState.instance.updateFromSocket({'type': 'ORDER_UPDATE', 'order': rawOrder});
        } else if (refId != null) {
          // Store reference if we're not already tracking it
          if (ActiveOrderState.instance.orderId != refId) {
            ActiveOrderState.instance.orderId = refId;
            ActiveOrderState.instance.hasActiveOrder = true;
          }
          // Trigger sync to get full order details for the UI
          ActiveOrderState.instance.syncActiveOrder();
        }
        
        final context = App.navigatorKey.currentState?.context;
        if (context == null) return;
        final state = ActiveOrderState.instance;
        final s = state.orderStatus;

        if (s == 0) {
          App.navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => OrderTrackingPage(
              store: CartStore(
                nameKey: state.shopNameEn ?? state.storeName ?? '',
                nameEn: state.shopNameEn ?? state.storeName,
                nameMm: state.shopNameMm,
                nameTh: state.shopNameTh,
                items: state.orderItems,
              ),
              foodTotal: (_primaryFoodSubtotal(state)).round(),
            ),
          ));
        } else if (s == 1) {
          App.navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => AwaitingPaymentPage(
              orderId: state.orderId,
              foodTotal: _primaryFoodSubtotal(state),
              deliveryFee: state.deliveryFee ?? 0,
            ),
          ));
        } else if (s == 2 || s == 3 || s == -1) {
          App.navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => OrderStatusPage(
              foodTotal: _primaryFoodSubtotal(state),
              deliveryFee: state.deliveryFee ?? 0,
            ),
          ));
        } else if (s == 4) {
          OrderCompletePage.navigateWithState(App.navigatorKey.currentState);
        }
        return; // Handled order routing
      } catch (e) {
          // Ignore FCM routing errors
        }
    }

    App.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
  }
}
