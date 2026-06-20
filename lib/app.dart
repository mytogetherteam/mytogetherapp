import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/auth_service.dart';
import 'core/localization/locale_controller.dart';
import 'features/auth/presentation/screens/login_page.dart';
import 'features/auth/presentation/screens/auth_entry_page.dart';
import 'features/main_navigation/presentation/screens/main_navigation_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'core/utils/lifecycle_observer.dart';
import 'package:upgrader/upgrader.dart';

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
    // Register callback so any clearSession() call navigates to login
    AuthService().onSessionExpired = () {
      final nav = App.navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
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
                child: child ?? const SizedBox.shrink(),
              );
            },
            navigatorObservers: [App.routeObserver],
            navigatorKey: App.navigatorKey,
            scaffoldMessengerKey: App.scaffoldMessengerKey,
            // Auth-aware initial route
            home: UpgradeAlert(
              showIgnore: false,
              showLater: false,
              upgrader: Upgrader(),
              child: !widget.hasSeenOnboarding
                  ? const OnboardingScreen()
                  : AuthService().isLoggedIn
                      ? const MainNavigationScreen()
                      : const LoginPage(),
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
