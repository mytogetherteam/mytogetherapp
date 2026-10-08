import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth/auth_service.dart';
import 'core/network/api_client.dart';
import 'core/localization/locale_controller.dart';
import 'core/splash/branded_splash.dart';
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
import 'features/social/post_link_listener.dart';
import 'dart:async';
import 'dart:convert';
import 'core/auth/order_ownership.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

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
  } else if (type == 'CALL_INCOMING') {
    final callId = data['callId']?.toString() ?? '';
    final callerName = data['callerName']?.toString() ?? 'Shop';
    
    if (callId.isNotEmpty) {
      final callKitParams = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: 'MyTogether',
        avatar: '',
        handle: 'Incoming Call',
        type: 0,
        duration: 60000,
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: false,
          subtitle: 'Missed call from shop',
          callbackText: 'Call back',
        ),
        extra: <String, dynamic>{},
        headers: <String, dynamic>{},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#EF4444',
          actionColor: '#22C55E',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: "Incoming Call",
          missedCallNotificationChannelName: "Missed Call",
        ),
        ios: const IOSParams(
          iconName: 'AppIcon',
          handleType: '',
          supportsVideo: false,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: true,
          supportsHolding: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );
      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
    }
    return;
  } else if (type == 'CALL_END' || type == 'CALL_TIMEOUT') {
    final callId = data['callId']?.toString() ?? '';
    if (callId.isNotEmpty) {
      await FlutterCallkitIncoming.endCall(callId);
    } else {
      await FlutterCallkitIncoming.endAllCalls();
    }
    return;
  }
  
  await NotificationService().showLocalNotification(message);
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Check for Jailbroken/Rooted devices and kill app if compromised
  await SecurityCheck.ensureDeviceIsSecure();

  bool hasSeenOnboarding = false;

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
  }

  try {
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
  } catch (e) {
  }

  try {
    await LocaleController.instance.initialize();
    await AuthService().initialize();

    // ── Next-day startup refresh ──────────────────────────────────────────
    // If the stored access token is already expired at launch, refresh it NOW
    // before any widget makes an API call.  This prevents dozens of concurrent
    // refresh requests racing each other (which would invalidate a
    // single-use refresh token on the backend).
    if (AuthService().isLoggedIn && AuthService().isTokenNearlyExpired) {
      try {
        final newToken = await AuthService().performRefresh(
          ApiClient().dio,
        );
        if (newToken != null) {
        } else {
          await AuthService().clearSession(navigate: false);
        }
      } catch (e) {
        // Keep session; interceptor will retry on the first real API call.
      }
    }
    // ─────────────────────────────────────────────────────────────────────
    try {
      await NotificationService().initialize();
    } catch (e) {
    }
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
    try {
      await LockScreenWidgetManager.instance.initialize();
    } catch (e) {
    }
    if (AuthService().isLoggedIn) {
      await ActiveOrderState.instance.loadFromPrefs();
      await ActiveOrderState.instance.hydrateActiveOrdersFromApi();
    } else {
      ActiveOrderState.instance.resetForUserSession();
    }
    CartManager.instance.syncWithApi();
    hasSeenOnboarding = await OnboardingPrefs.hasSeenOnboarding();
    try {
      await BrandedSplash.prefetch().timeout(const Duration(seconds: 6));
    } catch (e) {
    }
  } catch (e, stackTrace) {
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
  runApp(App(hasSeenOnboarding: hasSeenOnboarding));
  if (!kIsWeb) {
    unawaited(PostLinkListener.instance.start());
  }
}


