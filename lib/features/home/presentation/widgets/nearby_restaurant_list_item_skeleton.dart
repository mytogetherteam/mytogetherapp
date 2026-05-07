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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
            ),
            color: Colors.white,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Image Placeholder
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: shimmerGradient,
                ),
                child: Center(
                  child: Opacity(
                    opacity: 0.2,
                    child: Image.asset(
                      'assets/images/icon.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Right: Content Placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Placeholder
                    Container(
                      height: 16,
                      width: double.infinity,
                      margin: const EdgeInsets.only(right: 40),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: shimmerGradient,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Category & Rating Placeholder
                    Row(
                      children: [
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: shimmerGradient,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 12,
                          width: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: shimmerGradient,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Distance, Time, Status Placeholder
                    Row(
                      children: [
                        Container(
                          height: 12,
                          width: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: shimmerGradient,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 12,
                          width: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: shimmerGradient,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 12,
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
