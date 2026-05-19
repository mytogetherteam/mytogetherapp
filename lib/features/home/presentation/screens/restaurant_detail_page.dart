import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../cart/data/cart_manager.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../cart/presentation/screens/order_summary_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/image_skeleton_loader.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/restaurant_data.dart';
import '../../data/models/menu_item_dto.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/websocket_service.dart';
import 'restaurant_overview_page.dart';
import 'restaurant_reviews_page.dart';
import '../../../../app.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/food_menu_item_card.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../cart/data/active_order_state.dart';
import '../../../cart/presentation/widgets/active_order_bar.dart';

class RestaurantDetailPage extends StatefulWidget {
  final String id;
  final String? name;
  final String? category;
  final double? rating;
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

class _RestaurantDetailPageState extends State<RestaurantDetailPage> with SingleTickerProviderStateMixin, RouteAware {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _basketAnimationController;
  late Animation<Offset> _basketSlideAnimation;
  bool _showBasket = false;
  bool _isScrolled = false;
  bool _isFavorite = false;
  StreamSubscription? _menuUpdateSubscription;

  Restaurant? _currentRestaurant;

  // ── Pagination State ───────────────────────────────────────────────────
  final List<ShopFeedItemDto> _menuItems = [];
  int _menuPage = 0;
  bool _hasMoreMenu = true;
  bool _isMenuLoading = false;
  static const int _pageSize = 20;
  final Map<int, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Sync cart with backend to show correct basket bar
    CartManager.instance.syncWithApi();

    // Initialize basket animation
    _basketAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _basketSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start from below the screen
      end: Offset.zero,          // End at original position
    ).animate(CurvedAnimation(
      parent: _basketAnimationController,
      curve: Curves.easeOutBack,    // Floating and bounce effect
    ));

    // Seed UI immediately from constructor data
    _isFavorite = widget.isFavorite ?? false;
    _currentRestaurant = Restaurant(
      id: widget.id,
      name: widget.name ?? 'Loading...',
      category: widget.category ?? '',
      rating: widget.rating ?? 0.0,
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

    if (shopId > 0) {
      ActiveOrderState.instance.setCurrentShopId(shopId);
      _fetchMenu(isInitial: true);
    }

    // Also refresh the shop detail header (name, logo, rating etc.)
    Future(() async {
      try {
        final pos = LocationService().cachedPosition;
        final restaurant = await RestaurantRepository.instance.getShopById(
          shopId,
          lat: pos?.latitude ?? LocationService.defaultLat,
          lon: pos?.longitude ?? LocationService.defaultLon,
        );
        if (mounted) {
          setState(() {
            _currentRestaurant = restaurant;
            _isFavorite = restaurant.isFavorite;
          });
        }
      } catch (_) {}
    });

    // Listen for real-time menu updates
    _menuUpdateSubscription = WebSocketService().menuUpdates.listen((event) {
      final updatedShopId = event['shopId']?.toString();
      if (updatedShopId == widget.id && mounted) {
        debugPrint(' [RestaurantDetailPage] Real-time menu update detected. Refreshing menu...');
        _handleRefresh();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    App.routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  Future<void> _handleRefresh() async {
    final shopId = int.tryParse(widget.id);
    if (shopId != null) {
      debugPrint(' [RestaurantDetailPage] Manual refresh triggered.');
      
      setState(() {
        _menuItems.clear();
        _menuPage = 0;
        _hasMoreMenu = true;
      });
      _fetchMenu(isInitial: true);

      // Also re-fetch the shop detail itself
      final updatedRestaurant = await RestaurantRepository.instance.getShopById(shopId);
      if (mounted) {
        setState(() {
          _currentRestaurant = updatedRestaurant;
        });
      }
    }
  }

  Future<void> _fetchMenu({bool isInitial = false}) async {
    if (_isMenuLoading || (!_hasMoreMenu && !isInitial)) return;
    
    final shopId = int.tryParse(widget.id) ?? 0;
    if (shopId == 0) return;

    setState(() => _isMenuLoading = true);

    try {
      final result = await RestaurantRepository.instance.getShopMenu(
        shopId: shopId,
        page: isInitial ? 0 : _menuPage,
        size: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (isInitial) {
            _menuItems.clear();
            _menuPage = 0;
          }
          _menuItems.addAll(result.content);
          _hasMoreMenu = !result.last;
          if (_hasMoreMenu) _menuPage++;
          _isMenuLoading = false;
        });
      }
    } catch (e) {
      debugPrint(' [RestaurantDetailPage] Error fetching menu: $e');
      if (mounted) setState(() => _isMenuLoading = false);
    }
  }

  @override
  void dispose() {
    App.routeObserver.unsubscribe(this);
    _menuUpdateSubscription?.cancel();
    _scrollController.dispose();
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
    if (notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (metrics.pixels >= metrics.maxScrollExtent - 500) {
        _fetchMenu();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isScrolled ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
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
                      expandedHeight: 400,
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
                              (_currentRestaurant?.imagePath ?? '').trim().isEmpty
                                  ? Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                      ),
                                    )
                                  : Image.network(
                                      _currentRestaurant!.imagePath,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const ImageSkeletonLoader();
                                      },
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                              Container(
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
                            const SizedBox(height: 20), // Overlap space
                            // Action Buttons
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildActionButton(
                                    imageAsset: 'assets/images/detail_overview.png',
                                    label: 'Overview',
                                    onTap: () {
                                      if (_currentRestaurant != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RestaurantOverviewPage(
                                              restaurant: _currentRestaurant!,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  _buildActionButton(
                                    imageAsset: 'assets/images/detail_direction.png',
                                    label: 'Direction',
                                    isActive: true,
                                    onTap: () => AppDialog.showUnavailable(context),
                                  ),
                                  _buildActionButton(
                                    imageAsset: 'assets/images/detail_reviews.png',
                                    label: 'Reviews',
                                    onTap: () {
                                      if (_currentRestaurant != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RestaurantReviewsPage(
                                              shopId: int.parse(_currentRestaurant!.id),
                                              restaurantName: _currentRestaurant!.name,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  _buildActionButton(
                                    imageAsset: 'assets/images/detail_chat.png',
                                    label: 'Chat',
                                    onTap: () => AppDialog.showUnavailable(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                      sliver: _menuItems.isEmpty && !_isMenuLoading
                          ? SliverToBoxAdapter(child: _buildAllEmptyCard())
                          : SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 24,
                                childAspectRatio: 0.85,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final item = _menuItems[i];
                                  return FoodMenuItemCard(
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
                                    isHighlighted: item.id.toString() == widget.targetMenuItemId,
                                  );
                                },
                                childCount: _menuItems.length,
                              ),
                            ),
                    ),
                    if (_isMenuLoading)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CustomLoadingIndicator(
                              size: 30,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 140), // Bottom padding for cart summary
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
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                height: kToolbarHeight + MediaQuery.of(context).padding.top,
                decoration: BoxDecoration(
                  color: _isScrolled ? Colors.white : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: _isScrolled ? Colors.black.withValues(alpha: 0.05) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    _buildCircleIconButton(
                      icon: PhosphorIcons.arrowLeft(),
                      onPressed: () => Navigator.pop(context),
                      isScrolled: _isScrolled,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _isScrolled ? 1.0 : 0.0,
                        child: Text(
                          _currentRestaurant?.name ?? '',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCircleIconButton(
                      icon: PhosphorIcons.shareNetwork(),
                      onPressed: () => AppDialog.showUnavailable(context),
                      isScrolled: _isScrolled,
                    ),
                    const SizedBox(width: 12),
                    _buildCircleIconButton(
                      icon: _isFavorite ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
                      onPressed: () => AppDialog.showUnavailable(context),
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
                
                // Calculate dynamic position
                double cardTop = 300 - scrollOffset;
                
                // Calculate dynamic opacity (fade out as it moves up)
                double opacity = 1.0;
                if (scrollOffset > 50) {
                  opacity = (1.0 - (scrollOffset - 50) / 200).clamp(0.0, 1.0);
                }
                if (opacity <= 0) return const SizedBox.shrink();

                return Positioned(
                  top: cardTop,
                  left: 15,
                  right: 15,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ColorFilter.mode(
                            Colors.white.withValues(alpha: 0.7),
                            BlendMode.srcOver,
                          ),
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
                                // Logo Container
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: (_currentRestaurant?.logoPath ?? '').isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: _currentRestaurant!.logoPath,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const ImageSkeletonLoader(),
                                            errorWidget: (context, url, error) => _buildLogoFallback(_currentRestaurant?.name ?? ''),
                                          )
                                        : _buildLogoFallback(_currentRestaurant?.name ?? ''),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentRestaurant?.name ?? '',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            _currentRestaurant?.category ?? '',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          Text('  •  ', style: TextStyle(color: Colors.grey[500])),
                                          Text(
                                            '${_currentRestaurant?.rating ?? 0.0}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 4,
                                        children: [
                                          Icon(PhosphorIcons.car(), size: 16, color: Colors.grey[700]),
                                          Text(
                                            _currentRestaurant?.distance ?? '',
                                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                                          ),
                                          Text('  •  ', style: TextStyle(color: Colors.grey[500])),
                                          Icon(PhosphorIcons.clock(), size: 16, color: Colors.grey[700]),
                                          Text(
                                            _currentRestaurant?.deliveryTime ?? '',
                                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                                          ),
                                          Text('  •  ', style: TextStyle(color: Colors.grey[500])),
                                          Text(
                                            _currentRestaurant?.status ?? '',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: const Color(0xFF10B981),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
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
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEFEB),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                  child: Text(
                    'Add More Items — No Extra Delivery Fee.',
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
                          final storeIdx = CartManager.instance.stores.indexWhere((s) => s.name == storeName);
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
                              const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22),
                              const SizedBox(width: 12),
                              Text(
                                'Basket • $itemCount ${itemCount == 1 ? 'Item' : 'Items'}',
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
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
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
    final Color iconColor = iconColorOverride ?? (isScrolled ? Colors.black : Colors.white);
    final Color backgroundColor = isScrolled ? Colors.transparent : Colors.black.withValues(alpha: 0.3);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Gradient Border Circular Container
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: Container(
              margin: const EdgeInsets.all(1.5), // This creates the border thickness
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(8),
              child: imageAsset != null
                  ? Image.asset(
                      imageAsset,
                      fit: BoxFit.contain,
                    )
                  : Icon(
                      icon,
                      color: AppColors.primary,
                      size: 26,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937), // Darker gray for better readability
            ),
          ),
        ],
      ),
    );
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
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Added to favorites' : 'Removed from favorites'),
            backgroundColor: AppColors.primary,
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

  Widget _buildAllEmptyCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded, color: Colors.grey[200], size: 56),
            const SizedBox(height: 16),
            Text(
              'No food menu item available',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'This restaurant has no menu items right now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
