import 'package:flutter/material.dart';

class LocationSkeletonLoader extends StatefulWidget {
  final bool isList;
  final int itemCount;

  const LocationSkeletonLoader({
    super.key,
    this.isList = false,
    this.itemCount = 3,
  });

  @override
  State<LocationSkeletonLoader> createState() => _LocationSkeletonLoaderState();
}

class _LocationSkeletonLoaderState extends State<LocationSkeletonLoader>
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
    if (widget.isList) {
      return Column(
        children: List.generate(widget.itemCount, (index) => _buildListItem()),
      );
    }
    return _buildSingleBar();
  }

  Widget _buildSingleBar() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 16,
          width: widget.isList ? 140 : double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: _shimmerGradient(),
          ),
        );
      },
    );
  }

  Widget _buildListItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) => Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _shimmerGradient(),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) => Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: _shimmerGradient(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) => Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: _shimmerGradient(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _shimmerGradient() {
    return LinearGradient(
      begin: Alignment(_animation.value - 1, -0.3),
      end: Alignment(_animation.value + 1, 0.3),
      colors: [
        Colors.grey[300]!,
        Colors.grey[200]!,
        Colors.grey[300]!,
      ],
      stops: const [0.1, 0.5, 0.9],
    );
  }
}
