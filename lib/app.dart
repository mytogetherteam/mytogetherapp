import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/auth_service.dart';
import 'core/localization/locale_controller.dart';
import 'features/auth/presentation/screens/login_page.dart';
import 'features/auth/presentation/screens/auth_entry_page.dart';
import 'features/main_navigation/presentation/screens/main_navigation_screen.dart';
import 'core/utils/lifecycle_observer.dart';
import 'package:upgrader/upgrader.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

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
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            navigatorObservers: [App.routeObserver],
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
            // Auth-aware initial route
            home: UpgradeAlert(
              showIgnore: false,
              showLater: false,
              upgrader: Upgrader(),
              child: AuthService().isLoggedIn
                  ? const MainNavigationScreen()
                  : const AuthEntryPage(),
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
