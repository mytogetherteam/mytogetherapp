import 'package:flutter/painting.dart';

/// Text styles that use the Poppins font bundled with the app
/// (see `fonts:` in pubspec.yaml / `assets/fonts`).
///
/// This mirrors the `GoogleFonts.poppins(...)` signature but is a plain
/// [TextStyle], so there is no per-call font-name resolution or asset-manifest
/// lookup while widgets rebuild.
class AppFonts {
  AppFonts._();

  static const String poppinsFamily = 'Poppins';

  static TextStyle poppins({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final style = TextStyle(
      fontFamily: poppinsFamily,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
    return textStyle == null ? style : textStyle.merge(style);
  }
}
