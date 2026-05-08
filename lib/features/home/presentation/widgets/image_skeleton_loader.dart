import 'package:flutter/material.dart';

class ImageSkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final bool showLogo;

  const ImageSkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = double.infinity,
    this.showLogo = false,
  });

  @override
  State<ImageSkeletonLoader> createState() => _ImageSkeletonLoaderState();
}

class _ImageSkeletonLoaderState extends State<ImageSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment(_animation.value - 1, -0.3),
                  end: Alignment(_animation.value + 1, 0.3),
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[100]!,
                    Colors.grey[300]!,
                  ],
                  stops: const [0.1, 0.5, 0.9],
                ),
              ),
            ),
            if (widget.showLogo)
              Opacity(
                opacity: 0.2,
                child: Image.asset(
                  'assets/images/icon.png',
                  width: (widget.width > 0 && widget.width != double.infinity) 
                      ? widget.width * 0.15 
                      : 40,
                  height: (widget.height > 0 && widget.height != double.infinity) 
                      ? widget.height * 0.15 
                      : 40,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        );
      },
    );
  }
}
