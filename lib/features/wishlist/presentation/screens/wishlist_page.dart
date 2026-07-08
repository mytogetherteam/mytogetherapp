import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/network/media_url.dart';
import 'package:mytogetherapp/core/presentation/utils/paginated_list_controller.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/pagination_list_footer.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/navigation_controller.dart';
import 'package:mytogetherapp/features/home/data/models/place_dto.dart';
import 'package:mytogetherapp/features/home/data/repositories/places_repository.dart';
import 'package:mytogetherapp/features/home/presentation/screens/place_detail_page.dart';
import 'package:mytogetherapp/features/home/presentation/screens/places_list_page.dart';
import 'package:mytogetherapp/features/home/presentation/screens/restaurant_detail_page.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_menu_item_card.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/place_card.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/restaurant_card.dart';

import '../../data/models/wishlist_item_dto.dart';
import '../../data/repositories/wishlist_repository.dart';

/// "Saved Items" — shows the current user's wishlist for menu items,
/// shops and places. Backed by /api/user/wishlist/*.
class WishlistPage extends StatefulWidget {
  /// Which tab to open initially (0 = menu items, 1 = restaurants, 2 = places).
  final int initialTab;

  const WishlistPage({super.key, this.initialTab = 0});

  /// Tab index constants used by callers (e.g. the "View saved" toast action).
  static const int tabMenuItems = 0;
  static const int tabRestaurants = 1;
  static const int tabPlaces = 2;

  /// Convenience navigator that opens the wishlist on a specific tab.
  static Future<void> open(BuildContext context, {int initialTab = 0}) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WishlistPage(initialTab: initialTab)),
    );
  }

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage>
    with TickerProviderStateMixin {
  static const int _pageSize = 20;

  late final TabController _tabController;
  final WishlistRepository _repo = WishlistRepository.instance;

  late final PaginatedListController<WishlistItemDto> _menuPagination;
  late final PaginatedListController<WishlistItemDto> _shopPagination;
  late final PaginatedListController<WishlistItemDto> _placePagination;

  final ScrollController _menuScrollController = ScrollController();
  final ScrollController _shopScrollController = ScrollController();
  final ScrollController _placeScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );

    _menuPagination = _createWishlistController(_repo.listMenuItems)
      ..addListener(_onPaginationChanged);
    _shopPagination = _createWishlistController(_repo.listShops)
      ..addListener(_onPaginationChanged);
    _placePagination = _createWishlistController(_repo.listPlaces)
      ..addListener(_onPaginationChanged);

    _menuPagination.attachScrollController(_menuScrollController);
    _shopPagination.attachScrollController(_shopScrollController);
    _placePagination.attachScrollController(_placeScrollController);

    _menuPagination.loadInitial();
    _shopPagination.loadInitial();
    _placePagination.loadInitial();
  }

  PaginatedListController<WishlistItemDto> _createWishlistController(
    Future<List<WishlistItemDto>> Function({int page, int size}) fetch,
  ) {
    return PaginatedListController<WishlistItemDto>(
      pageSize: _pageSize,
      initialPage: 1,
      itemKey: (item) => item.id,
      fetchPage: (page) async {
        final items = await fetch(page: page, size: _pageSize);
        return PaginatedPage(
          items: items,
          hasMore: items.length >= _pageSize,
        );
      },
    );
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _menuPagination
      ..removeListener(_onPaginationChanged)
      ..dispose();
    _shopPagination
      ..removeListener(_onPaginationChanged)
      ..dispose();
    _placePagination
      ..removeListener(_onPaginationChanged)
      ..dispose();
    _menuScrollController.dispose();
    _shopScrollController.dispose();
    _placeScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool get _loading =>
      _menuPagination.isInitialLoading &&
      _shopPagination.isInitialLoading &&
      _placePagination.isInitialLoading;

  Future<void> _refreshAll() async {
    await Future.wait([
      _menuPagination.refresh(),
      _shopPagination.refresh(),
      _placePagination.refresh(),
    ]);
  }

  Future<void> _removeItem(WishlistItemDto item) async {
    try {
      await _repo.removeById(item.id);
      if (!mounted) return;
      _menuPagination.items.removeWhere((it) => it.id == item.id);
      _shopPagination.items.removeWhere((it) => it.id == item.id);
      _placePagination.items.removeWhere((it) => it.id == item.id);
      setState(() {});
      AppDialog.showToast(context, context.tr('wishlist.removed'));
    } catch (_) {
      if (!mounted) return;
      AppDialog.showToast(
        context,
        context.tr('wishlist.remove_failed'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          context.tr('profile.saved_items'),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              text: context.trArgs(
                'wishlist.tab_menu',
                {'count': '${_menuPagination.items.length}'},
              ),
            ),
            Tab(
              text: context.trArgs(
                'wishlist.tab_shops',
                {'count': '${_shopPagination.items.length}'},
              ),
            ),
            Tab(
              text: context.trArgs(
                'wishlist.tab_places',
                {'count': '${_placePagination.items.length}'},
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMenuItemList(),
                _buildShopList(),
                _buildPlaceList(),
              ],
            ),
    );
  }

  Widget _buildMenuItemList() {
    final pagination = _menuPagination;
    if (!pagination.isInitialLoading && pagination.items.isEmpty) {
      return _buildEmpty(
        title: context.tr('wishlist.empty_title'),
        subtitle: context.tr('wishlist.empty_sub'),
        actionLabel: context.tr('wishlist.start_exploring'),
        onAction: _goToFoodTab,
        onRefresh: pagination.refresh,
      );
    }
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;
    final items = pagination.items;
    return RefreshIndicator(
      onRefresh: pagination.refresh,
      color: AppColors.primary,
      child: GridView.builder(
        controller: _menuScrollController,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
          childAspectRatio: 0.85,
        ),
        itemCount: items.length + (pagination.showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return PaginationListFooter(
              isLoading: pagination.isLoadingMore,
              showEndMessage: !pagination.hasMore,
            );
          }
          pagination.onItemVisible(index);
          final item = items[index];
          final menu = item.menuItem;
          final shopId = menu?.shopId ?? menu?.shop?.id;
          return FoodMenuItemCard(
            id: (menu?.id ?? item.menuItemId ?? 0).toString(),
            restaurantId: (shopId ?? 0).toString(),
            title: menu?.displayName ?? context.tr('wishlist.menu_item'),
            price: menu?.effectivePrice ?? 0,
            currency: '฿',
            imagePath: menu?.imageUrl ?? '',
            restaurantName: menu?.shop?.displayName ?? '',
            isFavorite: true,
            originalPrice:
                (menu?.hasDiscount ?? false) ? menu?.originalPrice : null,
            isAvailable: menu?.isAvailable ?? true,
            forceRestaurantNavigation: true,
            showFavoriteToast: false,
            selfManageFavorite: false,
            onFavoriteToggle: () => _removeItem(item),
          );
        },
      ),
    );
  }

  Widget _buildShopList() {
    final pagination = _shopPagination;
    if (!pagination.isInitialLoading && pagination.items.isEmpty) {
      return _buildEmpty(
        title: context.tr('wishlist.empty_shops_title'),
        subtitle: context.tr('wishlist.empty_shops_sub'),
        actionLabel: context.tr('wishlist.start_exploring'),
        onAction: _goToFoodTab,
        onRefresh: pagination.refresh,
      );
    }
    final items = pagination.items;
    return RefreshIndicator(
      onRefresh: pagination.refresh,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _shopScrollController,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        itemCount: items.length + (pagination.showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return PaginationListFooter(
              isLoading: pagination.isLoadingMore,
              showEndMessage: !pagination.hasMore,
            );
          }
          pagination.onItemVisible(index);
          final item = items[index];
          final shop = item.shop;
          return RestaurantCard(
            name: shop?.displayName ?? context.tr('common.shop'),
            category: '',
            rating: shop?.ratingAvg ?? 0,
            reviewCount: shop?.ratingCount ?? 0,
            distance: '',
            imagePath: shop?.bannerImageUrl ?? '',
            logoPath: shop?.logoUrl,
            isVerified: shop?.isVerified ?? false,
            isFavorite: true,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
            showFavoriteToast: false,
            selfManageFavorite: false,
            onFavoriteToggle: () => _removeItem(item),
            onTap: () {
              final shopId = shop?.id;
              if (shopId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RestaurantDetailPage(
                    id: shopId.toString(),
                    name: shop?.displayName,
                    logoPath: shop?.logoUrl,
                    imagePath: shop?.bannerImageUrl,
                    rating: shop?.ratingAvg,
                    reviewCount: shop?.ratingCount,
                    isFavorite: true,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceList() {
    final pagination = _placePagination;
    if (!pagination.isInitialLoading && pagination.items.isEmpty) {
      return _buildEmpty(
        title: context.tr('wishlist.empty_places_title'),
        subtitle: context.tr('wishlist.empty_places_sub'),
        actionLabel: context.tr('wishlist.start_exploring'),
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlacesListPage()),
        ),
        onRefresh: pagination.refresh,
      );
    }
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 3 : 2;
    final items = pagination.items;
    return RefreshIndicator(
      onRefresh: pagination.refresh,
      color: AppColors.primary,
      child: GridView.builder(
        controller: _placeScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: items.length + (pagination.showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return PaginationListFooter(
              isLoading: pagination.isLoadingMore,
              showEndMessage: !pagination.hasMore,
            );
          }
          pagination.onItemVisible(index);
          final item = items[index];
          final place = item.place;
          return PlaceCard(
            name: place?.displayName ?? context.tr('common.place'),
            category: place?.locationName ?? '',
            distance: '',
            imagePath: resolveMediaUrl(place?.coverUrl),
            isFavorite: true,
            selfManageFavorite: false,
            onFavoriteToggle: () => _removeItem(item),
            onTap: () => _openPlace(item),
          );
        },
      ),
    );
  }

  Future<void> _openPlace(WishlistItemDto item) async {
    final ref = item.place;
    final placeId = ref?.id ?? item.placeId;
    if (placeId == null) return;

    PlaceDto? place;
    try {
      place = await PlacesRepository.instance.fetchPlace(placeId);
    } catch (_) {
      place = null;
    }

    final resolved = place ??
        PlaceDto(
          id: placeId,
          titleEn: ref?.titleEn ?? ref?.displayName ?? '',
          titleMm: ref?.titleMm,
          titleTh: ref?.titleTh,
          locationName: ref?.locationName ?? '',
          coverUrl: ref?.coverUrl,
          photoGallery: const [],
          openingTime: '09:00',
          closingTime: '21:00',
          isFavorite: true,
        );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceDetailPage(place: resolved),
      ),
    );
  }

  Widget _buildEmpty({
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    Future<void> Function()? onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh ?? _refreshAll,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 24),
                    PrimaryGradientButton(
                      onPressed: onAction,
                      width: 220,
                      child: Text(
                        actionLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goToFoodTab() {
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
