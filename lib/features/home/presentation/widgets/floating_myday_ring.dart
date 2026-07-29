import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class FloatingMyDayRing extends StatefulWidget {
  final Widget child;
  final double size;

  const FloatingMyDayRing({
    super.key,
    required this.child,
    this.size = 70,
  });

  @override
  State<FloatingMyDayRing> createState() => _FloatingMyDayRingState();
}

class _FloatingMyDayRingState extends State<FloatingMyDayRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final floatOffset = math.sin(_controller.value * 2 * math.pi) * 3;
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Container(
            width: widget.size,
            height: widget.size,
            padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            gradient: SweepGradient(
              colors: const [
                Color(0xFFF58529),
                Color(0xFFDD2A7B),
                Color(0xFF8134AF),
                Color(0xFF515BD4),
                Color(0xFFF58529),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: widget.child,
          ),
          ),
        );
      },
    );
  }
}
