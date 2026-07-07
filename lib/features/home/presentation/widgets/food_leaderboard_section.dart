import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import 'image_skeleton_loader.dart';
import 'food_leaderboard_page.dart';
import '../screens/food_swipe_rank_page.dart';

/// Home/Food tab section block: "Top Leaderboard Food Today"
class FoodLeaderboardSection extends StatefulWidget {
  const FoodLeaderboardSection({super.key});

  @override
  State<FoodLeaderboardSection> createState() => _FoodLeaderboardSectionState();
}

class _FoodLeaderboardSectionState extends State<FoodLeaderboardSection> {
  Future<List<ShopFeedItemDto>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ShopFeedItemDto>> _load() async {
    try {
      final coords =
          await UserLocationRepository.instance.resolveActiveCoordinates();
      final section = await RestaurantRepository.instance.getFoodTabFeed(
        feedType: 'explore',
        lat: coords.lat,
        lon: coords.lon,
        radiusKm: 10,
        page: 0,
        size: 20,
      );
      final items = section.items.toList();
      items.shuffle(Random());
      return items.take(20).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopFeedItemDto>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();
        return _buildContent(items);
      },
    );
  }

  Widget _buildContent(List<ShopFeedItemDto> items) {
    final top3 = items.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Dark leaderboard top ──────────────────────────────
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FoodLeaderboardPage(items: items),
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      child: CustomPaint(painter: _StarsPainter()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                              ),
                              child: const Text('🏆', style: TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('food.leaderboard_title'),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    context.tr('food.leaderboard_sub'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.tr('common.see_all'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFFFD700),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 10, color: Color(0xFFFFD700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Top 3 podium preview
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (top3.length > 1)
                              Expanded(child: _MiniRankCard(item: top3[1], rank: 2)),
                            const SizedBox(width: 8),
                            if (top3.isNotEmpty)
                              Expanded(child: _MiniRankCard(item: top3[0], rank: 1)),
                            const SizedBox(width: 8),
                            if (top3.length > 2)
                              Expanded(child: _MiniRankCard(item: top3[2], rank: 3)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            context.tr('food.leaderboard_tap_hint'),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── White swipe promo bottom (bottom-sheet style) ─────
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FoodSwipeRankPage()),
            ),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                children: [
                  // Mini card stack illustration
                  SizedBox(
                    width: 60,
                    height: 52,
                    child: Stack(
                      children: [
                        // Back card
                        Positioned(
                          right: 0,
                          top: 4,
                          child: Transform.rotate(
                            angle: 0.15,
                            child: Container(
                              width: 38,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB3C1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        // Front card
                        Positioned(
                          left: 0,
                          top: 4,
                          child: Transform.rotate(
                            angle: -0.1,
                            child: Container(
                              width: 38,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFFF4D6D), Color(0xFFFF8E53)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF4D6D).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text('❤️', style: TextStyle(fontSize: 18)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('food.swipe_promo_title'),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('food.swipe_promo_sub'),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // CTA button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D6D), Color(0xFFFF8E53)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr('food.swipe_start'),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.swipe_rounded,
                            color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        child: ImageSkeletonLoader(),
      ),
    );
  }
}

// ── Mini rank card (inside section block) ────────────────────────────────────

class _MiniRankCard extends StatefulWidget {
  final ShopFeedItemDto item;
  final int rank;

  const _MiniRankCard({required this.item, required this.rank});

  @override
  State<_MiniRankCard> createState() => _MiniRankCardState();
}

class _MiniRankCardState extends State<_MiniRankCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
      value: (widget.rank * 0.3) % 1.0, // Add phase shift based on rank
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = widget.rank == 1;
    final medalColor = widget.rank == 1
        ? const Color(0xFFFFD700)
        : widget.rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    final imageHeight = isFirst ? 110.0 : 88.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Floating offset calculation using sine wave
        final double offset = sin((_controller.value * 2 * pi)) * 4.0;
        
        return Transform.translate(
          offset: Offset(0, offset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: medalColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: medalColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${widget.rank}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: imageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: medalColor.withValues(alpha: 0.6),
                      width: isFirst ? 2 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _FoodThumbImage(imageUrl: widget.item.imageUrl ?? ''),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.item.name,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                widget.item.displayPrice ?? '฿ ${widget.item.price.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: medalColor,
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FoodThumbImage extends StatelessWidget {
  final String imageUrl;
  const _FoodThumbImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.white.withValues(alpha: 0.05),
        child: const Icon(Icons.fastfood_rounded, color: Colors.white38, size: 28),
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.white.withValues(alpha: 0.05),
        child: const Icon(Icons.fastfood_rounded, color: Colors.white38, size: 28),
      ),
    );
  }
}

// ── Subtle stars painter ─────────────────────────────────────────────────────

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    const positions = [
      [0.08, 0.12], [0.3, 0.05], [0.55, 0.18], [0.78, 0.08], [0.92, 0.25],
      [0.15, 0.55], [0.85, 0.6], [0.45, 0.88], [0.7, 0.78], [0.25, 0.82],
    ];
    for (final p in positions) {
      canvas.drawCircle(Offset(p[0] * size.width, p[1] * size.height), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

