import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth/auth_service.dart';
import 'core/location/location_service.dart';
import 'features/cart/data/active_order_state.dart';
import 'features/cart/data/cart_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notifications/notification_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/network/api_client.dart';
import 'app.dart';
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

void main() async {
  GoogleFonts.config.allowRuntimeFetching = true;
  print('[BOOT] --- APP BOOT START ---');
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  print('[BOOT] WidgetsBinding initialized.');

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  print('[BOOT] Splash preserved.');

  try {
    print('[BOOT] Initializing Firebase...');
    await Firebase.initializeApp(
      options: kIsWeb
          ? const FirebaseOptions(
              apiKey: 'AIzaSyBhxWsaCQlGoiUNQF6oZXx7uMltxF6Dg-s',
              appId: '1:972280179999:web:0000000000000000',
              messagingSenderId: '972280179999',
              projectId: 'mytogether-daf3f',
              authDomain: 'mytogether-daf3f.firebaseapp.com',
              storageBucket: 'mytogether-daf3f.firebasestorage.app',
            )
          : null,
    );
    print('[BOOT] Firebase initialized successfully.');
  } catch (e) {
    print('[BOOT] Firebase initialization failed: $e');
  }

  print('[BOOT] Initializing AuthService...');
  await AuthService().initialize();
  print(
    '[BOOT] AuthService initialized. LoggedIn: ${AuthService().isLoggedIn}',
  );

  // Proactive token refresh: if the token is expired/near-expiry, refresh it
  // BEFORE any UI loads. This prevents the QueuedInterceptor from serializing
  // all parallel API requests behind a single blocking refresh call.
  if (AuthService().isLoggedIn && AuthService().isTokenNearlyExpired) {
    print('[BOOT] Token nearly expired, proactively refreshing...');
    try {
      final refreshResult = await AuthService()
          .performRefresh(Dio(BaseOptions(
            baseUrl: ApiClient.baseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          )))
          .timeout(const Duration(seconds: 5));
      print('[BOOT] Token refresh ${refreshResult != null ? 'succeeded' : 'returned null'}.');
    } catch (e) {
      print('[BOOT] Token refresh failed (non-fatal): $e');
    }
  }

  print('[BOOT] Initializing NotificationService (background)...');
  NotificationService().initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  print('[BOOT] NotificationService initialization triggered.');

  print('[BOOT] Starting LocationService pre-fetch...');
  LocationService().getCurrentPosition();
  print('[BOOT] LocationService pre-fetch triggered.');

  print('[BOOT] Loading active order state...');
  await ActiveOrderState.instance.loadFromPrefs();
  print('[BOOT] Active order state loaded.');

  print('[BOOT] Syncing cart...');
  CartManager.instance.syncWithApi();
  print('[BOOT] Cart sync triggered.');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  print('[BOOT] Calling runApp()...');
  runApp(const App());
  print('[BOOT] runApp() called.');

  // Safety net: guarantee splash removal after max 4 seconds.
  // On PWA, the splash is an HTML overlay (<picture id="splash">) that blocks
  // the entire screen. If the normal removal chain (banner fetch → image
  // precache → FlutterNativeSplash.remove()) hangs or takes too long,
  // this ensures the user sees the app within a reasonable time.
  Future.delayed(const Duration(seconds: 4), () {
    FlutterNativeSplash.remove();
    print('[BOOT] Safety-net splash removal triggered.');
  });
}
