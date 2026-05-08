import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFED3973);
  static const Color secondary = Color(0xFFF96232);
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static LinearGradient primaryGradientDisabled = LinearGradient(
    colors: [
      primary.withValues(alpha: 0.6),
      secondary.withValues(alpha: 0.6),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
