import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/auth_service.dart';
import 'features/auth/presentation/screens/login_page.dart';
import 'features/main_navigation/presentation/screens/main_navigation_screen.dart';
import 'core/utils/lifecycle_observer.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    print('Building App widget...');
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
      home: AnimatedBuilder(
        animation: AuthService(),
        builder: (context, _) {
          return AuthService().isLoggedIn ? const MainNavigationScreen() : const LoginPage();
        },
      ),
        routes: {
          '/home': (context) => const MainNavigationScreen(),
          '/login': (context) => const LoginPage(),
        },
      ),
    );
  }
}
