import 'package:flutter/material.dart';

class AppTheme {
  /// Enables the platform-native "swipe to go back" gesture on every pushed
  /// route:
  ///   • iOS / macOS  → Cupertino left-edge swipe-back transition.
  ///   • Android      → predictive back, which hooks into the OS system
  ///     back-swipe gesture/animation (requires
  ///     `android:enableOnBackInvokedCallback="true"` in the manifest).
  /// Other platforms keep Flutter's default zoom transition.
  static final PageTransitionsTheme _pageTransitionsTheme =
      const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    },
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: _pageTransitionsTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFED3A72),
      primary: const Color(0xFFED3A72),
      brightness: Brightness.light,
    ),
    // Poppins is bundled in assets/fonts and declared in pubspec.yaml.
    fontFamily: 'Poppins',
    textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Poppins'),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Color(0xFFED3A72),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: _pageTransitionsTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFED3A72),
      primary: const Color(0xFFED3A72),
      brightness: Brightness.dark,
    ),
    fontFamily: 'Poppins',
    textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Poppins'),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Color(0xFFED3A72),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
