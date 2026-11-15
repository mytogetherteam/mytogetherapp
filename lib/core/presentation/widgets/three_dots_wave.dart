import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

/// An animated wave loading indicator with three jumping/pulsing dots.
/// Used for loading price quotations, delivery fee calculations, and other inline states.
class ThreeDotsWave extends StatefulWidget {
  final double dotSize;
  final double spacing;
  final double maxOffset;
  final Color? color;
  final LinearGradient? gradient;
  final Duration duration;

  const ThreeDotsWave({
    super.key,
    this.dotSize = 6.0,
    this.spacing = 4.0,
    this.maxOffset = 4.5,
    this.color,
    this.gradient,
    this.duration = const Duration(milliseconds: 1100),
  });

  @override
  State<ThreeDotsWave> createState() => _ThreeDotsWaveState();
}

class _ThreeDotsWaveState extends State<ThreeDotsWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _calcDotOffset(double progress, double delay) {
    final shifted = (progress - delay) % 1.0;
    if (shifted >= 0.0 && shifted <= 0.5) {
      final t = shifted / 0.5;
      return math.sin(t * math.pi) * widget.maxOffset;
    }
    return 0.0;
  }

  double _calcDotOpacity(double progress, double delay) {
    final shifted = (progress - delay) % 1.0;
    if (shifted >= 0.0 && shifted <= 0.5) {
      final t = shifted / 0.5;
      return 0.5 + (0.5 * math.sin(t * math.pi));
    }
    return 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? AppColors.primary;
    final totalHeight = widget.dotSize + widget.maxOffset + 2;

    return SizedBox(
      height: totalHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final p = _controller.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (index) {
              final delay = index * 0.16;
              final offsetY = _calcDotOffset(p, delay);
              final opacity = _calcDotOpacity(p, delay);

              Widget dot = Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.gradient == null ? dotColor : null,
                    gradient: widget.gradient,
                    shape: BoxShape.circle,
                  ),
                ),
              );

              return Padding(
                padding: EdgeInsets.only(
                  right: index < 2 ? widget.spacing : 0,
                  bottom: offsetY,
                ),
                child: dot,
              );
            }),
          );
        },
      ),
    );
  }
}

