import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/auth_service.dart';
import 'core/localization/locale_controller.dart';
import 'core/splash/branded_splash.dart';
import 'features/auth/presentation/screens/login_page.dart';
import 'features/auth/presentation/screens/auth_entry_page.dart';
import 'features/main_navigation/presentation/screens/main_navigation_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'core/utils/lifecycle_observer.dart';
import 'package:upgrader/upgrader.dart';
import 'package:mytogetherapp/features/chat/presentation/widgets/floating_chat_head.dart';
import 'package:mytogetherapp/features/call/presentation/widgets/floating_call_banner.dart';

class App extends StatefulWidget {
  final bool hasSeenOnboarding;

  const App({super.key, required this.hasSeenOnboarding});

  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    // After session loss, return to the app as a guest (not the login wall).
    AuthService().onSessionExpired = () {
      final nav = App.navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    };
  }

  @override
  void dispose() {
    AuthService().onSessionExpired = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building App widget...');
    // Rebuild the whole app whenever the selected language changes so that
    // every `context.tr(...)` and localized field re-renders.
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return LifecycleObserver(
          child: MaterialApp(
            title: 'Mytogether',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  alwaysUse24HourFormat: true,
                ),
                child: Stack(
                  textDirection: TextDirection.ltr,
                  children: [
                    child ?? const SizedBox.shrink(),
                    const FloatingCallBanner(),
                    ValueListenableBuilder<bool>(
                      valueListenable: FloatingChatHead.isHiddenNotifier,
                      builder: (context, isHidden, child) {
                        print('ValueListenableBuilder in app.dart: isHidden = $isHidden');
                        return IgnorePointer(
                          ignoring: isHidden,
                          child: AnimatedOpacity(
                            opacity: isHidden ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: child,
                          ),
                        );
                      },
                      child: const FloatingChatHead(),
                    ),
                  ],
                ),
              );
            },
            navigatorObservers: [App.routeObserver],
            navigatorKey: App.navigatorKey,
            scaffoldMessengerKey: App.scaffoldMessengerKey,
            // Auth-aware initial route
            home: BrandedSplashGate(
              child: UpgradeAlert(
                showIgnore: false,
                showLater: false,
                upgrader: Upgrader(),
                child: !widget.hasSeenOnboarding
                    ? const OnboardingScreen()
                    : const MainNavigationScreen(),
              ),
            ),
            routes: {
              '/home': (context) => const MainNavigationScreen(),
              '/login': (context) => const LoginPage(),
              '/auth_entry': (context) => const AuthEntryPage(),
            },
          ),
        );
      },
    );
  }
}
