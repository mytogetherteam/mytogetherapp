import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/food_menu_item_card.dart';
import '../widgets/food_menu_item_skeleton.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/menu_item_dto.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../../../core/location/location_service.dart';
import '../../data/models/trending_item_dto.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../../../core/presentation/widgets/empty_state_view.dart';
import '../../../../core/presentation/utils/paginated_list_controller.dart';
import '../../../../core/presentation/widgets/pagination_list_footer.dart';
import '../../../../core/utils/api_response_utils.dart';

class TodayOverviewDetailPage extends StatefulWidget {
  /// When provided, the page paginates this shop-feed type (e.g. `hot-deals`)
  /// via `getFoodTabFeed`. When null, it shows trending items.
  final String? feedType;

  /// Optional title override; defaults to "Trending Near By".
  final String? title;

  /// When [feedType] is `hot-deals`, passed through to
  /// `GET /api/user/menu-items/discount` (from home-discount-section config).
  final int? discountPercentage;
  final String? discountSectionTitle;

  const TodayOverviewDetailPage({
    super.key,
    this.feedType,
    this.title,
    this.discountPercentage,
    this.discountSectionTitle,
  });

  @override
  State<TodayOverviewDetailPage> createState() => _TodayOverviewDetailPageState();
}

class _TodayOverviewDetailPageState extends State<TodayOverviewDetailPage> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  late final PaginatedListController<MenuItemDto> _pagination;
  final Map<String, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    _pagination = PaginatedListController<MenuItemDto>(
      pageSize: _pageSize,
      initialPage: 0,
      itemKey: (item) => item.id,
      fetchPage: _fetchPageForController,
    )..addListener(_onPaginationChanged);
    _pagination.attachScrollController(_scrollController);
    _pagination.loadInitial();
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pagination
      ..removeListener(_onPaginationChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<PaginatedPage<MenuItemDto>> _fetchPageForController(int page) async {
    final activeLoc = UserLocationRepository.instance.activeLocation;
    final pos = await LocationService().getCurrentPosition();
    final lat = activeLoc?.latitude ?? pos.latitude;
    final lon = activeLoc?.longitude ?? pos.longitude;

    if (widget.feedType == 'hot-deals') {
      final deals = await RestaurantRepository.instance.getDiscountDeals(
        lat: lat,
        lon: lon,
        percentage: widget.discountPercentage ?? 50,
        sectionTitle: widget.discountSectionTitle,
        page: page + 1,
        size: _pageSize,
        forceRefresh: page == 0,
      );
      final items = deals.items.map(_mapShopFeedToMenuItem).toList();
      final lastPage = deals.totalCount > 0
          ? ((deals.totalCount + _pageSize - 1) / _pageSize).ceil()
          : 0;
      return PaginatedPage(
        items: items,
        hasMore: ApiResponseUtils.hasMorePages(
          page: page + 1,
          lastPage: lastPage,
          itemCount: items.length,
          pageSize: _pageSize,
          totalCount: deals.totalCount,
        ),
      );
    }

    if (widget.feedType != null) {
      final section = await RestaurantRepository.instance.getFoodTabFeed(
        feedType: widget.feedType!,
        lat: lat,
        lon: lon,
        page: page,
        size: _pageSize,
      );
      return PaginatedPage(
        items: section.items.map(_mapShopFeedToMenuItem).toList(),
        hasMore: section.hasMore,
      );
    }

    final section = await RestaurantRepository.instance.getTrendingItems(
      lat: lat,
      lon: lon,
      page: page,
      size: _pageSize,
    );
    return PaginatedPage(
      items: section.items.map(_mapTrendingToMenuItem).toList(),
      hasMore: section.hasMore,
    );
  }

  MenuItemDto _mapShopFeedToMenuItem(ShopFeedItemDto s) {
    return MenuItemDto(
      id: s.id.toString(),
      restaurantId: s.shopId.toString(),
      restaurantName: s.shopName,
      title: s.name,
      price: s.price,
      currency: s.currency,
      imagePath: s.imageUrl ?? '',
      category: '',
      isFavorite: s.isFavorite,
      displayPrice: s.displayPrice,
      rating: s.rating,
      reviewCount: s.reviewCount,
      distanceKm: s.distanceKm,
      estimatedTime: s.estimatedTime,
      deliveryFee: s.deliveryFee,
      originalDeliveryFee: s.originalDeliveryFee,
      originalPrice: s.originalPrice,
      isAvailable: s.isAvailable,
      publishStatus: s.publishStatus,
    );
  }

  MenuItemDto _mapTrendingToMenuItem(TrendingItemDto t) {
    return MenuItemDto(
      id: t.id.toString(),
      restaurantId: t.shopId.toString(),
      restaurantName: t.shopName,
      title: t.name,
      price: t.price,
      currency: t.currency,
      imagePath: t.imageUrl,
      category: '',
      isFavorite: t.isFavorite,
      displayPrice: t.displayPrice,
      rating: t.rating,
      reviewCount: t.reviewCount,
      distanceKm: t.distanceKm,
      estimatedTime: t.estimatedTime,
      deliveryFee: t.deliveryFee,
      originalDeliveryFee: t.originalDeliveryFee,
      isAvailable: t.isAvailable,
      publishStatus: t.publishStatus,
    );
  }

  Future<void> _toggleFavorite(MenuItemDto item) async {
    final newStatus = !(_localFavorites[item.id] ?? item.isFavorite);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _localFavorites[item.id] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleMenuFavorite(
        int.tryParse(item.id) ?? 0,
        newStatus,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _localFavorites[item.id] = !newStatus;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr('common.favorite_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayTitle =
        widget.title ?? context.tr('home.trending_nearby');
    final int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;
    final items = _pagination.items;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          displayTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.black.withValues(alpha: 0.05),
            height: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _pagination.refresh();
        },
        color: AppColors.primary,
        child: items.isEmpty && _pagination.isInitialLoading
            ? GridView.builder(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: 48.0,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.75,
                ),
                itemCount: crossAxisCount * 3,
                itemBuilder: (context, index) => const FoodMenuItemSkeleton(),
              )
            : items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: const EmptyStateView(
                          icon: Icons.restaurant_menu_rounded,
                        ),
                      ),
                    ],
                  )
                : CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 16.0,
                          bottom: 16.0,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 24,
                            childAspectRatio: 0.85,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              _pagination.onItemVisible(index);
                              final item = items[index];
                              return FoodMenuItemCard(
                                id: item.id,
                                restaurantId: item.restaurantId,
                                title: item.title,
                                price: item.price,
                                currency: item.currency,
                                imagePath: item.imagePath,
                                restaurantName: item.restaurantName,
                                isFavorite:
                                    _localFavorites[item.id] ?? item.isFavorite,
                                displayPrice: item.displayPrice,
                                rating: item.rating,
                                reviewCount: item.reviewCount,
                                distanceKm: item.distanceKm,
                                estimatedTime: item.estimatedTime,
                                deliveryFee: item.deliveryFee,
                                originalDeliveryFee: item.originalDeliveryFee,
                                onFavoriteToggle: () => _toggleFavorite(item),
                                forceRestaurantNavigation: true,
                                isAvailable: item.isAvailable,
                                publishStatus: item.publishStatus,
                              );
                            },
                            childCount: items.length,
                          ),
                        ),
                      ),
                      if (_pagination.showFooter)
                        SliverToBoxAdapter(
                          child: PaginationListFooter(
                            isLoading: _pagination.isLoadingMore,
                            showEndMessage: !_pagination.hasMore,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
      ),
    );
  }
}
