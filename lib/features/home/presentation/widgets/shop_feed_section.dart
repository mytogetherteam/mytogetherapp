import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'image_skeleton_loader.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import 'food_menu_item_card.dart';

/// Reusable section widget for any of the 5 shop feed endpoints.
/// Matches the style of TodaysOverviewSection (grid, skeleton, retry).
class ShopFeedSection extends StatefulWidget {
  final int shopId;
  final String feedType; // right-now | for-you | hot-deals | trending | popular-dishes
  final String title;
  final IconData? titleIcon;
  final bool showRestaurantName;
  /// Called with `true` when data loaded but was empty, `false` when data is present.
  final ValueChanged<bool>? onEmpty;

  const ShopFeedSection({
    super.key,
    required this.shopId,
    required this.feedType,
    required this.title,
    this.titleIcon,
    this.showRestaurantName = true,
    this.onEmpty,
    this.targetMenuItemId,
  });

  final String? targetMenuItemId;

  @override
  State<ShopFeedSection> createState() => _ShopFeedSectionState();
}

class _ShopFeedSectionState extends State<ShopFeedSection> {
  late Future<ShopFeedSectionDto> _future;
  final Map<int, bool> _localFavorites = {};
  bool _hasScrolled = false;
  final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<ShopFeedSectionDto> _fetch() =>
      RestaurantRepository.instance.getShopFeed(
        shopId: widget.shopId,
        feedType: widget.feedType,
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShopFeedSectionDto>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }
        if (snapshot.hasError) {
          // Notify parent that this section has no usable data (error counts as empty)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onEmpty?.call(true);
          });
          return const SizedBox.shrink();
        }
        final items = snapshot.data?.items ?? [];
        if (items.isEmpty) {
          // API succeeded but returned 0 items — show empty state, NOT retry
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onEmpty?.call(true);
          });
          return const SizedBox.shrink();
        }
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onEmpty?.call(false);
          });
        }
        
        // Trigger one-time scroll logic if needed
        if (!_hasScrolled) {
          _checkAndScrollToTarget(items);
        }

        return _buildContent(items);
      },
    );
  }

  // ── Content ─────────────────────────────────────────────────────────────
  Widget _buildContent(List<ShopFeedItemDto> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            widget.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
            childAspectRatio: 0.85,
          ),
          itemCount: (widget.targetMenuItemId != null && items.any((it) => it.id.toString() == widget.targetMenuItemId))
              ? items.length
              : (items.length > (MediaQuery.of(context).size.width > 600 ? 8 : 6) ? (MediaQuery.of(context).size.width > 600 ? 8 : 6) : items.length),
          itemBuilder: (context, i) {
            final item = items[i];
            final isTarget = widget.targetMenuItemId == item.id.toString();
            Widget card = FoodMenuItemCard(
              id: item.id.toString(),
              restaurantId: item.shopId.toString(),
              title: item.name,
              price: item.price,
              currency: item.currency,
              imagePath: item.imageUrl ?? '',
              restaurantName: item.shopName,
              isFavorite: _localFavorites[item.id] ?? item.isFavorite,
              originalPrice: item.originalPrice,
              displayPrice: item.displayPrice,
              showRestaurantName: widget.showRestaurantName,
              isHighlighted: isTarget,
              targetMenuItemId: widget.targetMenuItemId,
              rating: item.rating,
              reviewCount: item.reviewCount,
              distanceKm: item.distanceKm,
              estimatedTime: item.estimatedTime,
              deliveryFee: item.deliveryFee,
              originalDeliveryFee: item.originalDeliveryFee,
              onFavoriteToggle: () => _toggleFavorite(item),
            );
            
            return isTarget 
                ? Container(key: _targetKey, child: card) 
                : card;
          },
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  void _checkAndScrollToTarget(List<ShopFeedItemDto> items) {
    if (_hasScrolled || widget.targetMenuItemId == null) return;

    final targetIndex = items.indexWhere((it) => it.id.toString() == widget.targetMenuItemId);
    if (targetIndex == -1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted || _hasScrolled) return;

        final targetContext = _targetKey.currentContext;
        if (targetContext == null) return;

        _hasScrolled = true;

        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          alignment: 0.3, // Centers the item nicely in the upper half of screen
        );
      });
    });
  }

  Future<void> _toggleFavorite(ShopFeedItemDto item) async {
    final newStatus = !(_localFavorites[item.id] ?? item.isFavorite);
    final messenger = ScaffoldMessenger.of(context);
    
    // Immediate local feedback
    setState(() {
      _localFavorites[item.id] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleMenuFavorite(
        item.id,
        newStatus,
      );
      // No longer refreshing the future here to prevent flickering.
      // The local state _localFavorites handles the immediate color change.
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Added to favorites' : 'Removed from favorites'),
            backgroundColor: const Color(0xFFED3A72),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _localFavorites[item.id] = !newStatus;
        });
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Failed to update favorite. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Skeleton ─────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _shimmerBox(width: 150, height: 20, radius: 8),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
            childAspectRatio: 0.85,
          ),
          itemCount: MediaQuery.of(context).size.width > 600 ? 4 : 4,
          itemBuilder: (_, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const ImageSkeletonLoader(),
                ),
              ),
              const SizedBox(height: 6),
              _shimmerBox(width: 100, height: 14, radius: 6),
              const SizedBox(height: 4),
              _shimmerBox(width: 60, height: 14, radius: 6),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _shimmerBox({required double width, required double height, double radius = 8}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ImageSkeletonLoader(width: width, height: height),
    );
  }
}


