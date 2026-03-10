import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';
import '../auth/auth_service.dart';
import '../../app.dart';
import '../../features/notifications/data/repositories/notification_repository.dart';
import '../../features/notifications/presentation/screens/notifications_page.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
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
    await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        NotificationRepository().incrementCount(); // Real-time increment
        _showLocalNotification(message);
      } else if (message.data.isNotEmpty) {
        // For data-only messages, sync from server truth
        NotificationRepository().getUnreadCount();
        _showLocalNotification(message);
      }
    });

    // Handle background message clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // Check if the app was opened from a terminated state via a notification
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage);
    }

    // Register token if already logged in
    if (AuthService().isLoggedIn) {
      await registerDevice();
    }

    // Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      if (AuthService().isLoggedIn) {
        _sendTokenToServer(newToken);
      }
    });

    _isInitialized = true;
  }

  Future<void> registerDevice() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('FCM: Error getting token: $e');
      }
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
      if (kDebugMode) {
        if (e is DioException) {
          print('FCM: Error registering device: ${e.response?.statusCode} - ${e.response?.data}');
        } else {
          print('FCM: Error registering device: $e');
        }
      }
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
    App.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
  }
}
