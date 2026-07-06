import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
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

  final List<ShopFeedItemDto> _items = [];
  final Map<int, bool> _localFavorites = {};

  int _currentPage = 0;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  bool _armedForNextPage = true;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ExploreMenuSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      setState(() {
        _items.clear();
        _currentPage = 0;
        _hasMore = true;
        _isInitialLoading = true;
        _isLoadingMore = false;
      });
      _loadInitial();
    }
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    final nearEnd = position.pixels >= position.maxScrollExtent - 400;

    if (!nearEnd) {
      _armedForNextPage = true;
      return;
    }

    if (!_armedForNextPage ||
        _isLoadingMore ||
        _isInitialLoading ||
        !_hasMore) {
      return;
    }

    _armedForNextPage = false;
    _loadMore();
  }

  Future<List<ShopFeedItemDto>> _fetchPage(int page) async {
    final section = await RestaurantRepository.instance.getFoodTabFeed(
      feedType: _feedType,
      lat: widget.latitude,
      lon: widget.longitude,
      radiusKm: widget.radiusKm,
      page: page,
      size: _pageSize,
    );
    return section.items;
  }

  Future<void> _loadInitial() async {
    try {
      final items = await _fetchPage(0);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _currentPage = 0;
        _hasMore = items.length >= _pageSize;
        _isInitialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isInitialLoading) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final moreItems = await _fetchPage(nextPage);
      if (!mounted) return;
      setState(() {
        _items.addAll(moreItems);
        _currentPage = nextPage;
        _hasMore = moreItems.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
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
        SnackBar(
          content: Text(context.tr('common.favorite_failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return _buildSkeleton();
    }
    if (_items.isEmpty) {
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
    final showFooter = _isLoadingMore || !_hasMore;

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
                final item = _items[i];
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
              childCount: _items.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              if (showFooter)
                _ExploreFooter(
                  isLoading: _isLoadingMore,
                  showEndMessage: !_hasMore,
                ),
              if (!showFooter) const SizedBox(height: 24),
            ],
          ),
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
              (_, _) => const FoodMenuItemSkeleton(),
              childCount: crossAxisCount * 2,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }
}

class _ExploreFooter extends StatelessWidget {
  final bool isLoading;
  final bool showEndMessage;

  const _ExploreFooter({
    required this.isLoading,
    required this.showEndMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!showEndMessage) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 8),
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
    );
  }
}
