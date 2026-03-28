import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../cart/data/cart_manager.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../cart/presentation/screens/order_summary_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/image_skeleton_loader.dart';
import '../widgets/shop_feed_section.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/restaurant_data.dart';
import '../../data/models/menu_item_dto.dart';
import '../../../../core/location/location_service.dart';
import 'restaurant_overview_page.dart';
import '../../../../app.dart';
import '../widgets/review_card.dart';
import '../../../reviews/data/models/review_model.dart';
import '../../../reviews/presentation/screens/rating_and_reviews_page.dart';

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
  bool _isTogglingFavorite = false;

  Restaurant? _currentRestaurant;

  // Track which feed sections have reported empty/error (by feedType key)
  final Set<String> _emptySections = {};
  static const _allFeedTypes = [
    'right-now', 'for-you', 'hot-deals', 'trending', 'popular-dishes'
  ];

  Map<String, dynamic>? _shopReviews;
  bool _isLoadingReviews = true;

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

    // Kick off parallel pre-fetch of all 5 feed sections right away
    if (shopId > 0) {
      RestaurantRepository.instance.prefetchShopFeeds(shopId);
    }

    _loadReviews();

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
  }

  Future<void> _loadReviews() async {
    final shopId = int.tryParse(widget.id) ?? 0;
    try {
      final reviews = await RestaurantRepository.instance.getShopReviews(shopId);
      if (mounted) {
        setState(() {
          _shopReviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    App.routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    App.routeObserver.unsubscribe(this);
    _scrollController.dispose();
    _basketAnimationController.dispose();
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
      final double offset = _scrollController.offset;
      final double topPadding = MediaQuery.of(context).padding.top;
      final double toolbarHeight = kToolbarHeight + topPadding;
      final double snapTarget = 420 - toolbarHeight;

      // Only perform snapping if we are close to the header area but not exactly at 0
      // We also disable snapping if targetMenuItemId is present to allow free scrolling to the top
      if (offset > 50 && offset < snapTarget && widget.targetMenuItemId == null) {
        // Only snap if we were not already in a programmatic scroll (best effort check)
        if (notification.dragDetails != null || offset > snapTarget * 0.2) {
          if (offset > snapTarget * 0.4) {
            Future.microtask(() {
              if (mounted) {
                _scrollController.animateTo(
                  snapTarget,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          } else {
            Future.microtask(() {
              if (mounted) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        }
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
            NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: CustomScrollView(
                controller: _scrollController,
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
                                  onTap: () {
                                    final shopId = int.tryParse(widget.id);
                                    if (shopId != null) {
                                      RestaurantRepository.instance.trackConversion(shopId, 'DIRECTIONS');
                                    }
                                  },
                                ),
                                _buildActionButton(
                                  imageAsset: 'assets/images/detail_reviews.png',
                                  label: 'Reviews',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RatingAndReviewsPage(
                                          shopId: int.tryParse(widget.id) ?? 0,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildActionButton(
                                  imageAsset: 'assets/images/detail_chat.png',
                                  label: 'Chat',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          const SizedBox(height: 30),
                          // ── 5 live feed sections ───────────────────────────
                          if (int.tryParse(widget.id) != null && int.parse(widget.id) > 0) ..._buildFeedSections(int.parse(widget.id)),
                          const SizedBox(height: 24),
                          _buildCustomerReviewsSection(),
                          const SizedBox(height: 120), // Bottom padding for cart summary
                        ],
                      ),
                    ),
                  ),
                ],
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
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _isScrolled ? 1.0 : 0.0,
                      child: Text(
                        _currentRestaurant?.name ?? '',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildCircleIconButton(
                      icon: PhosphorIcons.shareNetwork(),
                      onPressed: () {
                        final shopId = int.tryParse(widget.id);
                        if (shopId != null) {
                          RestaurantRepository.instance.trackConversion(shopId, 'SHARES');
                        }
                      },
                      isScrolled: _isScrolled,
                    ),
                    const SizedBox(width: 12),
                    _buildCircleIconButton(
                      icon: _isFavorite ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
                      onPressed: () async {
                        if (_isTogglingFavorite) return;
                        _isTogglingFavorite = true;
                        
                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                           await RestaurantRepository.instance.toggleShopFavorite(
                            int.tryParse(widget.id) ?? 0, 
                            _isFavorite,
                          );
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
                                backgroundColor: const Color(0xFFED3A72),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          // Rollback on error
                          if (mounted) {
                            setState(() => _isFavorite = !_isFavorite);
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text('Failed to update favorite. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          _isTogglingFavorite = false;
                        }
                      },
                      isScrolled: _isScrolled,
                      iconColorOverride: _isFavorite ? const Color(0xFFED3A72) : null,
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
                double cardTop = 305 - scrollOffset;
                
                // Calculate dynamic opacity (fade out as it moves up)
                // Start fading after 50px of scroll, fully gone by 250px
                double opacity = 1.0;
                if (scrollOffset > 50) {
                  opacity = (1.0 - (scrollOffset - 50) / 200).clamp(0.0, 1.0);
                }

                if (opacity <= 0) return const SizedBox.shrink();

                return Positioned(
                  top: cardTop,
                  left: 15,
                  right: 15,
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
                );
              },
            ),

            // Cart Summary Bar
            _buildCartSummary(),
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

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
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
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFED3A72), Color(0xFFF97316)],
                    ).createShader(bounds),
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
                      child: Material(
                        color: const Color(0xFFED3973),
                        borderRadius: BorderRadius.circular(18),
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
          ),
        );
      },
    );
  }

  Widget _buildLogoFallback(String name) {
    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFED3973),
            Color(0xFFF97316),
          ],
        ),
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFED3A72), // Primary Pink
                  Color(0xFFF97316), // Vibrant Orange
                ],
              ),
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
                      color: const Color(0xFFED3A72),
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

  Widget _buildCustomerReviewsSection() {
    if (_isLoadingReviews) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFED3A72)),
        ),
      );
    }

    final reviewsList = _shopReviews!['content'] as List? ?? _shopReviews!['items'] as List? ?? [];
    if (reviewsList.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalReviews = _shopReviews!['totalReviews']?.toString() ?? reviewsList.length.toString();
    final reviews = reviewsList.take(2).map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customer Reviews ($totalReviews)',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RatingAndReviewsPage(
                        shopId: int.tryParse(widget.id) ?? 0,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFED3973),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: reviews.asMap().entries.map((entry) {
              final index = entry.key;
              final review = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ReviewCard(
                  userName: review.userName.isNotEmpty ? review.userName : 'Anonymous',
                  userAvatar: review.userAvatar,
                  rating: review.rating,
                  comment: review.text,
                  tags: review.tags,
                  date: 'Dec 25, 2025', // We can format proper date or leave it for now since ReviewCard uses String
                  image: index == 0 ? (review.photoUrl.isNotEmpty ? review.photoUrl : null) : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeedSections(int shopId) {
    const sections = [
      ('right-now',      'Right Now',      Icons.access_time_filled_rounded),
      ('for-you',        'For You',        Icons.person_rounded),
      ('hot-deals',      'Hot Deals',      Icons.local_offer_rounded),
      ('trending',       'Trending',       Icons.trending_up_rounded),
      ('popular-dishes', 'Popular Dishes', Icons.star_rounded),
    ];

    // All 5 sections have loaded and every one is empty → show a single No Data card
    final allEmpty = _emptySections.length == _allFeedTypes.length &&
        _allFeedTypes.every((t) => _emptySections.contains(t));

    if (allEmpty) {
      return [_buildAllEmptyCard()];
    }

    return [
      for (int i = 0; i < sections.length; i++) ...[
        ShopFeedSection(
          shopId: shopId,
          feedType: sections[i].$1,
          title: sections[i].$2,
          titleIcon: sections[i].$3,
          showRestaurantName: true,
          targetMenuItemId: widget.targetMenuItemId,
          onEmpty: (isEmpty) {
            final changed = isEmpty
                ? _emptySections.add(sections[i].$1)
                : _emptySections.remove(sections[i].$1);
            if (changed && mounted) setState(() {});
          },
        ),
      ],
    ];
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
