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

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
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
      return _buildEndOfListMessage();
    }

    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;
    // Append a final row of skeletons while the next page is loading.
    final placeholderCount =
        _isLoadingMore ? crossAxisCount : 0;

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
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
            childAspectRatio: 0.85,
          ),
          itemCount: _items.length + placeholderCount,
          itemBuilder: (context, i) {
            if (i >= _items.length) {
              return const FoodMenuItemSkeleton();
            }
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
            );
          },
        ),
        const SizedBox(height: 24),
        if (!_hasMore) _buildEndOfListMessage(),
      ],
    );
  }

  Widget _buildEndOfListMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 20),
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

  Widget _buildSkeleton() {
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;
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
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
            childAspectRatio: 0.85,
          ),
          itemCount: crossAxisCount * 2,
          itemBuilder: (_, _) => const FoodMenuItemSkeleton(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
