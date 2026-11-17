import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../main_navigation/presentation/screens/main_navigation_screen.dart';
import '../../../home/presentation/screens/restaurant_detail_page.dart';
import '../../../home/presentation/screens/restaurant_nearby_list_page.dart';
import '../../../home/presentation/screens/today_overview_detail_page.dart';
import '../../../home/presentation/widgets/restaurant_card.dart';
import '../../../home/presentation/widgets/food_menu_item_card.dart';
import '../../../home/presentation/widgets/view_all_icon_button.dart';
import '../../../home/presentation/widgets/image_skeleton_loader.dart';
import '../../../home/data/restaurant_data.dart';
import '../../../home/data/models/trending_item_dto.dart';
import '../../../home/data/repositories/restaurant_repository.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../data/active_order_state.dart';
import '../../../../app.dart';
import '../../../../core/utils/file_url_util.dart';

class OrderCancelPage extends StatefulWidget {
  static bool isCurrentlyVisible = false;

  final String orderId;
  final String? reason;
  final String? shopId;
  final String? shopName;
  final String? shopNameMm;
  final String? shopNameTh;
  final String? shopLogo;
  final String? shopImageUrl;
  /// When true, shows the user-initiated cancellation copy.
  final bool cancelledByUser;
  /// When true, shows system-initiated cancellation copy.
  final bool cancelledBySystem;

  const OrderCancelPage({
    super.key,
    required this.orderId,
    this.reason,
    this.shopId,
    this.shopName,
    this.shopNameMm,
    this.shopNameTh,
    this.shopLogo,
    this.shopImageUrl,
    this.cancelledByUser = false,
    this.cancelledBySystem = false,
  });

  @override
  State<OrderCancelPage> createState() => _OrderCancelPageState();
}

class _OrderCancelPageState extends State<OrderCancelPage> {
  List<Restaurant> _nearbyShops = [];
  List<TrendingItemDto> _trendingItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    OrderCancelPage.isCurrentlyVisible = true;
    _loadAlternativeSuggestions();
  }

  @override
  void dispose() {
    OrderCancelPage.isCurrentlyVisible = false;
    super.dispose();
  }

  String _getFullUrl(String? path) => FileUrlUtil.resolve(path);

  NavigatorState get _rootNavigator =>
      App.navigatorKey.currentState ?? Navigator.of(context);

  bool get _isSystemCancelled {
    if (widget.cancelledByUser) return false;
    if (widget.cancelledBySystem) return true;
    final r = widget.reason?.toLowerCase() ?? '';
    return r.contains('system') ||
        r.contains('auto') ||
        r.contains('timeout') ||
        r.contains('expire') ||
        r.contains('no driver') ||
        r.contains('not accepted') ||
        r.contains('unaccepted') ||
        r.contains('no response') ||
        r.contains('စနစ်');
  }

  String get _titleText {
    if (widget.cancelledByUser) {
      return context.tr('order_cancel_user.title');
    }
    if (_isSystemCancelled) {
      return context.tr('order_cancel_system.title');
    }
    return context.localized(
      en: 'Order Cancelled',
      mm: 'အော်ဒါ ပယ်ဖျက်လိုက်ပါသည်',
      th: 'คำสั่งซื้อถูกยกเลิก',
    );
  }

  String get _subtitleText {
    if (widget.cancelledByUser) {
      return context.tr('order_cancel_user.message');
    }
    if (_isSystemCancelled) {
      return context.tr('order_cancel_system.message');
    }
    return context.tr('order_cancel.message');
  }

  Future<void> _loadAlternativeSuggestions() async {
    try {
      final coords =
          await UserLocationRepository.instance.resolveActiveCoordinates();

      final shopsFuture = RestaurantRepository.instance
          .getNearbyShops(
            lat: coords.lat,
            lon: coords.lon,
            radius: 6.0,
            size: 15,
            deliveryOnly: true,
          )
          .timeout(const Duration(seconds: 8), onTimeout: () => []);

      final trendingFuture = RestaurantRepository.instance
          .getTrendingItems(
            lat: coords.lat,
            lon: coords.lon,
            radiusKm: 10.0,
            size: 12,
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => TrendingSectionDto(
              title: '',
              description: '',
              items: const [],
              totalCount: 0,
            ),
          );

      final results = await Future.wait([shopsFuture, trendingFuture]);
      final shops = results[0] as List<Restaurant>;
      final trending = results[1] as TrendingSectionDto;

      if (mounted) {
        setState(() {
          _nearbyShops =
              shops.where((s) => s.id != widget.shopId).toList();
          _trendingItems = trending.items
              .where((i) =>
                  widget.shopId == null ||
                  i.shopId.toString() != widget.shopId)
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onViewRestaurant(BuildContext context) {
    ActiveOrderState.instance.clearOrder(orderId: widget.orderId);
    NavigationController.instance.goToFoodTab();

    if (widget.shopId != null && widget.shopId!.isNotEmpty) {
      _rootNavigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RestaurantDetailPage(
            id: widget.shopId!,
            name: widget.shopName,
            logoPath: _getFullUrl(widget.shopLogo),
            imagePath: _getFullUrl(widget.shopImageUrl),
          ),
        ),
        (route) => route.isFirst,
      );
    } else {
      _exitToFoodTab(context);
    }
  }

  void _exitToFoodTab(BuildContext context) {
    ActiveOrderState.instance.clearOrder(orderId: widget.orderId);
    final nav = App.navigatorKey.currentState ??
        Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    } else {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationController.instance.goToFoodTab();
    });
  }

  void _exitToHome(BuildContext context) {
    ActiveOrderState.instance.clearOrder(orderId: widget.orderId);
    final nav = App.navigatorKey.currentState ??
        Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    } else {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = widget.shopLogo != null && widget.shopLogo!.isNotEmpty;
    final hasImage =
        widget.shopImageUrl != null && widget.shopImageUrl!.isNotEmpty;
    final localizedShopName = context.localized(
      en: widget.shopName,
      mm: widget.shopNameMm,
      th: widget.shopNameTh,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitToFoodTab(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 54,
          leading: Center(
            child: Container(
              margin: const EdgeInsets.only(left: 16),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => _exitToFoodTab(context),
                  customBorder: const CircleBorder(),
                  child: const Center(
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Clean, Spacious Top Status Header with far_delivery_baby
                _buildHeroHeader(
                  context,
                  localizedShopName,
                  hasLogo,
                  hasImage,
                ),

                const SizedBox(height: 12),

                // 2. Nearby Alternative Restaurants Section (No emojis in title)
                _buildNearbyRestaurantsSection(context),

                const SizedBox(height: 8),

                // 3. Recommended Food Items Nearby Section (No emojis in title, compact gap)
                _buildRecommendedFoodSection(context),

                SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. Clean Hero Header (Aesthetic with far_delivery_baby)
  // -------------------------------------------------------------
  Widget _buildHeroHeader(
    BuildContext context,
    String localizedShopName,
    bool hasLogo,
    bool hasImage,
  ) {
    final hasShopInfo = localizedShopName.isNotEmpty;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          // Cancelled Store Sleek Pill Link (Placed ABOVE character image)
          if (hasShopInfo || hasLogo || hasImage) ...[
            InkWell(
              onTap: () => _onViewRestaurant(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child: (widget.shopLogo != null &&
                                widget.shopLogo!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: _getFullUrl(widget.shopLogo),
                                fit: BoxFit.cover,
                                errorWidget: (ctx, url, error) => const Icon(
                                  PhosphorIconsFill.storefront,
                                  color: Colors.grey,
                                  size: 14,
                                ),
                              )
                            : (widget.shopImageUrl != null &&
                                    widget.shopImageUrl!.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: _getFullUrl(widget.shopImageUrl),
                                    fit: BoxFit.cover,
                                    errorWidget: (ctx, url, error) =>
                                        const Icon(
                                      PhosphorIconsFill.storefront,
                                      color: Colors.grey,
                                      size: 14,
                                    ),
                                  )
                                : const Icon(
                                    PhosphorIconsFill.storefront,
                                    color: Colors.grey,
                                    size: 14,
                                  ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        localizedShopName,
                        style: AppFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      PhosphorIcons.caretRightBold,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Baby Delivery Character Illustration (Enlarged size)
          Image.asset(
            'assets/images/far_delivery_baby.png',
            width: 155,
            height: 155,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            _titleText,
            style: AppFonts.poppins(
              fontSize: 19.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Subtext
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _subtitleText,
              style: AppFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Cancellation Reason Capsule (if reason exists)
          if (!widget.cancelledByUser &&
              widget.reason != null &&
              widget.reason!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFE4E6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsFill.info,
                    color: Color(0xFFE11D48),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${context.tr('order_cancel.reason_title')}: ${widget.reason!.trim()}',
                      style: AppFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFBE123C),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 2. Nearby Restaurants Section (No emojis in title)
  // -------------------------------------------------------------
  Widget _buildNearbyRestaurantsSection(BuildContext context) {
    if (!_isLoading && _nearbyShops.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.localized(
                  en: 'Nearby Restaurants',
                  mm: 'အနီးအနားရှိ စားသောက်ဆိုင်များ',
                  th: 'ร้านอาหารใกล้เคียง',
                ),
                style: AppFonts.poppins(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              ViewAllIconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RestaurantNearbyListPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (_isLoading)
          _buildRestaurantSkeletons()
        else
          SizedBox(
            height: 244,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _nearbyShops.length,
              itemBuilder: (context, index) {
                final data = _nearbyShops[index];
                return RestaurantCard(
                  name: data.name,
                  category: data.category,
                  rating: data.rating,
                  reviewCount: data.reviewCount,
                  distance: data.distance,
                  imagePath: data.imagePath,
                  logoPath: data.logoPath,
                  deliveryTime: data.deliveryTime,
                  deliveryFee: data.deliveryFee,
                  originalDeliveryFee: data.originalDeliveryFee,
                  deliveryEnabled: data.deliveryEnabled,
                  operatingHours: data.operatingHours,
                  status: data.status,
                  shopId: data.id,
                  isVerified: data.isVerified,
                  isFavorite: data.isFavorite,
                  compact: true,
                  width: 240,
                  margin: const EdgeInsets.only(right: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailPage(
                          id: data.id,
                          name: data.name,
                          logoPath: data.logoPath,
                          imagePath: data.imagePath,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 3. Recommended Food Items Section (No emojis in title, compact gap)
  // -------------------------------------------------------------
  Widget _buildRecommendedFoodSection(BuildContext context) {
    if (!_isLoading && _trendingItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.localized(
                  en: 'Popular Dishes Nearby',
                  mm: 'လူကြိုက်များသော ဟင်းလျာများ',
                  th: 'เมนูยอดนิยมใกล้เคียง',
                ),
                style: AppFonts.poppins(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              ViewAllIconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TodayOverviewDetailPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (_isLoading)
          _buildFoodSkeletons()
        else
          SizedBox(
            height: 244,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _trendingItems.length,
              itemBuilder: (context, index) {
                final item = _trendingItems[index];
                return Container(
                  width: 175,
                  margin: const EdgeInsets.only(right: 14),
                  child: FoodMenuItemCard(
                    id: item.id.toString(),
                    restaurantId: item.shopId.toString(),
                    title: item.name,
                    price: item.price,
                    currency: item.currency,
                    imagePath: item.imageUrl,
                    restaurantName: item.shopName,
                    isFavorite: item.isFavorite,
                    rating: item.rating,
                    reviewCount: item.reviewCount,
                    distanceKm: item.distanceKm,
                    estimatedTime: item.estimatedTime,
                    deliveryFee: item.deliveryFee,
                    originalDeliveryFee: item.originalDeliveryFee,
                    originalPrice: item.originalPrice,
                    displayPrice: item.displayPrice,
                    forceRestaurantNavigation: true,
                    isAvailable: item.isAvailable,
                    publishStatus: item.publishStatus,
                    deliveryEnabled: item.deliveryEnabled,
                    operatingHours: item.operatingHours,
                    restaurantStatus: item.restaurantStatus,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 4. Skeleton Loaders
  // -------------------------------------------------------------
  Widget _buildRestaurantSkeletons() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) => Container(
          width: 240,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: ImageSkeletonLoader(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 90,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodSkeletons() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) => Container(
          width: 175,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: ImageSkeletonLoader(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 110,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 70,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
