import 'package:flutter/material.dart';

class AnimatedDotsText extends StatefulWidget {
  final String baseText;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  const AnimatedDotsText({
    super.key,
    required this.baseText,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  State<AnimatedDotsText> createState() => _AnimatedDotsTextState();
}

class _AnimatedDotsTextState extends State<AnimatedDotsText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
        int dotCount = (_controller.value * 4).floor();
        String dots = '.' * dotCount;
        return RichText(
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          text: TextSpan(
            text: widget.baseText,
            style: widget.style,
            children: [
              TextSpan(
                text: dots,
              ),
              TextSpan(
                text: '.' * (3 - dotCount),
                style: widget.style?.copyWith(color: Colors.transparent) ?? const TextStyle(color: Colors.transparent),
              ),
            ],
          ),
        );
      },
    );
  }
}
