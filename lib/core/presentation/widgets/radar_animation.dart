import 'package:flutter/material.dart';
import 'dart:math' as math;

class RadarAnimation extends StatefulWidget {
  final Widget child;
  final Color color;
  final double scale;

  const RadarAnimation({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.scale = 2.5, // Radar area is 2.5x the size of the child
  });

  @override
  State<RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<RadarAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return OverflowBox(
                maxWidth: constraints.maxWidth * widget.scale,
                maxHeight: constraints.maxHeight * widget.scale,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth * widget.scale, constraints.maxHeight * widget.scale),
                      painter: RadarPainter(
                        progress: _controller.value,
                        color: widget.color,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    // Draw ripples
    final paintRipple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 3; i++) {
      double rippleProgress = (progress + (i * 0.333)) % 1.0;
      double radius = maxRadius * rippleProgress;
      double opacity = 1.0 - rippleProgress;

      // Fade out outer edges more smoothly
      double finalOpacity = opacity * 0.6;
      if (rippleProgress < 0.1) {
        // Fade in from center
        finalOpacity *= (rippleProgress / 0.1);
      }

      paintRipple.color = color.withValues(alpha: finalOpacity);
      canvas.drawCircle(center, radius, paintRipple);
    }

    // Removed radar sweep per user request
    
    // Removed border per user request
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
