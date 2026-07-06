import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';
import '../auth/auth_service.dart';
import '../auth/order_ownership.dart';
import '../../app.dart';
import '../../features/notifications/data/repositories/notification_repository.dart';
import '../../features/notifications/presentation/screens/notifications_page.dart';
import '../../features/notifications/presentation/order_notification_navigation.dart';
import '../../features/announcements/data/models/announcement_model.dart';
import '../../features/announcements/presentation/announcement_presenter.dart';
import '../../features/cart/data/active_order_state.dart';
import 'package:mytogetherapp/features/chat/presentation/screens/chat_page.dart';

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
          if (details.payload != null && details.payload != 'item_id') {
            try {
              final Map<String, dynamic> map = json.decode(details.payload!);
              
              final dataMap = <String, String>{};
              if (map['data'] is Map) {
                for (final entry in (map['data'] as Map).entries) {
                  dataMap[entry.key.toString()] = entry.value?.toString() ?? '';
                }
              }

              // Also extract type from payload itself for safety
              final msgType = map['type']?.toString();

              // Mock RemoteMessage
              final message = RemoteMessage(
                data: dataMap,
                messageType: msgType,
                // Passing a RemoteNotification here would require it, 
                // but we only use data in _handleNotificationClick
              );
              _handleNotificationClick(message);
              return;
            } catch (e) {
              debugPrint('Payload decode error: $e');
            }
          }
          _handleNotificationClick(null);
        },
      );

      // Create high importance channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel_v3',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('normal_noti'),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Payment-request channel — high importance but normal (default) sound,
      // no looping flag so it behaves like every other notification.
      const AndroidNotificationChannel paymentChannel = AndroidNotificationChannel(
        'high_importance_channel_payment_v3',
        'Payment Notifications',
        description: 'This channel is used for payment request notifications.',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('normal_noti'),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(paymentChannel);

      const AndroidNotificationChannel orderStatusChannel = AndroidNotificationChannel(
        'order_status_channel_v1',
        'Order Status Updates',
        description: 'This channel is used for order status changes.',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('status_change'),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(orderStatusChannel);

      const AndroidNotificationChannel orderDeliveredChannel = AndroidNotificationChannel(
        'order_delivered_channel_v1',
        'Order Delivered',
        description: 'This channel is used when an order is delivered.',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('order_deliver'),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(orderDeliveredChannel);
    }

    // Permissions are now requested via MainNavigationScreen rationale modal
    try {
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final String? type = _resolveNotificationType(message.data);

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
      if (_isOrderNotification(message.data)) {
        final String? refId = message.data['referenceId'] ??
            message.data['orderId'];
        if (message.data['order'] != null) {
          try {
            final Map<String, dynamic> rawOrder = json.decode(message.data['order'] as String);
            if (!OrderOwnership.isForeignOrder(rawOrder)) {
              ActiveOrderState.instance.updateFromSocket({'type': 'ORDER_UPDATE', 'order': rawOrder});
            }
          } catch (_) {}
        } else if (refId != null) {
          final id = refId.toString();
          if (ActiveOrderState.instance.orderId == id) {
            ActiveOrderState.instance.syncActiveOrder();
          } else {
            unawaited(ActiveOrderState.instance.adoptOrderIfOwned(id));
          }
        }
      }

      // 2. Display Notification
      // Since the backend now sends 'STANDARD' mode with a 'notification' object,
      // Firebase will NOT show a banner automatically in the foreground.
      // We manual handle it here for consistency.
      if (type == 'SILENT_SYNC') {
        cancelAllNotifications();
      } else if (message.notification != null) {
        NotificationRepository().incrementCount();
        showLocalNotification(message);
      } else if (message.data.isNotEmpty) {
        // Fallback for data-only legacy/other pushes
        NotificationRepository().getUnreadCount();
        showLocalNotification(message);
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

    // Check if opened from LOCAL notification (when terminated)
    try {
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp && launchDetails.notificationResponse != null) {
        final payload = launchDetails.notificationResponse!.payload;
        if (payload != null && payload != 'item_id') {
          final Map<String, dynamic> map = json.decode(payload);
          final dataMap = <String, String>{};
          if (map['data'] is Map) {
            for (final entry in (map['data'] as Map).entries) {
              dataMap[entry.key.toString()] = entry.value?.toString() ?? '';
            }
          }
          final msgType = map['type']?.toString();
          final message = RemoteMessage(data: dataMap, messageType: msgType);
          _handleNotificationClick(message);
        }
      }
    } catch (e) {
      debugPrint('Local notif launch details error: $e');
    }

    // Register token if already logged in
    if (AuthService().isLoggedIn) {
      await registerDevice();
    }

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

  Future<void> requestPermission() async {
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
    if (kIsWeb) return;

    final String title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
    final String body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? 'You have a new message';
    
    final String? type = _resolveNotificationType(message.data);
    final String? subType = message.data['subType'];
    final String? mainType = message.data['mainType']?.toUpperCase();
    
    final bool isPayment = type == 'PAYMENT_REMINDER' || subType == 'PAYMENT_SLIP_REQUEST_ORDER';
    final bool isDelivered =
        (type == 'ORDER' || mainType == 'ORDER') && subType == 'DELIVERED_ORDER';
    final bool isOrderChange =
        (type == 'ORDER' || type == 'ORDER_STATUS' || mainType == 'ORDER') &&
        !isDelivered &&
        !isPayment;

    String channelId = 'high_importance_channel_v3';
    String channelName = 'High Importance Notifications';
    String channelDescription = 'This channel is used for important notifications.';

    if (isDelivered) {
      channelId = 'order_delivered_channel_v1';
      channelName = 'Order Delivered';
      channelDescription = 'This channel is used when an order is delivered.';
    } else if (isOrderChange) {
      channelId = 'order_status_channel_v1';
      channelName = 'Order Status Updates';
      channelDescription = 'This channel is used for order status changes.';
    } else if (isPayment) {
      channelId = 'high_importance_channel_payment_v3';
      channelName = 'Payment Notifications';
      channelDescription = 'This channel is used for payment request notifications.';
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
      showWhen: true,
    );
    final DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentSound: true,
      sound: isDelivered ? 'order_deliver.mp3' : (isOrderChange ? 'status_change.mp3' : 'normal_noti.mp3'),
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    await _localNotifications.show(
      id: (DateTime.now().millisecondsSinceEpoch % 100000), // Safe 32-bit int
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: json.encode({
        'data': message.data,
        'type': message.messageType ?? message.data['type'] ?? message.data['notificationType'],
        'title': title,
      }),
    );
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling notifications: $e');
    }
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

  String? _resolveNotificationType(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? data['notificationType']?.toString();
    if (type != null && type.isNotEmpty) return type;

    final mainType = data['mainType']?.toString().toUpperCase();
    if (mainType == 'ORDER') return 'ORDER_STATUS';
    if (mainType == 'CHAT') return 'CHAT';
    if (mainType == 'ESCALATION') return 'SYSTEM';
    return mainType;
  }

  bool _isOrderNotification(Map<String, dynamic> data) {
    final mainType = data['mainType']?.toString().toUpperCase();
    final type = _resolveNotificationType(data);
    return type == 'ORDER_STATUS' || mainType == 'ORDER';
  }

  bool _isChatNotification(Map<String, dynamic> data, String? type) {
    final mainType = data['mainType']?.toString().toUpperCase();
    final subType = data['subType']?.toString().toUpperCase();
    return mainType == 'CHAT' ||
        type == 'CHAT' ||
        type == 'CHAT_MESSAGE' ||
        type == 'MESSAGE' ||
        type == 'NEW_MESSAGE' ||
        (type != null && type.contains('CHAT')) ||
        (subType != null && subType.contains('CHAT')) ||
        subType == 'NEW_MESSAGE' ||
        data.containsKey('conversationId');
  }

  void _handleNotificationClick(RemoteMessage? message) {
    final data = message?.data ?? const <String, dynamic>{};
    final String? type = _resolveNotificationType(data);

    // Tapping a broadcast push (from background/terminated) opens the modal.
    if (message != null && type == 'BROADCAST') {
      final announcement = _announcementFromMessage(message);
      if (announcement != null) {
        _navigateWhenReady((nav) {
          // Not a fresh foreground arrival — reconcile count, don't double-bump.
          AnnouncementPresenter.present(announcement, isNewArrival: false);
        });
      }
      return;
    }

    final bool isChat = _isChatNotification(data, type);

    if (message != null && isChat) {
      try {
        final orderIdStr = message.data['orderId']?.toString() ??
            message.data['referenceId']?.toString();
        final orderId = orderIdStr != null ? int.tryParse(orderIdStr) : null;
        if (orderId != null) {
          final shopName = message.data['senderName'] ??
              message.data['title'] ??
              message.notification?.title ??
              'Restaurant';
          _navigateWhenReady((nav) {
            nav.push(MaterialPageRoute(
              builder: (_) => ChatPage(
                orderId: orderId,
                peerName: shopName,
                peerSubtitle: 'Restaurant',
              ),
            ));
          });
          return;
        }
      } catch (_) {}
    }

    if (message != null && _isOrderNotification(data)) {
      try {
        final String? refId = data['referenceId']?.toString() ??
            data['orderId']?.toString();

        if (data['order'] != null) {
          final Map<String, dynamic> rawOrder =
              json.decode(data['order'] as String);
          if (!OrderOwnership.isForeignOrder(rawOrder)) {
            ActiveOrderState.instance
                .updateFromSocket({'type': 'ORDER_UPDATE', 'order': rawOrder});
          }
        } else if (refId != null) {
          unawaited(ActiveOrderState.instance.adoptOrderIfOwned(refId));
        }

        final orderId = int.tryParse(refId ?? '');
        if (orderId != null) {
          _navigateWhenReady((nav) {
            navigateToOrderFromNotification(nav.context, orderId);
          });
        }
        return;
      } catch (e) {
        // Ignore FCM routing errors
      }
    }

    if (message != null) {
      _navigateWhenReady((nav) {
        nav.push(
          MaterialPageRoute(builder: (context) => const NotificationsPage()),
        );
      });
    }
  }

  void _navigateWhenReady(void Function(NavigatorState nav) action, {int attempts = 0}) {
    if (App.navigatorKey.currentState != null && App.navigatorKey.currentState!.mounted) {
      // Delay slightly to ensure MaterialApp has finished setting up its home route
      Future.delayed(const Duration(milliseconds: 400), () {
        if (App.navigatorKey.currentState != null) {
          action(App.navigatorKey.currentState!);
        }
      });
    } else if (attempts < 60) { // Increased to 30 seconds (60 * 500ms)
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateWhenReady(action, attempts: attempts + 1);
      });
    }
  }
}
