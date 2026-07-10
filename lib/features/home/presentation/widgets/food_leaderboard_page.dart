import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_text.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../screens/menu_detail_page.dart';
import '../screens/restaurant_detail_page.dart';
import '../screens/food_swipe_rank_page.dart';

/// Full-screen leaderboard page — top 3 podium + ranked list 4-20.
class FoodLeaderboardPage extends StatelessWidget {
  final List<ShopFeedItemDto> items;

  const FoodLeaderboardPage({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final top3 = items.take(3).toList();
    final rest = items.skip(3).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1E),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ──────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: const Color(0xFF1A1A2E),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                children: [
                  Text(
                    context.tr('food.leaderboard_title'),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    context.tr('food.leaderboard_sub'),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),

            // ── Podium (top 3) ────────────────────────────────────────
            SliverToBoxAdapter(
              child: _PodiumSection(top3: top3),
            ),

            // ── Swipe Promo Banner ────────────────────────────────
            SliverToBoxAdapter(
              child: _SwipePromoBanner(),
            ),

            // ── Divider ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.1),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        context.tr('food.leaderboard_rest_title'),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.1),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Ranks 4-20 ────────────────────────────────────────────
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = rest[index];
                  final rank = index + 4;
                  return _RankListTile(item: item, rank: rank);
                },
                childCount: rest.length,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ── Podium (top 3) ────────────────────────────────────────────────────────────

class _PodiumSection extends StatelessWidget {
  final List<ShopFeedItemDto> top3;

  const _PodiumSection({required this.top3});

  @override
  Widget build(BuildContext context) {
    if (top3.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1E)],
          ),
        ),
        child: Text(
          context.tr('food.leaderboard_empty_msg'),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      );
    }

    // Build the three columns: 2nd | 1st | 3rd  (podium order)
    final podiumOrder = <ShopFeedItemDto?>[];
    podiumOrder.add(top3.length > 1 ? top3[1] : null); // 2nd
    podiumOrder.add(top3.isNotEmpty ? top3[0] : null);  // 1st
    podiumOrder.add(top3.length > 2 ? top3[2] : null);  // 3rd

    final podiumHeights = [80.0, 120.0, 60.0]; // 2nd, 1st, 3rd
    final ranks = [2, 1, 3];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1E)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          // Avatar + name row (above podium blocks)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final item = podiumOrder[i];
              if (item == null) return const Expanded(child: SizedBox());
              final rank = ranks[i];
              final medalColor = rank == 1
                  ? const Color(0xFFFFD700)
                  : rank == 2
                      ? const Color(0xFFC0C0C0)
                      : const Color(0xFFCD7F32);
              final isFirst = rank == 1;

              return Expanded(
                child: _PodiumAvatarCol(
                  item: item,
                  rank: rank,
                  medalColor: medalColor,
                  isFirst: isFirst,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Podium blocks row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final rank = ranks[i];
              final medalColor = rank == 1
                  ? const Color(0xFFFFD700)
                  : rank == 2
                      ? const Color(0xFF6C8EBF) // blue-silver
                      : const Color(0xFFE8896A); // coral-bronze
              return Expanded(
                child: _PodiumBlock(
                  rank: rank,
                  height: podiumHeights[i],
                  color: medalColor,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PodiumAvatarCol extends StatelessWidget {
  final ShopFeedItemDto item;
  final int rank;
  final Color medalColor;
  final bool isFirst;

  const _PodiumAvatarCol({
    required this.item,
    required this.rank,
    required this.medalColor,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = isFirst ? 84.0 : 68.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MenuDetailPage(
            id: item.id.toString(),
            restaurantId: item.shopId.toString(),
            title: item.name,
            price: item.price,
            currency: item.currency,
            imagePath: item.imageUrl ?? '',
            restaurantName: item.shopName,
            displayPrice: item.displayPrice,
            description: '',
            isFavorite: item.isFavorite,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown / rank badge
          if (isFirst)
            Text('👑', style: TextStyle(fontSize: isFirst ? 20 : 14))
          else
            const SizedBox(height: 4),
          const SizedBox(height: 4),
          // Food image as avatar
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: medalColor,
                    width: isFirst ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: medalColor.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (_, _) => Container(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: const Icon(Icons.fastfood_rounded,
                                color: Colors.white38),
                          ),
                        )
                      : Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Icon(Icons.fastfood_rounded,
                              color: Colors.white38),
                        ),
                ),
              ),
              // Rank circle
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: medalColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            style: GoogleFonts.poppins(
              fontSize: isFirst ? 12 : 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Price + discount
          _PriceTag(item: item, medalColor: medalColor, small: !isFirst),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  final int rank;
  final double height;
  final Color color;

  const _PodiumBlock({
    required this.rank,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.55),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$rank',
                style: GoogleFonts.poppins(
                  fontSize: rank == 1 ? 32 : 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              // Laurel wreath emoji
              Text(
                '🏅',
                style: TextStyle(fontSize: rank == 1 ? 16 : 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rank list tile (4-20) ─────────────────────────────────────────────────────

class _RankListTile extends StatelessWidget {
  final ShopFeedItemDto item;
  final int rank;

  const _RankListTile({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailPage(
            id: item.shopId.toString(),
            name: item.shopName,
            targetMenuItemId: item.id.toString(),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      color: Colors.white24, size: 14),
                  Text(
                    '$rank',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Food image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 60,
                height: 60,
                child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 180,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, _) =>
                            Container(color: Colors.white.withValues(alpha: 0.05)),
                        errorWidget: (_, _, _) => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Icon(Icons.fastfood_rounded,
                              color: Colors.white24),
                        ),
                      )
                    : Container(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: const Icon(Icons.fastfood_rounded,
                            color: Colors.white24),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + restaurant
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.shopName,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Price column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.hasDiscount && item.originalPrice != null)
                  Text(
                    '฿ ${item.originalPrice!.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white30,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.white30,
                    ),
                  ),
                GradientText(
                  item.displayPrice ?? '฿ ${item.price.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Price tag widget (used in podium avatar) ──────────────────────────────────

class _PriceTag extends StatelessWidget {
  final ShopFeedItemDto item;
  final Color medalColor;
  final bool small;

  const _PriceTag({
    required this.item,
    required this.medalColor,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 10.0 : 11.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.hasDiscount && item.originalPrice != null)
          Text(
            '฿ ${item.originalPrice!.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: fontSize - 1,
              color: Colors.white30,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.white30,
            ),
          ),
        GradientText(
          item.displayPrice ?? '฿ ${item.price.toStringAsFixed(0)}',
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Swipe Promo Banner ────────────────────────────────────────────────────────

class _SwipePromoBanner extends StatelessWidget {
  const _SwipePromoBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FoodSwipeRankPage()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Mini card stack illustration
            SizedBox(
              width: 64,
              height: 56,
              child: Stack(
                children: [
                  // Back card (pink)
                  Positioned(
                    right: 0,
                    top: 4,
                    child: Transform.rotate(
                      angle: 0.18,
                      child: Container(
                        width: 40,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB3C1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  // Front card (gradient)
                  Positioned(
                    left: 0,
                    top: 4,
                    child: Transform.rotate(
                      angle: -0.12,
                      child: Container(
                        width: 40,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF4D6D), Color(0xFFFF8E53)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4D6D).withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('❤️', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Text content
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
                  const SizedBox(height: 3),
                  Text(
                    context.tr('food.swipe_promo_sub'),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // CTA button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4D6D), Color(0xFFFF8E53)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D6D).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                  const SizedBox(width: 5),
                  const Icon(Icons.swipe_rounded,
                      color: Colors.white, size: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

