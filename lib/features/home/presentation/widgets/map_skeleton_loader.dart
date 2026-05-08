import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

/// A skeleton loader that mimics a real map with roads, blocks and pin placeholders.
class MapSkeletonLoader extends StatefulWidget {
  const MapSkeletonLoader({super.key});

  @override
  State<MapSkeletonLoader> createState() => _MapSkeletonLoaderState();
}

class _MapSkeletonLoaderState extends State<MapSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
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
      animation: _shimmerAnim,
      builder: (context, _) {
        final shimmerGradient = LinearGradient(
          begin: Alignment(_shimmerAnim.value - 1, -0.2),
          end: Alignment(_shimmerAnim.value + 1, 0.2),
          colors: const [
            Color(0xFFEEEEEE),
            Color(0xFFFAFAFA),
            Color(0xFFEEEEEE),
          ],
          stops: const [0.0, 0.5, 1.0],
        );

        return Container(
          decoration: const BoxDecoration(color: Color(0xFFE8EAE6)),
          child: Stack(
            children: [
              // Road network (CustomPainter)
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoadMapPainter(shimmer: shimmerGradient),
                ),
              ),

              // Park / water block (top-left)
              Positioned(
                top: 60,
                left: 30,
                child: _block(80, 50, const Color(0xFFD8EAD3), shimmerGradient, radius: 4),
              ),

              // Building blocks - scattered
              Positioned(
                top: 140,
                left: 20,
                child: _block(50, 34, const Color(0xFFDDDDDD), shimmerGradient),
              ),
              Positioned(
                top: 180,
                left: 100,
                child: _block(38, 38, const Color(0xFFDDDDDD), shimmerGradient),
              ),
              Positioned(
                top: 100,
                right: 60,
                child: _block(70, 44, const Color(0xFFDDDDDD), shimmerGradient),
              ),
              Positioned(
                top: 170,
                right: 20,
                child: _block(55, 28, const Color(0xFFDDDDDD), shimmerGradient),
              ),

              // Pin skeletons
              _pin(context, top: 0.25, left: 0.28, shimmer: shimmerGradient, width: 90),
              _pin(context, top: 0.15, left: 0.6, shimmer: shimmerGradient, width: 75),
              _pin(context, top: 0.35, left: 0.75, shimmer: shimmerGradient, width: 85),
            ],
          ),
        );
      },
    );
  }

  Widget _block(double w, double h, Color fill, LinearGradient shimmer,
      {double radius = 2}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: shimmer.scale(0.6), // dimmer shimmer on blocks
        color: fill,
      ),
    );
  }

  Widget _pin(BuildContext context,
      {required double top,
      required double left,
      required LinearGradient shimmer,
      required double width}) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;
    return Positioned(
      top: h * top,
      left: w * left,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label pill
          Container(
            width: width,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: width * 0.5,
                  height: 7,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // Tail
          Container(
            width: 2,
            height: 8,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
          // Dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws stylized road segments to simulate a real map background.
class _RoadMapPainter extends CustomPainter {
  final LinearGradient shimmer;
  _RoadMapPainter({required this.shimmer});

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final minorPaint = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // Major horizontal roads
    canvas.drawLine(Offset(0, size.height * 0.32), Offset(size.width, size.height * 0.32), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.58), Offset(size.width, size.height * 0.58), roadPaint);

    // Major vertical roads
    canvas.drawLine(Offset(size.width * 0.38, 0), Offset(size.width * 0.38, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.72, 0), Offset(size.width * 0.72, size.height), roadPaint);

    // Minor horizontal
    canvas.drawLine(Offset(0, size.height * 0.18), Offset(size.width * 0.7, size.height * 0.18), minorPaint);
    canvas.drawLine(Offset(size.width * 0.35, size.height * 0.75), Offset(size.width, size.height * 0.75), minorPaint);

    // Minor vertical
    canvas.drawLine(Offset(size.width * 0.55, size.height * 0.3), Offset(size.width * 0.55, size.height * 0.6), minorPaint);
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.2, size.height * 0.35), minorPaint);

    // Diagonal road (like a diagonal street)
    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width * 0.38, size.height * 0.32), minorPaint);
  }

  @override
  bool shouldRepaint(covariant _RoadMapPainter oldDelegate) => false;
}

extension ShimmerScale on LinearGradient {
  LinearGradient scale(double factor) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors
          .map((c) => c.withValues(alpha: (c.a * factor).clamp(0.0, 1.0)))
          .toList(),
      stops: stops,
    );
  }
}
