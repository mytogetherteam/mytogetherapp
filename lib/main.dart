import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/auth/auth_service.dart';
import 'core/location/location_service.dart';
import 'features/cart/data/active_order_state.dart';
import 'features/cart/data/cart_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notifications/notification_service.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  
  // Initialize auth session FIRST so NotificationService can register the token
  await AuthService().initialize();
  
  await NotificationService().initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Pre-fetch location once at startup — permission dialog (if needed) shows
  // here, never again mid-navigation. Result is cached in LocationService.
  LocationService().getCurrentPosition();

  // Load active order state if any
  await ActiveOrderState.instance.loadFromPrefs();

  // Sync cart from API on startup
  CartManager.instance.syncWithApi();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const App());
}
