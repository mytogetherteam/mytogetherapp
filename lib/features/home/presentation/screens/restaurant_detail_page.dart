import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:flutter/services.dart';
import '../../../cart/data/cart_manager.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../cart/presentation/screens/order_summary_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/image_skeleton_loader.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../../wishlist/data/repositories/wishlist_repository.dart';
import '../../../wishlist/presentation/screens/wishlist_page.dart';
import '../../data/restaurant_data.dart';
import '../../data/models/menu_item_dto.dart';
import '../../data/models/menu_category_dto.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import 'restaurant_overview_page.dart';
import 'restaurant_reviews_page.dart';
import '../../../coupons/presentation/widgets/shop_promotions_sheet.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../cart/data/coupon_service.dart';
import '../../../../app.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/food_menu_item_card.dart';
import '../widgets/order_unavailability_ui.dart';
import '../widgets/restaurant_open_status.dart';
import '../widgets/my_together_verified_badge.dart';
import '../../data/restaurant_order_availability.dart';
import '../../data/shop_order_state_cache.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../../../core/presentation/utils/pagination_scroll.dart';
import '../../../../core/presentation/widgets/pagination_list_footer.dart';
import '../../../cart/data/active_order_state.dart';
import '../../../cart/presentation/widgets/active_order_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/presentation/widgets/full_screen_image_viewer.dart';
import '../widgets/shop_myday_viewer.dart';
import '../widgets/shop_myday_list_section.dart';
import '../../../call/data/call_session.dart';
import '../../../call/presentation/screens/call_screen.dart';

class RestaurantDetailPage extends StatefulWidget {
  final String id;
  final String? name;
  final String? category;
  final double? rating;
  final int? reviewCount;
  final String? distance;
  final String? imagePath;
  final String? logoPath;
  final String? deliveryTime;
  final String? status;
  final double? latitude;
  final double? longitude;
  final List<MenuItemDto> popularDishes;
  final List<MenuItemDto> recommendations;
  final List<MenuItemDto> hotDeals;
  final String? targetMenuItemId;
  final bool? isFavorite;

  const RestaurantDetailPage({
    super.key,
    required this.id,
    this.name,
    this.category,
    this.rating,
    this.reviewCount,
    this.distance,
    this.imagePath,
    this.logoPath,
    this.deliveryTime,
    this.status,
    this.latitude,
    this.longitude,
    this.popularDishes = const [],
    this.recommendations = const [],
    this.hotDeals = const [],
    this.targetMenuItemId,
    this.isFavorite,
  });

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage>
    with TickerProviderStateMixin, RouteAware {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _basketAnimationController;
  late Animation<Offset> _basketSlideAnimation;
  late AnimationController _promoAnimationController;
  bool _showBasket = false;
  bool _isScrolled = false;
  bool _isFavorite = false;
  StreamSubscription? _menuUpdateSubscription;
  StreamSubscription? _shopProfileUpdateSubscription;
  late final VoidCallback _wsReconnectListener;
  bool _wsReady = false;
  Timer? _refreshDebounce;
  Timer? _hoursRefreshTimer;
  bool _hasShownUnavailableSheet = false;
  late final VoidCallback _orderStateListener;

  Restaurant? _currentRestaurant;

  // ── Pagination State ───────────────────────────────────────────────────
  final List<ShopFeedItemDto> _menuItems = [];
  // Shop menu categories (GET /api/user/menu-categories) used to group the menu
  // into ordered sections. Empty until loaded / for guests.
  List<MenuCategoryDto> _categories = [];
  /// Next 0-based page index per category when using per-category fetches.
  final Map<int, int> _categoryPage = {};
  final Map<int, bool> _categoryHasMore = {};
  int _shopWidePage = 0;
  bool _shopWideHasMore = true;
  bool _hasMoreMenu = true;
  bool _isMenuLoading = false;
  static const int _pageSize = 20;
  final Map<int, bool> _localFavorites = {};
  final GlobalKey _targetMenuKey = GlobalKey();
  int _promotionCount = 0;
  bool _hasScrolledToTarget = false;
  String? _targetMenuItemId;

  @override
  void initState() {
    super.initState();
    _targetMenuItemId = widget.targetMenuItemId;
    _scrollController.addListener(_onScroll);

    // Sync cart with backend to show correct basket bar
    CartManager.instance.syncWithApi();

    // Initialize basket animation
    _basketAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _basketSlideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 1), // Start from below the screen
          end: Offset.zero, // End at original position
        ).animate(
          CurvedAnimation(
            parent: _basketAnimationController,
            curve: Curves.easeOutBack, // Floating and bounce effect
          ),
        );

    _promoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // Seed UI immediately from constructor data
    _isFavorite = widget.isFavorite ?? false;
    _currentRestaurant = Restaurant(
      id: widget.id,
      name: widget.name ?? LocaleController.instance.tr('restaurant.loading'),
      category: widget.category ?? '',
      rating: widget.rating ?? 0.0,
      reviewCount: widget.reviewCount ?? 0,
      distance: widget.distance ?? '',
      imagePath: widget.imagePath ?? '',
      logoPath: widget.logoPath ?? '',
      deliveryTime: widget.deliveryTime ?? '',
      status: widget.status ?? '',
      latitude: widget.latitude,
      longitude: widget.longitude,
      isFavorite: _isFavorite,
    );

    final shopId = int.tryParse(widget.id) ?? 0;

    // Keep the favorite heart in sync with the global wishlist source of truth
    // so it always matches the cards/wishlist tab, regardless of where the
    // user last toggled it.
    WishlistRepository.instance.addListener(_onWishlistChanged);
    _primeFavoriteFromWishlist(shopId);

    if (shopId > 0) {
      ActiveOrderState.instance.setCurrentShopId(shopId);
      WebSocketService().connect();
      _fetchPromotionCount(shopId);
      _loadInitialMenu();
    }

    // Also refresh the shop detail header (name, logo, rating etc.)
    Future(() async {
      try {
        final coords =
            await UserLocationRepository.instance.resolveActiveCoordinates();
        final restaurant = await RestaurantRepository.instance.getShopById(
          shopId,
          lat: coords.lat,
          lon: coords.lon,
        );
        if (mounted) {
          setState(() {
            // Preserve the distance/delivery-time we were seeded with (from the
            // card the user tapped) when the freshly-fetched shop comes back
            // without a usable value, so the header doesn't regress to "0.0 km".
            final seededDistance = _currentRestaurant?.distance ?? '';
            final seededDeliveryTime = _currentRestaurant?.deliveryTime ?? '';
            _currentRestaurant = restaurant.copyWith(
              distance:
                  (restaurant.distance == '0.0 km' ||
                      restaurant.distance.isEmpty)
                  ? seededDistance
                  : restaurant.distance,
              deliveryTime:
                  (restaurant.deliveryTime == '20-30 mins' ||
                      restaurant.deliveryTime.isEmpty)
                  ? seededDeliveryTime
                  : restaurant.deliveryTime,
            );
            // The wishlist is the source of truth for the favorite heart. The
            // public shop-detail endpoint has no auth context and returns
            // isFavorite: false, so only trust it when the wishlist isn't primed.
            final repo = WishlistRepository.instance;
            _isFavorite = repo.isPrimed
                ? repo.isShopSaved(shopId)
                : restaurant.isFavorite;
          });
          _maybeShowUnavailableSheet();
        }
      } catch (_) {}
    });

    // Catch up after a dropped connection (e.g. mobile background).
    _wsReconnectListener = () {
      if (!mounted || !WebSocketService().connectionStatus.value) return;
      if (!_wsReady) {
        _wsReady = true;
        return;
      }
      debugPrint(
        ' [RestaurantDetailPage] WebSocket reconnected — refreshing menu...',
      );
      _scheduleRefresh(silent: true);
    };
    WebSocketService().connectionStatus.addListener(_wsReconnectListener);

    // Listen for real-time menu updates
    _menuUpdateSubscription = WebSocketService().menuUpdates.listen((event) {
      final updatedShopId = event['shopId']?.toString();
      if (updatedShopId == widget.id && mounted) {
        debugPrint(
          ' [RestaurantDetailPage] Real-time menu update detected. Refreshing menu...',
        );
        _scheduleRefresh(silent: true);
      }
    });

    // Listen for real-time shop-profile updates (open/closed, delivery state).
    _shopProfileUpdateSubscription = WebSocketService().shopProfileUpdates.listen((
      event,
    ) {
      final updatedShopId = event['shopId']?.toString();
      if (updatedShopId == widget.id && mounted) {
        debugPrint(
          ' [RestaurantDetailPage] Real-time shop-profile update detected. Refreshing header...',
        );
        setState(() {
          if (_currentRestaurant != null) {
            var updated = _currentRestaurant!;
            if (event.containsKey('deliveryEnabled')) {
              updated = updated.copyWith(
                deliveryEnabled: event['deliveryEnabled'] == true,
              );
            }
            if (event.containsKey('isOpen')) {
              updated = updated.copyWith(
                status: event['isOpen'] == true ? 'Open' : 'Closed',
              );
            }
            _currentRestaurant = updated;
            ShopOrderStateCache.instance.remember(updated);
          }
        });
        _scheduleRefresh(silent: true);
      }
    });

    ShopOrderStateCache.instance.ensureListening();
    _orderStateListener = () {
      if (!mounted || _currentRestaurant == null) return;
      final shopId = int.tryParse(widget.id);
      if (shopId == null) return;
      final availability =
          ShopOrderStateCache.instance.availabilityForShopIdOrDefault(
        shopId,
        deliveryEnabled: _currentRestaurant!.deliveryEnabled,
        operatingHours: _currentRestaurant!.operatingHours,
        status: _currentRestaurant!.status,
      );
      setState(() {
        _currentRestaurant = _currentRestaurant!.copyWith(
          deliveryEnabled: availability.deliveryEnabled,
          status: availability.statusFallback,
        );
      });
    };
    ShopOrderStateCache.instance.addListener(_orderStateListener);
    _hoursRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchPromotionCount(int shopId) async {
    if (!AuthService().isLoggedIn) return;
    try {
      final coupons = await CouponService.instance.fetchByShop(shopId);
      if (mounted) {
        setState(() => _promotionCount = coupons.length);
      }
    } catch (_) {}
  }

  void _maybeShowUnavailableSheet() {
    final restaurant = _currentRestaurant;
    if (restaurant == null || !mounted) return;
    final availability = RestaurantOrderAvailability.of(restaurant);
    OrderUnavailableBottomSheet.showIfNeeded(
      context,
      availability: availability,
      shopId: int.tryParse(widget.id),
      alreadyShown: () => _hasShownUnavailableSheet,
      markShown: () => _hasShownUnavailableSheet = true,
    );
  }

  RestaurantOrderAvailability? get _orderAvailability {
    final restaurant = _currentRestaurant;
    if (restaurant == null) return null;
    return RestaurantOrderAvailability.of(restaurant);
  }

  /// Coalesce bursty WS/reconnect events into a single refresh.
  void _scheduleRefresh({bool silent = false}) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted) _handleRefresh(silent: silent);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    App.routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  Future<void> _handleRefresh({bool silent = false}) async {
    final shopId = int.tryParse(widget.id);
    if (shopId != null) {
      debugPrint(' [RestaurantDetailPage] Manual refresh triggered. silent: $silent');

      if (!silent) {
        setState(() {
          _targetMenuItemId = null; // Clear deep-linked highlight
          _menuItems.clear();
          _categoryPage.clear();
          _categoryHasMore.clear();
          _shopWidePage = 0;
          _shopWideHasMore = true;
          _hasMoreMenu = true;
          // NOTE: intentionally do NOT reset `_hasScrolledToTarget` here.
          // The scroll-to-target is a one-time intent when the page is opened
          // deep-linked to a specific menu item. `_handleRefresh` also runs on
          // real-time WebSocket events (menu/shop-profile updates, reconnects),
          // so re-arming it would repeatedly yank the user back to the target.
        });
        _loadInitialMenu();
      } else {
        try {
          await _fetchCategories(shopId);
          await _fetchMenu(isInitial: true, silent: true);
        } catch (_) {}
      }

      // Also re-fetch the shop detail itself
      final coords =
          await UserLocationRepository.instance.resolveActiveCoordinates();
      final updatedRestaurant = await RestaurantRepository.instance.getShopById(
        shopId,
        lat: coords.lat,
        lon: coords.lon,
      );
      if (mounted) {
        setState(() {
          final oldDistance = _currentRestaurant?.distance ?? '';
          final oldDeliveryTime = _currentRestaurant?.deliveryTime ?? '';

          _currentRestaurant = updatedRestaurant.copyWith(
            distance:
                (updatedRestaurant.distance == '0.0 km' ||
                    updatedRestaurant.distance.isEmpty)
                ? oldDistance
                : updatedRestaurant.distance,
            deliveryTime:
                (updatedRestaurant.deliveryTime == '20-30 mins' ||
                    updatedRestaurant.deliveryTime.isEmpty)
                ? oldDeliveryTime
                : updatedRestaurant.deliveryTime,
          );
        });
      }
    }
  }

  Future<void> _fetchCategories(int shopId) async {
    try {
      final cats = await RestaurantRepository.instance.getMenuCategories(
        shopId: shopId,
      );
      if (mounted) {
        setState(() => _categories = cats);
      }
    } catch (e) {
      debugPrint(' [RestaurantDetailPage] Error fetching categories: $e');
    }
  }

  void _resetMenuPagination() {
    _categoryPage.clear();
    _categoryHasMore.clear();
    _shopWidePage = 0;
    _shopWideHasMore = true;
    _hasMoreMenu = true;
  }

  void _mergeMenuPage(
    SliceShopFeedItemDto result, {
    int? categoryId,
    required int fetchedPage,
  }) {
    final existingIds = _menuItems.map((e) => e.id).toSet();
    for (final item in result.content) {
      if (existingIds.add(item.id)) {
        _menuItems.add(item);
      } else {
        final index = _menuItems.indexWhere((e) => e.id == item.id);
        if (index != -1) {
          _menuItems[index] = item;
        }
      }
    }

    final hasMore = !result.last && result.content.isNotEmpty;
    if (categoryId != null) {
      _categoryHasMore[categoryId] = hasMore;
      _categoryPage[categoryId] = hasMore ? fetchedPage + 1 : fetchedPage;
    } else {
      _shopWideHasMore = hasMore;
      _shopWidePage = hasMore ? fetchedPage + 1 : fetchedPage;
    }
  }

  void _syncHasMoreMenu() {
    if (_categories.isNotEmpty) {
      _hasMoreMenu = _categoryHasMore.values.any((hasMore) => hasMore);
    } else {
      _hasMoreMenu = _shopWideHasMore;
    }
  }

  Future<void> _fetchCategoryMenuPages({required bool isInitial}) async {
    final shopId = int.tryParse(widget.id) ?? 0;
    if (shopId == 0) return;

    final requests = <Future<SliceShopFeedItemDto>>[];
    final categoryIds = <int>[];
    final pages = <int>[];

    for (final cat in _categories) {
      final hasMore = _categoryHasMore[cat.id] ?? true;
      if (!isInitial && !hasMore) continue;
      final page = isInitial ? 0 : (_categoryPage[cat.id] ?? 0);
      categoryIds.add(cat.id);
      pages.add(page);
      requests.add(
        RestaurantRepository.instance.getShopMenu(
          shopId: shopId,
          categoryId: cat.id,
          page: page,
          size: _pageSize,
        ),
      );
    }

    if (requests.isEmpty) {
      _syncHasMoreMenu();
      return;
    }

    final results = await Future.wait(requests);
    if (!mounted) return;

    setState(() {
      for (var i = 0; i < results.length; i++) {
        _mergeMenuPage(
          results[i],
          categoryId: categoryIds[i],
          fetchedPage: pages[i],
        );
      }
      _syncHasMoreMenu();
    });
  }

  Future<void> _fetchShopWideMenuPage({required bool isInitial}) async {
    final shopId = int.tryParse(widget.id) ?? 0;
    if (shopId == 0) return;

    final page = isInitial ? 0 : _shopWidePage;
    final result = await RestaurantRepository.instance.getShopMenu(
      shopId: shopId,
      page: page,
      size: _pageSize,
    );

    if (!mounted) return;
    setState(() {
      if (isInitial) {
        _menuItems.clear();
      }
      _mergeMenuPage(result, fetchedPage: page);
      _syncHasMoreMenu();
    });
  }

  /// Loads the first menu page, then keeps paging until [targetMenuItemId] is
  /// present (when set) so scroll + highlight can reach off-screen items.
  Future<void> _loadInitialMenu() async {
    final shopId = int.tryParse(widget.id) ?? 0;
    if (shopId > 0) {
      await _fetchCategories(shopId);
    }
    await _fetchMenu(isInitial: true);
    final targetId = widget.targetMenuItemId;
    if (targetId == null || targetId.isEmpty) return;

    int retries = 0;
    while (mounted &&
        _hasMoreMenu &&
        !_menuItems.any((it) => it.id.toString() == targetId) &&
        retries < 5) {
      final prevCount = _menuItems.length;
      await _fetchMenu();
      if (_menuItems.length == prevCount) {
        retries++;
      } else {
        retries = 0;
      }
    }

    if (mounted) _scheduleScrollToTarget();
  }

  void _scheduleScrollToTarget() {
    if (_hasScrolledToTarget || widget.targetMenuItemId == null) return;
    if (!_menuItems.any((it) => it.id.toString() == widget.targetMenuItemId)) {
      return;
    }

    _hasScrolledToTarget = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animateToTargetMenuItem();
    });
  }

  /// Positions the menu so the highlighted target item is on screen.
  ///
  /// The menu is rendered with lazily-built slivers, so an off-screen item's
  /// [GlobalKey] context doesn't exist yet — `Scrollable.ensureVisible` alone
  /// silently does nothing for items below the fold. To handle that we step the
  /// scroll position down (forcing those slivers to build) until the target's
  /// context becomes available, then settle it into place.
  ///
  /// Like Grab, this jumps instantly rather than animating: stepping is done
  /// with [ScrollController.jumpTo] and the final `ensureVisible` uses a zero
  /// duration, so the page appears already positioned at the item instead of
  /// visibly scrolling through everything above it.
  Future<void> _animateToTargetMenuItem() async {
    if (!_scrollController.hasClients) return;

    // Let the first batch of slivers lay out before measuring.
    await Future.delayed(const Duration(milliseconds: 250));

    const int maxSteps = 300;
    for (int step = 0; step < maxSteps; step++) {
      if (!mounted || !_scrollController.hasClients) return;

      final targetContext = _targetMenuKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: Duration.zero,
          alignment: 0.3,
        );
        return;
      }

      final position = _scrollController.position;
      final nextOffset = (position.pixels + 200.0)
          .clamp(0.0, position.maxScrollExtent);

      // Reached the end without the target building — nothing more we can do.
      if (nextOffset <= position.pixels) return;

      _scrollController.jumpTo(nextOffset);
      // Give the newly revealed slivers a frame to build.
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
    }
  }

  Future<void> _fetchMenu({bool isInitial = false, bool silent = false}) async {
    if (_isMenuLoading || (!_hasMoreMenu && !isInitial)) return;

    final shopId = int.tryParse(widget.id) ?? 0;
    if (shopId == 0) return;

    final wasNearEnd =
        !isInitial &&
        PaginationScroll.wasNearEnd(
          _scrollController,
          threshold: PaginationScroll.menuEndThreshold,
        );
    setState(() {
      if (!silent) _isMenuLoading = true;
      if (isInitial) {
        if (!silent) _menuItems.clear();
        _resetMenuPagination();
      }
    });
    if (!isInitial) {
      PaginationScroll.maintainAfterPageAppend(
        _scrollController,
        wasNearEnd: wasNearEnd,
      );
    }

    try {
      if (_categories.isNotEmpty) {
        await _fetchCategoryMenuPages(isInitial: isInitial);
      } else {
        await _fetchShopWideMenuPage(isInitial: isInitial);
      }
      if (mounted) {
        setState(() {
          if (!silent) _isMenuLoading = false;
        });
        if (!isInitial) {
          PaginationScroll.maintainAfterPageAppend(
            _scrollController,
            wasNearEnd: wasNearEnd,
          );
        }
      }
    } catch (e) {
      debugPrint(' [RestaurantDetailPage] Error fetching menu: $e');
      if (mounted) {
        setState(() {
          if (!silent) _isMenuLoading = false;
          _hasMoreMenu = false;
        });
        if (!isInitial) {
          PaginationScroll.maintainAfterPageAppend(
            _scrollController,
            wasNearEnd: wasNearEnd,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    App.routeObserver.unsubscribe(this);
    WishlistRepository.instance.removeListener(_onWishlistChanged);
    _menuUpdateSubscription?.cancel();
    _shopProfileUpdateSubscription?.cancel();
    _refreshDebounce?.cancel();
    _hoursRefreshTimer?.cancel();
    ShopOrderStateCache.instance.removeListener(_orderStateListener);
    WebSocketService().connectionStatus.removeListener(_wsReconnectListener);
    _scrollController.dispose();
    _basketAnimationController.dispose();
    _promoAnimationController.dispose();
    // Clear shop context
    ActiveOrderState.instance.setCurrentShopId(null);
    super.dispose();
  }

  @override
  void didPopNext() {
    // This is called when the top route has been popped off, and this route shows up.
    // Re-trigger basket animation if it's currently showing
    if (_showBasket) {
      _basketAnimationController.reset();
      _basketAnimationController.forward();
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final double offset = _scrollController.offset;
      // Precise threshold for white app bar to appear
      if (offset > 150) {
        if (!_isScrolled) {
          setState(() {
            _isScrolled = true;
          });
        }
      } else {
        if (_isScrolled) {
          setState(() {
            _isScrolled = false;
          });
        }
      }
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (metrics.pixels >=
          metrics.maxScrollExtent - PaginationScroll.menuEndThreshold) {
        _fetchMenu();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isScrolled
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppColors.primary,
              displacement: 80,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 320,
                      pinned: false,
                      stretch: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      flexibleSpace: FlexibleSpaceBar(
                        background: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(40),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              resolveMediaUrl(_currentRestaurant?.imagePath)
                                      .isEmpty
                                  ? Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: () {
                                        final img = resolveMediaUrl(_currentRestaurant!.imagePath);
                                        if (img.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              opaque: false,
                                              barrierDismissible: true,
                                              pageBuilder: (context, _, _) => FullScreenImageViewer(
                                                imageUrls: [img],
                                                initialIndex: 0,
                                                heroTagPrefix: 'restaurant_banner_${widget.id}_',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: CachedNetworkImage(
                                        imageUrl: resolveMediaUrl(
                                          _currentRestaurant!.imagePath,
                                        ),
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const ImageSkeletonLoader(),
                                        errorWidget:
                                            (context, url, error) =>
                                                Container(
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      size: 50,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                      ),
                                    ),
                              IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.5),
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.3),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10), // Overlap space
                            // Action Buttons
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildActionButton(
                                    imageAsset:
                                        'assets/images/detail_overview.png',
                                    label: context.tr('restaurant.overview'),
                                    onTap: () {
                                      if (_currentRestaurant != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                RestaurantOverviewPage(
                                                  restaurant:
                                                      _currentRestaurant!,
                                                ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  _buildActionButton(
                                    imageAsset:
                                        'assets/images/detail_direction.png',
                                    label: context.tr('home.direction'),
                                    isActive: true,
                                    onTap: () async {
                                      if (_currentRestaurant != null) {
                                        final lat =
                                            _currentRestaurant!.latitude;
                                        final lon =
                                            _currentRestaurant!.longitude;
                                        if (lat != null && lon != null) {
                                          final uri = Uri.parse(
                                            'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
                                          );
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          } else {
                                            if (context.mounted) {
                                              AppDialog.showUnavailable(
                                                context,
                                              );
                                            }
                                          }
                                        } else {
                                          if (context.mounted) {
                                            AppDialog.showUnavailable(context);
                                          }
                                        }
                                      }
                                    },
                                  ),
                                  _buildActionButton(
                                    imageAsset:
                                        'assets/images/detail_reviews.png',
                                    label: context.tr('restaurant.reviews'),
                                    onTap: () {
                                      if (_currentRestaurant != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                RestaurantReviewsPage(
                                              shopId: int.parse(
                                                _currentRestaurant!.id,
                                              ),
                                              restaurantName:
                                                  _currentRestaurant!.name,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  AnimatedBuilder(
                                    animation: _promoAnimationController,
                                    builder: (context, child) {
                                      return Opacity(
                                        opacity: (_orderAvailability?.isBlocked ?? false) ? 0.5 : 1.0,
                                        child: _buildActionButton(
                                          imageAsset: 'assets/images/detail_chat.png',
                                          label: context.tr('restaurant.chat'),
                                          badgeCount: _promotionCount,
                                          shineValue: _promoAnimationController.value,
                                          onTap: (_orderAvailability?.isBlocked ?? false)
                                              ? null
                                              : () {
                                                  final restaurant = _currentRestaurant;
                                                  final shopId = restaurant == null
                                                      ? null
                                                      : int.tryParse(restaurant.id);
                                                  if (restaurant == null || shopId == null) {
                                                    AppDialog.showUnavailable(context);
                                                    return;
                                                  }
                                                  ShopPromotionsSheet.show(
                                                    context,
                                                    shopId: shopId,
                                                    shopName: restaurant.name,
                                                  );
                                                },
                                        ),
                                      );
                                    }
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                    if (_currentRestaurant != null && _currentRestaurant!.hasActiveMyDays)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: ShopMyDayListSection(
                            shopName: _currentRestaurant!.name,
                            shopLogoUrl: _currentRestaurant!.logoPath,
                            stories: _currentRestaurant!.myDays,
                          ),
                        ),
                      ),
                    ..._buildMenuSlivers(context),
                    if (_isMenuLoading)
                      const SliverToBoxAdapter(
                        child: PaginationListFooter(
                          isLoading: true,
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 140,
                      ), // Bottom padding for cart summary
                    ),
                  ],
                ),
              ),
            ),

            // Custom App Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                height: kToolbarHeight + MediaQuery.of(context).padding.top,
                decoration: BoxDecoration(
                  color: _isScrolled ? Colors.white : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: _isScrolled
                          ? Colors.black.withValues(alpha: 0.05)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    _buildCircleIconButton(
                      icon: PhosphorIcons.arrowLeft,
                      onPressed: () => Navigator.pop(context),
                      isScrolled: _isScrolled,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _isScrolled ? 1.0 : 0.0,
                        child: VerifiedRestaurantNameRow(
                          name: _currentRestaurant?.name ?? '',
                          isVerified: _currentRestaurant?.isVerified ?? false,
                          badgeSize: MyTogetherVerifiedBadge.detailSize,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCircleIconButton(
                      icon: PhosphorIcons.shareNetwork,
                      onPressed: () => AppDialog.showUnavailable(context),
                      isScrolled: _isScrolled,
                    ),
                    const SizedBox(width: 12),
                    _buildCircleIconButton(
                      icon: _isFavorite
                          ? PhosphorIcons.heartFill
                          : PhosphorIcons.heart,
                      onPressed: _toggleShopFavorite,
                      isScrolled: _isScrolled,
                      iconColorOverride: _isFavorite ? AppColors.primary : null,
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),

            // Floating Info Card
            AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                double scrollOffset = 0;
                if (_scrollController.hasClients) {
                  scrollOffset = _scrollController.offset;
                }

                // Calculate dynamic position to keep consistent gap with SliverAppBar bottom
                double cardTop = 190 + MediaQuery.of(context).padding.top - scrollOffset;

                // Calculate dynamic opacity (fade out as it moves up)
                double opacity = 1.0;
                if (scrollOffset > 50) {
                  opacity = (1.0 - (scrollOffset - 50) / 200).clamp(0.0, 1.0);
                }
                if (opacity <= 0) return const SizedBox.shrink();

                final showStrip = _orderAvailability?.isBlocked ?? false;
                const stripBlockHeight = 44.0;
                final blockTop = showStrip
                    ? cardTop - stripBlockHeight - 6
                    : cardTop;

                return Positioned(
                  top: blockTop,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: opacity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showStrip && _orderAvailability != null)
                          RestaurantOrderStatusStrip(
                            message: _orderAvailability!
                                .statusStripText(context),
                            reason: _orderAvailability!.reason,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ColorFilter.mode(
                                Colors.white.withValues(alpha: 0.7),
                                BlendMode.srcOver,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  if (_currentRestaurant != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            RestaurantOverviewPage(
                                          restaurant: _currentRestaurant!,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                // Logo Container (MyDay story ring when active)
                                Builder(
                                  builder: (context) {
                                    final hasStories =
                                        _currentRestaurant?.hasActiveMyDays ==
                                            true;
                                    final logo = Padding(
                                      padding: EdgeInsets.all(hasStories ? 3 : 0),
                                      child: Container(
                                        width: hasStories ? 64 : 70,
                                        height: hasStories ? 64 : 70,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: resolveMediaUrl(
                                                    _currentRestaurant
                                                        ?.logoPath,
                                                  ).isNotEmpty
                                              ? CachedNetworkImage(
                                                  fadeInDuration:
                                                      Duration.zero,
                                                  fadeOutDuration:
                                                      Duration.zero,
                                                  imageUrl: resolveMediaUrl(
                                                    _currentRestaurant!
                                                        .logoPath,
                                                  ),
                                                  fit: BoxFit.cover,
                                                  placeholder:
                                                      (context, url) =>
                                                          const ImageSkeletonLoader(),
                                                  errorWidget: (
                                                    context,
                                                    url,
                                                    error,
                                                  ) =>
                                                      _buildLogoFallback(
                                                    _currentRestaurant
                                                            ?.name ??
                                                        '',
                                                  ),
                                                )
                                              : _buildLogoFallback(
                                                  _currentRestaurant?.name ??
                                                      '',
                                                ),
                                        ),
                                      ),
                                    );

                                    Widget child = logo;

                                      return GestureDetector(
                                        onTap: () {
                                          final restaurant = _currentRestaurant;
                                          if (restaurant == null) return;
                                          
                                          final img = resolveMediaUrl(
                                            restaurant.logoPath,
                                        );
                                        if (img.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              opaque: false,
                                              barrierDismissible: true,
                                              pageBuilder:
                                                  (context, _, _) =>
                                                      FullScreenImageViewer(
                                                imageUrls: [img],
                                                initialIndex: 0,
                                                heroTagPrefix:
                                                    'restaurant_logo_${widget.id}_',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: child,
                                    );
                                  },
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      VerifiedRestaurantNameRow(
                                        name: _currentRestaurant?.name ?? '',
                                        isVerified:
                                            _currentRestaurant?.isVerified ??
                                                false,
                                        badgeSize:
                                            MyTogetherVerifiedBadge.detailSize,
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            _currentRestaurant?.category ?? '',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          if (_currentRestaurant != null &&
                                              _currentRestaurant!.rating > 0 &&
                                              _currentRestaurant!.reviewCount >
                                                  0) ...[
                                            Text(
                                              '  •  ',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            Text(
                                              '${_currentRestaurant?.rating ?? 0.0}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.star_rounded,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 4,
                                        children: [
                                          Icon(
                                            PhosphorIcons.car,
                                            size: 16,
                                            color: Colors.grey[700],
                                          ),
                                          Text(
                                            _currentRestaurant?.distance ?? '',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          Text(
                                            '  •  ',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          Icon(
                                            PhosphorIcons.clock,
                                            size: 16,
                                            color: Colors.grey[700],
                                          ),
                                          Text(
                                            _currentRestaurant?.deliveryTime ??
                                                '',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          if (!(_orderAvailability?.isBlocked ??
                                              false)) ...[
                                            Text(
                                              '  •  ',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            Text(
                                              _currentRestaurant != null
                                                  ? RestaurantOpenStatus.of(
                                                      context,
                                                      _currentRestaurant!,
                                                    ).text
                                                  : context.localizedStatus(
                                                      _currentRestaurant?.status ??
                                                          '',
                                                    ),
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: _currentRestaurant != null
                                                    ? RestaurantOpenStatus.of(
                                                        context,
                                                        _currentRestaurant!,
                                                      ).color
                                                    : const Color(0xFF10B981),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                         ),
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
              );
            },
            ),

            // Active Order Bar & Cart Summary
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActiveOrderBar(shopId: int.tryParse(widget.id)),
                  _buildCartSummary(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary() {
    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, _) {
        final storeName = _currentRestaurant?.name ?? '';
        final itemCount = CartManager.instance.getStoreItemCount(storeName);
        final totalAmount = CartManager.instance.getStoreTotal(storeName);

        if (itemCount <= 0) {
          if (_showBasket) {
            _showBasket = false;
            _basketAnimationController.reverse();
          }
          return const SizedBox.shrink();
        }

        if (!_showBasket) {
          _showBasket = true;
          _basketAnimationController.forward();
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Promo Text with Pink Background (Static)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                decoration: const BoxDecoration(color: Color(0xFFFFEFEB)),
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: Text(
                    context.tr('restaurant.add_more_no_fee'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Basket Button Section (Animated)
              SlideTransition(
                position: _basketSlideAnimation,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: InkWell(
                        onTap: () {
                          final storeIdx = CartManager.instance.stores
                              .indexWhere((s) => s.name == storeName);
                          if (storeIdx != -1) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderSummaryPage(
                                  store: CartManager.instance.stores[storeIdx],
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          height: 57,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.shopping_cart_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                context.trArgs('restaurant.basket', {
                                  'count': '$itemCount',
                                  'items': itemCount == 1
                                      ? context.tr('restaurant.item')
                                      : context.tr('restaurant.items'),
                                }),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                totalAmount.toFormattedPrice(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogoFallback(String name) {
    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Center(
        child: Text(
          firstLetter,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isScrolled,
    Color? iconColorOverride,
  }) {
    final Color iconColor =
        iconColorOverride ?? (isScrolled ? Colors.black : Colors.white);
    final Color backgroundColor = isScrolled
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.3);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon, color: iconColor, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    String? imageAsset,
    required String label,
    bool isActive = false,
    VoidCallback? onTap,
    int badgeCount = 0,
    double shineValue = 0.0,
  }) {
    double badgeRotation = 0.0;
    // Bell ringing animation at the start of the loop (0 to 0.2)
    if (shineValue > 0.0 && shineValue < 0.2) {
      // 0.2 represents 500ms in a 2500ms duration.
      // A quick back-and-forth wiggling motion:
      badgeRotation = math.sin(shineValue * 5 * math.pi * 6) * 0.4;
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
            // Gradient Border Circular Container
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(
                      1.5,
                    ), // This creates the border thickness
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: imageAsset != null
                        ? Image.asset(imageAsset, fit: BoxFit.contain)
                        : Icon(icon, color: AppColors.primary, size: 26),
                  ),
                ),
                if (shineValue > 0)
                  Positioned.fill(
                    child: ClipOval(
                      child: FractionalTranslation(
                        translation: Offset(-1.5 + (3 * shineValue), 0),
                        child: Transform.rotate(
                          angle: 0.3,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.6),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: const [0.3, 0.5, 0.7],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              if (badgeCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Transform.rotate(
                    angle: badgeRotation,
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Center(
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(
                0xFF1F2937,
              ), // Darker gray for better readability
            ),
          ),
        ],
      ), // Column
    ); // GestureDetector
  }

  /// Ensures the global wishlist index is loaded, then reflects the saved
  /// state of this shop on the favorite heart.
  Future<void> _primeFavoriteFromWishlist(int shopId) async {
    if (shopId <= 0) return;
    final repo = WishlistRepository.instance;
    if (!repo.isPrimed) {
      await repo.loadAll();
    }
    if (!mounted) return;
    _onWishlistChanged();
  }

  /// Re-syncs `_isFavorite` from the wishlist whenever it changes anywhere in
  /// the app (cards, wishlist tab, other detail pages).
  void _onWishlistChanged() {
    final shopId = int.tryParse(widget.id) ?? 0;
    if (shopId <= 0 || !mounted) return;
    final repo = WishlistRepository.instance;
    if (!repo.isPrimed) return;
    final saved = repo.isShopSaved(shopId);
    if (saved != _isFavorite) {
      setState(() => _isFavorite = saved);
    }
  }

  /// Toggles the shop (restaurant) wishlist via `POST/DELETE /api/user/wishlist`.
  Future<void> _toggleShopFavorite() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;

    final shopId = int.tryParse(_currentRestaurant?.id ?? '');
    if (shopId == null) return;

    final newStatus = !_isFavorite;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isFavorite = newStatus);

    try {
      await RestaurantRepository.instance.toggleShopFavorite(shopId, newStatus);
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr(newStatus ? 'wishlist.saved' : 'wishlist.removed'),
          actionLabel:
              newStatus ? context.tr('wishlist.view_action') : null,
          onAction: newStatus
              ? () => WishlistPage.open(
                    context,
                    initialTab: WishlistPage.tabRestaurants,
                  )
              : null,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFavorite = !newStatus);
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr('common.favorite_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    } catch (e) {
      // Rollback on error
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

  /// Builds the menu region as a list of slivers, one labelled section per
  /// menu category (ordered by the categories endpoint), with the items of
  /// each category in a grid beneath its header.
  List<Widget> _buildMenuSlivers(BuildContext context) {
    if (_menuItems.isEmpty) {
      if (_isMenuLoading) return const [];
      return [
        SliverPadding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
          sliver: SliverToBoxAdapter(child: _buildAllEmptyCard()),
        ),
      ];
    }

    final groups = _buildCategoryGroups();
    final slivers = <Widget>[];

    if (_orderAvailability?.isBlocked ?? false) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _orderAvailability!.menuBrowseHint(context),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
    }

    for (final group in groups) {
      if (group.title != null && group.title!.isNotEmpty) {
        slivers.add(
          SliverToBoxAdapter(child: _buildCategoryHeader(group.title!)),
        );
      }
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
          sliver: _buildMenuGrid(group.items),
        ),
      );
    }
    return slivers;
  }

  /// Groups the loaded menu items into ordered category sections. Prefers the
  /// order from the categories endpoint; falls back to the category embedded on
  /// each item (e.g. for guests), and finally to a single unlabelled section.
  List<_MenuGroup> _buildCategoryGroups() {
    final byCategory = <int, List<ShopFeedItemDto>>{};
    final uncategorized = <ShopFeedItemDto>[];
    for (final item in _menuItems) {
      final cid = item.categoryId;
      if (cid != null) {
        byCategory.putIfAbsent(cid, () => []).add(item);
      } else {
        uncategorized.add(item);
      }
    }

    if (byCategory.isEmpty) {
      return [_MenuGroup(title: null, items: List.of(_menuItems))];
    }

    final groups = <_MenuGroup>[];

    if (_categories.isNotEmpty) {
      final sorted = [..._categories]
        ..sort((a, b) {
          final ao = a.displayOrder ?? 1 << 30;
          final bo = b.displayOrder ?? 1 << 30;
          if (ao != bo) return ao.compareTo(bo);
          return a.id.compareTo(b.id);
        });
      final used = <int>{};
      for (final cat in sorted) {
        final items = byCategory[cat.id];
        if (items == null || items.isEmpty) continue;
        used.add(cat.id);
        groups.add(_MenuGroup(title: cat.displayName, items: items));
      }
      // Items whose category isn't in the categories list (edge case).
      for (final entry in byCategory.entries) {
        if (used.contains(entry.key)) continue;
        groups.add(
          _MenuGroup(title: entry.value.first.categoryName, items: entry.value),
        );
      }
    } else {
      // Fallback: order by first appearance of each category.
      for (final entry in byCategory.entries) {
        groups.add(
          _MenuGroup(title: entry.value.first.categoryName, items: entry.value),
        );
      }
    }

    if (uncategorized.isNotEmpty) {
      groups.add(_MenuGroup(title: null, items: uncategorized));
    }
    return groups;
  }

  SliverGrid _buildMenuGrid(List<ShopFeedItemDto> items) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final item = items[i];
        final isTarget = item.id.toString() == _targetMenuItemId;
        final card = FoodMenuItemCard(
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
          showRestaurantName: false,
          rating: item.rating,
          reviewCount: item.reviewCount,
          distanceKm: item.distanceKm,
          estimatedTime: item.estimatedTime,
          deliveryFee: item.deliveryFee,
          originalDeliveryFee: item.originalDeliveryFee,
          onFavoriteToggle: () => _toggleFavorite(item),
          isAvailable: item.isAvailable,
          publishStatus: item.publishStatus,
          orderAvailability: _orderAvailability,
          isHighlighted: isTarget,
        );
        return isTarget ? Container(key: _targetMenuKey, child: card) : card;
      }, childCount: items.length),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllEmptyCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              color: Colors.grey[200],
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('restaurant.no_menu'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('restaurant.no_menu_sub'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single menu category section: a [title] header (null = no header) and the
/// items that belong to it.
class _MenuGroup {
  final String? title;
  final List<ShopFeedItemDto> items;

  _MenuGroup({required this.title, required this.items});
}

