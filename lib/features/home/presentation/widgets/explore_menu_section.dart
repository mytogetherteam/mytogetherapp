import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/utils/paginated_list_controller.dart';
import 'package:mytogetherapp/core/presentation/utils/pagination_scroll.dart';
import 'package:mytogetherapp/core/presentation/widgets/pagination_list_footer.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import 'food_menu_item_card.dart';
import 'food_menu_item_skeleton.dart';

/// Explore Menu feed that keeps loading more items (via the `explore` food-tab
/// endpoint) as the user scrolls the parent page, for as long as the API keeps
/// returning full pages.
///
/// Unlike [FoodFeedSection] which renders a single capped page, this section
/// drives infinite pagination off the parent [scrollController]. It must be the
/// last section in the scroll view so reaching its bottom means reaching the
/// page bottom.
class ExploreMenuSection extends StatefulWidget {
  final String title;
  final double latitude;
  final double longitude;
  final double radiusKm;

  /// The scroll controller of the parent scroll view. Used to detect when the
  /// user is near the bottom so the next page can be fetched.
  final ScrollController scrollController;

  const ExploreMenuSection({
    super.key,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.scrollController,
    this.radiusKm = 10.0,
  });

  @override
  State<ExploreMenuSection> createState() => _ExploreMenuSectionState();
}

class _ExploreMenuSectionState extends State<ExploreMenuSection> {
  static const int _pageSize = 20;
  static const String _feedType = 'explore';

  late final PaginatedListController<ShopFeedItemDto> _pagination;
  final Map<int, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    _pagination = PaginatedListController<ShopFeedItemDto>(
      pageSize: _pageSize,
      initialPage: 0,
      pixelPrefetchThreshold: PaginationScroll.exploreEndThreshold,
      itemKey: (item) => item.id,
      fetchPage: _fetchPage,
    )..addListener(_onPaginationChanged);
    _pagination.attachScrollController(widget.scrollController);
    _pagination.loadInitial();
  }

  @override
  void dispose() {
    _pagination
      ..removeListener(_onPaginationChanged)
      ..dispose();
    super.dispose();
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ExploreMenuSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _pagination.loadInitial();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _pagination.attachScrollController(widget.scrollController);
    }
  }

  Future<PaginatedPage<ShopFeedItemDto>> _fetchPage(int page) async {
    final section = await RestaurantRepository.instance.getFoodTabFeed(
      feedType: _feedType,
      lat: widget.latitude,
      lon: widget.longitude,
      radiusKm: widget.radiusKm,
      page: page,
      size: _pageSize,
    );
    final items = section.items;
    return PaginatedPage(
      items: items,
      hasMore: items.length >= _pageSize,
    );
  }

  Future<void> _toggleFavorite(ShopFeedItemDto item) async {
    final newStatus = !(_localFavorites[item.id] ?? item.isFavorite);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _localFavorites[item.id] = newStatus);
    try {
      await RestaurantRepository.instance.toggleMenuFavorite(item.id, newStatus);
    } catch (_) {
      if (!mounted) return;
      setState(() => _localFavorites[item.id] = !newStatus);
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('common.favorite_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pagination.isInitialLoading) {
      return _buildSkeleton();
    }

    if (_pagination.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Center(
            child: Text(
              context.tr('food.end_of_list'),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    }

    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
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
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                _pagination.onItemVisible(i);
                final item = _pagination.items[i];
                return FoodMenuItemCard(
                  id: item.id.toString(),
                  restaurantId: item.shopId.toString(),
                  title: item.name,
                  price: item.price,
                  currency: item.currency,
                  imagePath: item.imageUrl ?? '',
                  restaurantName: item.shopName,
                  isFavorite: _localFavorites[item.id] ?? item.isFavorite,
                  rating: item.rating,
                  reviewCount: item.reviewCount,
                  distanceKm: item.distanceKm,
                  estimatedTime: item.estimatedTime,
                  deliveryFee: item.deliveryFee,
                  originalDeliveryFee: item.originalDeliveryFee,
                  originalPrice: item.originalPrice,
                  displayPrice: item.displayPrice,
                  onFavoriteToggle: () => _toggleFavorite(item),
                  forceRestaurantNavigation: true,
                  isAvailable: item.isAvailable,
                  publishStatus: item.publishStatus,
                  deliveryEnabled: item.deliveryEnabled,
                  operatingHours: item.operatingHours,
                  restaurantStatus: item.restaurantStatus,
                );
              },
              childCount: _pagination.items.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _pagination.showFooter
              ? PaginationListFooter(
                  isLoading: _pagination.isLoadingMore,
                  showEndMessage: !_pagination.hasMore,
                )
              : const SizedBox(height: 24),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
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
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => const FoodMenuItemSkeleton(),
              childCount: crossAxisCount * 2,
            ),
          ),
        ),
      ],
    );
  }
}
