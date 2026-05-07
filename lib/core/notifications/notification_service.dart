import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';
import '../auth/auth_service.dart';
import '../../app.dart';
import '../../features/notifications/data/repositories/notification_repository.dart';
import '../../features/notifications/presentation/screens/notifications_page.dart';
import '../../features/cart/data/active_order_state.dart';
import '../../features/cart/data/cart_manager.dart';
import '../../features/cart/presentation/screens/order_tracking_page.dart';
import '../../features/cart/presentation/screens/awaiting_payment_page.dart';
import '../../features/cart/presentation/screens/order_status_page.dart';
import '../../features/cart/presentation/screens/order_complete_page.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _fcm;
  FirebaseMessaging get fcm {
    try {
      _fcm ??= FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('Firebase Messaging not available: $e');
    }
    return _fcm!; 
  }
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationClick(null); // Simple navigation for now
      },
    );

    // Create high importance channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request permissions
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (e) {
      debugPrint('FCM permission request failed: $e');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final String? type = message.data['type'] ?? message.data['notificationType'];
      
      // 1. Process Order Data regardless of notification display
      if (type == 'ORDER_STATUS') {
        final String? refId = message.data['referenceId']?.toString();
        if (message.data['order'] != null) {
          try {
            final Map<String, dynamic> rawOrder = json.decode(message.data['order'] as String);
            ActiveOrderState.instance.updateFromSocket({'type': 'ORDER_UPDATE', 'order': rawOrder});
          } catch (_) {}
        } else if (refId != null && ActiveOrderState.instance.orderId == refId) {
          ActiveOrderState.instance.syncActiveOrder();
        }
      }

      // 2. Display Notification
      // Since the backend now sends 'STANDARD' mode with a 'notification' object,
      // Firebase will NOT show a banner automatically in the foreground.
      // We manual handle it here for consistency.
      if (message.notification != null) {
        NotificationRepository().incrementCount();
        _showLocalNotification(message);
      } else if (message.data.isNotEmpty && type != 'SILENT_SYNC') {
        // Fallback for data-only legacy/other pushes
        NotificationRepository().getUnreadCount();
        _showLocalNotification(message);
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

    // Register token if already logged in
    if (AuthService().isLoggedIn) {
      await registerDevice();
    }

    // Listen for token refreshes
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (AuthService().isLoggedIn) {
          _sendTokenToServer(newToken);
        }
      });
    } catch (e) {
      debugPrint('FCM onTokenRefresh failed: $e');
    }

    _isInitialized = true;
  }

  Future<void> registerDevice() async {
    // Run registration in background to avoid blocking main execution
    _registerDeviceInBackground();
  }

  Future<void> _registerDeviceInBackground() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 5));
      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (e) {
      // Ignore token retrieval or registration errors
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      String deviceId = await _getDeviceId();
      
      await ApiClient().dio.post(
        '/api/v1/mobile/notifications/register-device',
        data: {
          'fcmToken': token,
          'deviceId': deviceId,
        },
      );
    } catch (e) {
      // Ignore token registration errors
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final String title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
    final String body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? 'You have a new message';

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item_id',
    );
  }

  Future<String> _getDeviceId() async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios_device';
    }
    return 'unknown_device';
  }

  void _handleNotificationClick(RemoteMessage? message) {
    final String? type = message?.data['type'] ?? message?.data['notificationType'];
    
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
              store: CartStore(name: state.storeName ?? '', items: state.orderItems),
              foodTotal: (state.totalAmount ?? 0).toInt(),
            ),
          ));
        } else if (s == 1) {
          App.navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => AwaitingPaymentPage(
              orderId: state.orderId,
              foodTotal: state.totalAmount ?? 0,
              deliveryFee: state.deliveryFee ?? 0,
            ),
          ));
        } else if (s == 2 || s == 3 || s == -1) {
          App.navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => OrderStatusPage(
              foodTotal: state.totalAmount ?? 0,
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
