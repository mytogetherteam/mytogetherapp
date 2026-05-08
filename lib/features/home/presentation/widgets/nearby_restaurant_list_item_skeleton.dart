import 'package:flutter/material.dart';

class NearbyRestaurantListItemSkeleton extends StatefulWidget {
  const NearbyRestaurantListItemSkeleton({super.key});

  @override
  State<NearbyRestaurantListItemSkeleton> createState() => _NearbyRestaurantListItemSkeletonState();
}

class _NearbyRestaurantListItemSkeletonState extends State<NearbyRestaurantListItemSkeleton>
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
        final shimmerGradient = LinearGradient(
          begin: Alignment(_animation.value - 1, -0.3),
          end: Alignment(_animation.value + 1, 0.3),
          colors: [
            Colors.grey[200]!,
            Colors.grey[100]!,
            Colors.grey[200]!,
          ],
          stops: const [0.1, 0.5, 0.9],
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: Image Placeholder
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: shimmerGradient,
                ),
                child: Center(
                  child: Opacity(
                    opacity: 0.1,
                    child: Image.asset(
                      'assets/images/icon.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Bottom: Content Placeholders
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Placeholder
                    Container(
                      height: 18,
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: shimmerGradient,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Metadata Row Placeholder
                    Row(
                      children: [
                        Container(
                          height: 14,
                          width: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: shimmerGradient,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 14,
                          width: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: shimmerGradient,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 14,
                          width: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: shimmerGradient,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
