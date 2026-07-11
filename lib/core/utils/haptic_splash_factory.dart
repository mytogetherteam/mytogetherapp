import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A global [InteractiveInkFeatureFactory] that fires iOS-quality haptic
/// feedback on every tap, then delegates the visual splash to Flutter's
/// default [InkSparkle] / [InkSplash] factory.
///
/// Apply once in [AppTheme] via `ThemeData(splashFactory: HapticSplashFactory.instance)`.
/// Every [InkWell], [ElevatedButton], [TextButton], [OutlinedButton],
/// [IconButton], [ListTile], [BottomNavigationBar] item, etc. will
/// automatically receive the haptic — no per-widget changes needed.
class HapticSplashFactory extends InteractiveInkFeatureFactory {
  const HapticSplashFactory._();

  /// Singleton instance — pass to [ThemeData.splashFactory].
  static const HapticSplashFactory instance = HapticSplashFactory._();

  /// The underlying visual splash factory we delegate to.
  static final InteractiveInkFeatureFactory _delegate =
      defaultTargetPlatform == TargetPlatform.iOS
          ? InkSplash.splashFactory   // Crisp on iOS
          : InkSparkle.splashFactory; // Sparkle on Android

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    // Fire haptic only on iOS — feels like 3D Touch / Taptic Engine "click"
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.mediumImpact();
    }

    return _delegate.create(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}

/// Convenience helpers for manual haptic in [GestureDetector]-based
/// widgets that don't use [InkWell] under the hood.
///
/// Usage:
/// ```dart
/// GestureDetector(
///   onTap: () {
///     AppHaptics.buttonTap();
///     // ... your logic
///   },
/// )
/// ```
class AppHaptics {
  const AppHaptics._();

  /// Standard button tap — equivalent to iOS UIImpactFeedbackGenerator(.medium)
  static void buttonTap() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Lighter tap — for small chips, tags, secondary actions
  static void lightTap() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.lightImpact();
    }
  }

  /// Heavy press — for destructive/confirm dialogs, long-press actions
  static void heavyPress() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Selection change — for toggles, sliders, pickers
  static void selection() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.selectionClick();
    }
  }

  /// Success notification — e.g. order placed, payment done
  static void success() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.mediumImpact();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HapticHorizontalScrollListener
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps any widget tree and fires a [selectionClick] haptic every time
/// a **horizontal** scroll crosses a pixel threshold (~one card width).
///
/// Works with all horizontal [ListView], [PageView], [SingleChildScrollView],
/// and [CustomScrollView] descendants — no per-widget changes needed.
///
/// Usage:
/// ```dart
/// HapticHorizontalScrollListener(
///   child: RefreshIndicator(...)
/// )
/// ```
class HapticHorizontalScrollListener extends StatefulWidget {
  final Widget child;

  /// Pixel distance between haptic ticks.  60px ≈ one finger-swipe "notch".
  final double threshold;

  const HapticHorizontalScrollListener({
    super.key,
    required this.child,
    this.threshold = 60.0,
  });

  @override
  State<HapticHorizontalScrollListener> createState() =>
      _HapticHorizontalScrollListenerState();
}

class _HapticHorizontalScrollListenerState
    extends State<HapticHorizontalScrollListener> {
  // Track last pixel position per scroll view key to avoid cross-widget bleed.
  final Map<int, double> _lastHapticPixel = {};

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        // Only care about horizontal scrollables
        if (notification.metrics.axis != Axis.horizontal) return false;

        final key = notification.metrics.hashCode;
        final current = notification.metrics.pixels;
        final last = _lastHapticPixel[key] ?? current;

        if ((current - last).abs() >= widget.threshold) {
          _lastHapticPixel[key] = current;
          AppHaptics.selection();
        }
        return false; // Let the notification continue bubbling
      },
      child: widget.child,
    );
  }
}
