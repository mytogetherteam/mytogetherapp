import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth/auth_service.dart';
import 'core/network/api_client.dart';
import 'core/localization/locale_controller.dart';
import 'features/cart/data/active_order_state.dart';
import 'features/cart/data/cart_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notifications/notification_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/onboarding/data/onboarding_prefs.dart';
import 'core/utils/lock_screen_widget_manager.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService().initialize();
  await NotificationService().showLocalNotification(message);
}

void main() async {
  debugPrint('[BOOT] --- APP BOOT START ---');
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[BOOT] WidgetsBinding initialized.');

  bool hasSeenOnboarding = false;

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

    // ── Next-day startup refresh ──────────────────────────────────────────
    // If the stored access token is already expired at launch, refresh it NOW
    // before any widget makes an API call.  This prevents dozens of concurrent
    // refresh requests racing each other (which would invalidate a
    // single-use refresh token on the backend).
    if (AuthService().isLoggedIn && AuthService().isTokenNearlyExpired) {
      debugPrint('[BOOT] Access token expired — refreshing before runApp()...');
      try {
        final newToken = await AuthService().performRefresh(
          ApiClient().dio,
        );
        if (newToken != null) {
          debugPrint('[BOOT] Token refreshed successfully.');
        } else {
          debugPrint('[BOOT] Refresh returned null — user will be asked to log in.');
          await AuthService().clearSession(navigate: false);
        }
      } catch (e) {
        debugPrint('[BOOT] Startup refresh failed: $e — continuing without valid token.');
        // Keep session; interceptor will retry on the first real API call.
      }
    }
    // ─────────────────────────────────────────────────────────────────────

    debugPrint('[BOOT] Initializing NotificationService (background)...');
    NotificationService().initialize();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('[BOOT] NotificationService initialization triggered.');
    
    debugPrint('[BOOT] Initializing LockScreenWidgetManager...');
    LockScreenWidgetManager.instance.initialize();

    debugPrint('[BOOT] LocationService pre-fetch removed for rationale modal.');

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

    debugPrint('[BOOT] Checking onboarding status...');
    hasSeenOnboarding = await OnboardingPrefs.hasSeenOnboarding();
    debugPrint('[BOOT] Onboarding status loaded: $hasSeenOnboarding');
  } catch (e, stackTrace) {
    debugPrint('[BOOT] Critical error during initialization: $e\n$stackTrace');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  GoogleFonts.config.allowRuntimeFetching = false;

  debugPrint('[BOOT] Calling runApp()...');
  runApp(App(hasSeenOnboarding: hasSeenOnboarding));
  debugPrint('[BOOT] runApp() called.');
}
