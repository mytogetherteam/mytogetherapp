import 'package:flutter/material.dart';
import 'image_skeleton_loader.dart';

class FoodMenuItemSkeleton extends StatefulWidget {
  const FoodMenuItemSkeleton({super.key});

  @override
  State<FoodMenuItemSkeleton> createState() => _FoodMenuItemSkeletonState();
}

class _FoodMenuItemSkeletonState extends State<FoodMenuItemSkeleton>
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Placeholder
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: const ImageSkeletonLoader(),
              ),
            ),
            const SizedBox(height: 12),
            // Title Placeholder
            Container(
              height: 14,
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
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
            const SizedBox(height: 8),
            // Price Placeholder
            Container(
              height: 14,
              width: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
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
          ],
        );
      },
    );
  }
}
