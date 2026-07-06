import 'package:flutter/foundation.dart';
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
import 'core/security/security_check.dart';
import 'app.dart';
import 'dart:convert';
import 'core/auth/order_ownership.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  try {
    final data = message.data;
    final mainType = data['mainType']?.toString().toUpperCase();
    final type = data['type'] ??
        data['notificationType'] ??
        (mainType == 'ORDER' ? 'ORDER_STATUS' : null);
    final isOrder = type == 'ORDER_STATUS' || mainType == 'ORDER';

    if (isOrder && data['order'] != null) {
      final Map<String, dynamic> rawOrder =
          json.decode(data['order'] as String);
      if (!OrderOwnership.isForeignOrder(rawOrder)) {
        await ActiveOrderState.instance.loadFromPrefs();
        ActiveOrderState.instance.updateFromSocket({
          'type': 'ORDER_UPDATE',
          'order': rawOrder,
        });

        await LockScreenWidgetManager.instance.initialize();
        final order = ActiveOrderState.instance.activeOrdersList.isNotEmpty
            ? ActiveOrderState.instance.activeOrdersList.first
            : null;
        if (order != null) {
          await LockScreenWidgetManager.instance.showOrUpdateWidget(order);
        } else {
          await LockScreenWidgetManager.instance.cancelWidget();
        }
      }
    } else if (isOrder) {
      final refId =
          data['referenceId']?.toString() ?? data['orderId']?.toString();
      if (refId != null) {
        await ActiveOrderState.instance.loadFromPrefs();
        await ActiveOrderState.instance.adoptOrderIfOwned(refId);
      }
    }
  } catch (e) {
    debugPrint('Background live activity update failed: $e');
  }

  await NotificationService().initialize();

  final data = message.data;
  final mainType = data['mainType']?.toString().toUpperCase();
  final String? type = data['type'] ??
      data['notificationType'] ??
      (mainType == 'ORDER' ? 'ORDER_STATUS' : null);
  if (type == 'SILENT_SYNC') {
    await NotificationService().cancelAllNotifications();
    return;
  }
  
  await NotificationService().showLocalNotification(message);
}

void main() async {
  debugPrint('[BOOT] --- APP BOOT START ---');
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[BOOT] WidgetsBinding initialized.');

  // Check for Jailbroken/Rooted devices and kill app if compromised
  await SecurityCheck.ensureDeviceIsSecure();

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
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
          authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
          projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
          storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
          messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
          appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
          measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID'] ?? '',
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
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
    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('[BOOT] NotificationService initialization failed: $e');
    }
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
    debugPrint('[BOOT] NotificationService initialization triggered.');
    
    debugPrint('[BOOT] Initializing LockScreenWidgetManager...');
    try {
      await LockScreenWidgetManager.instance.initialize();
    } catch (e) {
      debugPrint('[BOOT] LockScreenWidgetManager initialization failed: $e');
    }

    debugPrint('[BOOT] LocationService pre-fetch removed for rationale modal.');

    debugPrint('[BOOT] Loading active order state...');
    if (AuthService().isLoggedIn) {
      await ActiveOrderState.instance.loadFromPrefs();
      ActiveOrderState.instance.hydrateActiveOrdersFromApi();
    } else {
      ActiveOrderState.instance.resetForUserSession();
    }
    debugPrint('[BOOT] Active order state loaded.');

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
      statusBarIconBrightness: Brightness.dark, // Android: dark icons
      statusBarBrightness: Brightness.light,    // iOS: dark icons (light background)
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  GoogleFonts.config.allowRuntimeFetching = false;

  // ── Image cache optimisation ─────────────────────────────────────────────
  // Increase the Flutter in-memory image cache from the tiny default (100 images /
  // 100 MB) so scrolling lists don't constantly evict and re-download images.
  PaintingBinding.instance.imageCache.maximumSize = 200;                   // up to 200 decoded images
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 * 1024 * 1024; // 150 MB
  // ─────────────────────────────────────────────────────────────────────────

  debugPrint('[BOOT] Calling runApp()...');
  runApp(App(hasSeenOnboarding: hasSeenOnboarding));
  debugPrint('[BOOT] runApp() called.');
}
