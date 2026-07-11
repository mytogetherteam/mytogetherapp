import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../data/repositories/swipe_ranking_repository.dart';
import '../screens/restaurant_detail_page.dart';

// ─── Page entry point ─────────────────────────────────────────────────────────

class FoodSwipeRankPage extends StatefulWidget {
  const FoodSwipeRankPage({super.key});

  @override
  State<FoodSwipeRankPage> createState() => _FoodSwipeRankPageState();
}

class _FoodSwipeRankPageState extends State<FoodSwipeRankPage> with TickerProviderStateMixin {
  final List<ShopFeedItemDto> _items = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  int _likeCount = 0;
  int _skipCount = 0;
  int _totalSeen = 0;
  int _page = 0;
  final int _pageSize = 20;

  bool _showActionOverlay = false;
  bool _isLikeAction = true;
  AnimationController? _actionController;

  List<ShopFeedItemDto> _todayLikedItems = [];
  bool _isFetchingLikedItems = false;
  bool _hasFetchedLikedItems = false;

  @override
  void initState() {
    super.initState();
    _actionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadInitial();
  }

  @override
  void dispose() {
    _actionController?.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _page = 0;
      _hasFetchedLikedItems = false;
      _todayLikedItems = [];
    });
    await _fetchPage(_page);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchPage(int pageToFetch) async {
    try {
      final newItems = await SwipeRankingRepository.instance.getSwipeCandidates(limit: _pageSize);

      if (mounted) {
        setState(() {
          final existingIds = _items.map((e) => e.id).toSet();
          final uniqueNewItems = newItems.where((e) => !existingIds.contains(e.id)).toList();
          _items.addAll(uniqueNewItems);
        });
      }
    } catch (_) {
      // Handle error implicitly by keeping what we have
    }
  }

  void _checkAndFetchMore() {
    // If we have 3 or fewer items left, start fetching the next page
    if (_items.length <= 3 && !_isFetchingMore) {
      _isFetchingMore = true;
      _page++;
      _fetchPage(_page).then((_) {
        if (mounted) {
          setState(() {
            _isFetchingMore = false;
          });
        }
      });
    }
  }

  void _triggerActionAnimation(bool isLike) {
    setState(() {
      _showActionOverlay = true;
      _isLikeAction = isLike;
    });
    _actionController?.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _showActionOverlay = false;
        });
      }
    });
  }

  void _onLike() {
    if (_items.isEmpty) return;
    final item = _items[0];
    SwipeRankingRepository.instance.submitSwipe(item.id, true);
    
    _triggerActionAnimation(true);
    setState(() {
      _items.removeAt(0);
      _likeCount++;
      _totalSeen++;
    });
    _checkAndFetchMore();
  }

  void _onSkip() {
    if (_items.isEmpty) return;
    final item = _items[0];
    SwipeRankingRepository.instance.submitSwipe(item.id, false);
    
    _triggerActionAnimation(false);
    setState(() {
      _items.removeAt(0);
      _skipCount++;
      _totalSeen++;
    });
    _checkAndFetchMore();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF16213E),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildStats(),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildCardArea()),
                      Positioned.fill(child: IgnorePointer(child: _buildActionOverlay())),
                    ],
                  ),
                ),
                _buildButtons(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionOverlay() {
    if (!_showActionOverlay || _actionController == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _actionController!,
      builder: (context, child) {
        final progress = _actionController!.value;
        // Scale from 0.5 to 2.0
        final scale = 0.5 + (progress * 1.5);
        // Fade in fast, then fade out
        final opacity = progress < 0.2 ? (progress / 0.2) : (1.0 - ((progress - 0.2) / 0.8));
        
        return Center(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Icon(
                _isLikeAction ? Icons.favorite_rounded : Icons.close_rounded,
                color: _isLikeAction ? const Color(0xFFFF4D6D) : Colors.white,
                size: 140,
                shadows: [
                  Shadow(
                    color: _isLikeAction 
                        ? const Color(0xFFFF4D6D).withValues(alpha: 0.5) 
                        : Colors.white.withValues(alpha: 0.5),
                    blurRadius: 30,
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                context.tr('food.swipe_rank_title'),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                context.tr('food.swipe_rank_sub'),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 40), // Invisible placeholder to keep title centered
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatChip(
            icon: Icons.favorite_rounded,
            label: '$_likeCount',
            color: const Color(0xFFFF4D6D),
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.close_rounded,
            label: '$_skipCount',
            color: Colors.white38,
          ),
        ],
      ),
    );
  }

  Widget _buildCardArea() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF4D6D)),
      );
    }
    if (_items.isEmpty) {
      if (_isLoading) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF4D6D)),
        );
      }
      return _buildEmptyState();
    }

    // Show max 3 stacked cards
    final visible = _items.take(3).toList().reversed.toList();

    return Stack(
      alignment: Alignment.center,
      children: [
        for (int i = 0; i < visible.length; i++)
          _buildStackedCard(visible[i], i, visible.length),
      ],
    );
  }

  Widget _buildStackedCard(ShopFeedItemDto item, int index, int total) {
    final isTop = index == total - 1;
    final scale = 1.0 - (total - 1 - index) * 0.04;
    final offsetY = (total - 1 - index) * 14.0;

    if (isTop) {
      return _DraggableCard(
        key: ValueKey(item.id),
        item: item,
        onLike: _onLike,
        onSkip: _onSkip,
      );
    }

    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Transform.scale(
        scale: scale,
        child: _FoodCard(item: item, isInteractive: false),
      ),
    );
  }

  Future<void> _fetchTodayLikedItems() async {
    setState(() {
      _isFetchingLikedItems = true;
    });
    final items = await SwipeRankingRepository.instance.getTodayLikedItems();
    if (mounted) {
      setState(() {
        _todayLikedItems = items;
        _isFetchingLikedItems = false;
        _hasFetchedLikedItems = true;
      });
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Text(
            context.tr('food.swipe_done_title'),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Come back tomorrow!',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Skip button
          GestureDetector(
            onTap: _onSkip,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white60, size: 30),
            ),
          ),
          const SizedBox(width: 32),
          // Like button (bigger, primary action)
          GestureDetector(
            onTap: _onLike,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF4D6D), Color(0xFFFF8E53)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D6D).withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 34),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Draggable top card ────────────────────────────────────────────────────────

class _DraggableCard extends StatefulWidget {
  final ShopFeedItemDto item;
  final VoidCallback onLike;
  final VoidCallback onSkip;

  const _DraggableCard({
    super.key,
    required this.item,
    required this.onLike,
    required this.onSkip,
  });

  @override
  State<_DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<_DraggableCard>
    with SingleTickerProviderStateMixin {
  Offset _offset = Offset.zero;
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;
  bool _isDragging = false;

  static const double _swipeThreshold = 100.0;
  static const double _dismissDistance = 500.0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d) {
    _snapController.stop();
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _offset += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    setState(() => _isDragging = false);
    final velocity = d.velocity.pixelsPerSecond.dx;
    final shouldDismissRight = _offset.dx > _swipeThreshold || velocity > 800;
    final shouldDismissLeft = _offset.dx < -_swipeThreshold || velocity < -800;

    if (shouldDismissRight) {
      _animateOut(toRight: true);
    } else if (shouldDismissLeft) {
      _animateOut(toRight: false);
    } else {
      _snapBack();
    }
  }

  void _animateOut({required bool toRight}) {
    final endX = toRight ? _dismissDistance : -_dismissDistance;
    final endY = _offset.dy;
    final begin = _offset;
    final end = Offset(endX, endY);

    _snapAnimation = Tween<Offset>(begin: begin, end: end).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
    );
    _snapController.forward(from: 0).then((_) {
      if (toRight) {
        widget.onLike();
      } else {
        widget.onSkip();
      }
    });
    _snapController.addListener(() {
      if (mounted) setState(() => _offset = _snapAnimation.value);
    });
  }

  void _snapBack() {
    final begin = _offset;
    _snapAnimation = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
    );
    _snapController.duration = const Duration(milliseconds: 500);
    _snapController.forward(from: 0);
    _snapController.addListener(() {
      if (mounted) setState(() => _offset = _snapAnimation.value);
    });
  }

  double get _rotationAngle => _offset.dx / 1000;
  double get _likeOpacity => (_offset.dx / _swipeThreshold).clamp(0.0, 1.0);
  double get _skipOpacity => (-_offset.dx / _swipeThreshold).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: () {
        if (!_isDragging) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantDetailPage(
                id: widget.item.shopId.toString(),
                name: widget.item.shopName,
                rating: widget.item.rating,
                distance: widget.item.distanceKm != null ? '${widget.item.distanceKm!.toStringAsFixed(1)} km' : null,
                deliveryTime: widget.item.estimatedTime,
                imagePath: widget.item.shopLogoUrl ?? widget.item.imageUrl,
                targetMenuItemId: widget.item.id.toString(), // Navigate directly to menu item
              ),
            ),
          );
        }
      },
      child: Transform.translate(
        offset: _offset,
        child: Transform.rotate(
          angle: _rotationAngle,
          child: Stack(
            children: [
              _FoodCard(item: widget.item, isInteractive: true),
              // Like overlay
              if (_likeOpacity > 0.01)
                _SwipeOverlay(
                  label: '❤️',
                  labelText: 'LIKE',
                  color: const Color(0xFFFF4D6D),
                  opacity: _likeOpacity,
                  alignment: Alignment.topLeft,
                ),
              // Skip overlay
              if (_skipOpacity > 0.01)
                _SwipeOverlay(
                  label: '✖',
                  labelText: 'NOPE',
                  color: Colors.white,
                  opacity: _skipOpacity,
                  alignment: Alignment.topRight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Swipe overlay badge ──────────────────────────────────────────────────────

class _SwipeOverlay extends StatelessWidget {
  final String label;
  final String labelText;
  final Color color;
  final double opacity;
  final Alignment alignment;

  const _SwipeOverlay({
    required this.label,
    required this.labelText,
    required this.color,
    required this.opacity,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: alignment,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: alignment == Alignment.topLeft ? -0.3 : 0.3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 3),
                  borderRadius: BorderRadius.circular(12),
                  color: color.withValues(alpha: 0.15),
                ),
                child: Text(
                  labelText,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Food card visual ─────────────────────────────────────────────────────────

class _FoodCard extends StatelessWidget {
  final ShopFeedItemDto item;
  final bool isInteractive;

  const _FoodCard({required this.item, required this.isInteractive});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth = screenWidth - 48;
    final cardHeight = screenHeight * 0.52;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Food image
            (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: const Color(0xFF1A1A2E),
                      child: const Center(
                        child: Icon(Icons.fastfood_rounded,
                            color: Colors.white24, size: 48),
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: const Color(0xFF1A1A2E),
                      child: const Center(
                        child: Icon(Icons.fastfood_rounded,
                            color: Colors.white24, size: 48),
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFF1A1A2E),
                    child: const Center(
                      child: Icon(Icons.fastfood_rounded,
                          color: Colors.white24, size: 64),
                    ),
                  ),

            // Bottom gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.45, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
            ),

            // Top gradient for better readability of the banner
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 100,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Restaurant banner on the card
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RestaurantDetailPage(
                        id: item.shopId.toString(),
                        name: item.shopName,
                        rating: item.rating,
                        distance: item.distanceKm != null ? '${item.distanceKm!.toStringAsFixed(1)} km' : null,
                        deliveryTime: item.estimatedTime,
                        imagePath: item.shopLogoUrl ?? item.imageUrl,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                  child: Row(
                    children: [
                      if (item.shopLogoUrl != null && item.shopLogoUrl!.isNotEmpty)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: item.shopLogoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const Center(
                                child: Icon(Icons.storefront_rounded, color: Colors.grey, size: 14),
                              ),
                              errorWidget: (_, _, _) => const Center(
                                child: Icon(Icons.storefront_rounded, color: Colors.grey, size: 14),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D6D).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFFFF4D6D), size: 16),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.shopName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
            // Discount badge top-right (shifted down below the banner)
            if (item.hasDiscount)
              Positioned(
                top: 80,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D6D), Color(0xFFFF8E53)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🔥 HOT DEAL',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Content at bottom
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Food name
                  Text(
                    item.name,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Shop name
                  Row(
                    children: [
                      const Icon(Icons.store_rounded,
                          color: Colors.white54, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.shopName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Price row
                  Row(
                    children: [
                      if (item.hasDiscount && item.originalPrice != null) ...[
                        Text(
                          '฿ ${item.originalPrice!.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white38,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.white38,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF4D6D), Color(0xFFFF8E53)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.displayPrice ??
                              '฿ ${item.price.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Swipe hint (only top card)
            if (isInteractive)
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

