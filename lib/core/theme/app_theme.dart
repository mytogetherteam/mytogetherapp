import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  /// Enables the platform-native "swipe to go back" gesture on every pushed
  /// route:
  ///   • iOS / macOS  → Cupertino left-edge swipe-back transition.
  ///   • Android      → predictive back, which hooks into the OS system
  ///     back-swipe gesture/animation (requires
  ///     `android:enableOnBackInvokedCallback="true"` in the manifest).
  /// Other platforms keep Flutter's default zoom transition.
  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
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
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.light().textTheme,
    ),
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
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    ),
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
