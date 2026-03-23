import 'package:flutter/material.dart';

class NewsFeedItemSkeleton extends StatefulWidget {
  const NewsFeedItemSkeleton({super.key});

  @override
  State<NewsFeedItemSkeleton> createState() => _NewsFeedItemSkeletonState();
}

class _NewsFeedItemSkeletonState extends State<NewsFeedItemSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
    const double avatarRadius = 20.0;
    const double avatarGap = 14.0;
    const double outerPadding = 16.0;
    const double leftContentOffset = outerPadding + (avatarRadius * 2) + avatarGap;

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
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section: Avatar and Content Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: outerPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Avatar
                    Container(
                      width: avatarRadius * 2,
                      height: avatarRadius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: shimmerGradient,
                      ),
                    ),
                    const SizedBox(width: avatarGap),
                    // Right Column: Content Header
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 14,
                                width: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: shimmerGradient,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                height: 12,
                                width: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: shimmerGradient,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Content line 1
                          Container(
                            height: 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: shimmerGradient,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Content line 2
                          Container(
                            height: 14,
                            width: MediaQuery.of(context).size.width * 0.6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: shimmerGradient,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Middle Section: Image Placeholder
              Padding(
                padding: const EdgeInsets.only(top: 16.0, left: leftContentOffset, right: 40.0),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: shimmerGradient,
                  ),
                ),
              ),

              // Bottom Section: Interaction Buttons
              Padding(
                padding: const EdgeInsets.only(left: leftContentOffset, top: 16.0, right: outerPadding),
                child: Row(
                  children: [
                    Container(
                      height: 24,
                      width: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: shimmerGradient,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      height: 24,
                      width: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: shimmerGradient,
                      ),
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
