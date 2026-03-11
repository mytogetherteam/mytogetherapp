import 'package:flutter/material.dart';

class CustomLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  const CustomLoadingIndicator({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  State<CustomLoadingIndicator> createState() => _CustomLoadingIndicatorState();
}

class _CustomLoadingIndicatorState extends State<CustomLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // The order: top-right -> bottom-right -> bottom-left -> top-left -> top-right
    // Positions: 
    // TR: (1, 0)
    // BR: (1, 1)
    // BL: (0, 1)
    // TL: (0, 0)
    _animation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(1, 0), end: const Offset(1, 1))
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(1, 1), end: const Offset(0, 1))
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(0, 1), end: const Offset(0, 0))
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(0, 0), end: const Offset(1, 0))
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.color ?? const Color(0xFFED3A72);
    final dotSize = widget.size / 2.2;
    final spacing = widget.size * 0.1;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Background Dots
          _buildDot(0, 0, primaryColor.withValues(alpha: 0.1), dotSize), // TL
          _buildDot(1, 0, primaryColor.withValues(alpha: 0.1), dotSize), // TR
          _buildDot(0, 1, primaryColor.withValues(alpha: 0.1), dotSize), // BL
          _buildDot(1, 1, primaryColor.withValues(alpha: 0.1), dotSize), // BR

          // Active Dot
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Positioned(
                left: _animation.value.dx * (dotSize + spacing),
                top: _animation.value.dy * (dotSize + spacing),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(dotSize * 0.3),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDot(double xIndex, double yIndex, Color color, double size) {
    final spacing = widget.size * 0.1;
    return Positioned(
      left: xIndex * (size + spacing),
      top: yIndex * (size + spacing),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
      ),
    );
  }
}
