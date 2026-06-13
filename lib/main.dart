import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth/auth_service.dart';
import 'core/localization/locale_controller.dart';
import 'core/location/location_service.dart';
import 'features/cart/data/active_order_state.dart';
import 'features/cart/data/cart_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notifications/notification_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  debugPrint('[BOOT] --- APP BOOT START ---');
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[BOOT] WidgetsBinding initialized.');

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  debugPrint('[BOOT] Splash preserved.');

  try {
    debugPrint('[BOOT] Loading .env...');
    await dotenv.load(fileName: ".env");
    debugPrint('[BOOT] .env loaded successfully.');
  } catch (e) {
    debugPrint('[BOOT] Failed to load .env: $e');
  }

  try {
    debugPrint('[BOOT] Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('[BOOT] Firebase initialized successfully.');
  } catch (e) {
    debugPrint('[BOOT] Firebase initialization failed: $e');
  }

  try {
    debugPrint('[BOOT] Initializing LocaleController...');
    await LocaleController.instance.initialize();
    debugPrint('[BOOT] LocaleController initialized. Language: ${LocaleController.instance.language.code}');

    debugPrint('[BOOT] Initializing AuthService...');
    await AuthService().initialize();
    debugPrint('[BOOT] AuthService initialized. LoggedIn: ${AuthService().isLoggedIn}');

    debugPrint('[BOOT] Initializing NotificationService (background)...');
    NotificationService().initialize();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('[BOOT] NotificationService initialization triggered.');

    debugPrint('[BOOT] Starting LocationService pre-fetch...');
    LocationService().getCurrentPosition();
    debugPrint('[BOOT] LocationService pre-fetch triggered.');

    debugPrint('[BOOT] Loading active order state...');
    await ActiveOrderState.instance.loadFromPrefs();
    debugPrint('[BOOT] Active order state loaded.');

    // Seed active orders from the backend so ongoing orders survive cold
    // starts / cleared prefs (WebSocket alone can't hydrate unknown orders).
    if (AuthService().isLoggedIn) {
      ActiveOrderState.instance.hydrateActiveOrdersFromApi();
    }

    debugPrint('[BOOT] Syncing cart...');
    CartManager.instance.syncWithApi();
    debugPrint('[BOOT] Cart sync triggered.');
  } catch (e, stackTrace) {
    debugPrint('[BOOT] Critical error during initialization: $e\n$stackTrace');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  GoogleFonts.config.allowRuntimeFetching = false;

  debugPrint('[BOOT] Calling runApp()...');
  runApp(const App());
  debugPrint('[BOOT] runApp() called.');
}
