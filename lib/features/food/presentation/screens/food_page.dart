import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_feed_section.dart';
import 'package:mytogetherapp/features/auth/data/repositories/user_location_repository.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_header.dart';
import 'package:mytogetherapp/features/home/data/repositories/restaurant_repository.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_quick_access_section.dart';
import 'package:mytogetherapp/features/cart/presentation/widgets/styled_cart_fab.dart';
import 'package:mytogetherapp/features/cart/presentation/widgets/active_order_bar.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_restaurants_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/trending_shops_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/popular_brands_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/collections_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/explore_menu_section.dart';
import 'package:mytogetherapp/features/food/presentation/widgets/food_discount_selection_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_categories_section.dart';
import 'package:mytogetherapp/features/food/presentation/widgets/food_promotions_carousel.dart';
import 'package:mytogetherapp/features/home/presentation/screens/restaurant_nearby_list_page.dart';
import 'package:mytogetherapp/features/home/presentation/screens/food_collection_list_page.dart';
import 'package:mytogetherapp/features/home/presentation/screens/food_for_you_page.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/features/coupons/presentation/widgets/coupon_rail_section.dart';
import '../../../../core/presentation/widgets/search_box_trigger.dart';
import 'food_search_page.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_leaderboard_section.dart';

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  /// Toggle to show discount + collection rails between banner and restaurants.
  static const _showDiscountAndCollectionRails = false;

  Key _refreshKey = UniqueKey();
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    UserLocationRepository.instance.addListener(_onLocationChanged);
    UserLocationRepository.instance.getPrimaryLocation().then((_) {
      _loadCoordinates();
    });
  }

  @override
  void dispose() {
    UserLocationRepository.instance.removeListener(_onLocationChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  double _lat = LocationService.defaultLat;
  double _lon = LocationService.defaultLon;

  Future<void> _loadCoordinates() async {
    final coords =
        await UserLocationRepository.instance.resolveActiveCoordinates();
    if (!mounted) return;
    setState(() {
      _lat = coords.lat;
      _lon = coords.lon;
    });
  }

  /// Rebuild geo-scoped sections when the user picks a new delivery location.
  void _onLocationChanged() {
    _loadCoordinates();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final isScrolled = _scrollController.offset > 80;
    if (isScrolled != _isScrolled) {
      setState(() => _isScrolled = isScrolled);
    }

    final shouldShow = _scrollController.offset > 600;
    if (shouldShow != _showBackToTop) {
      setState(() => _showBackToTop = shouldShow);
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _onRefresh() async {
    RestaurantRepository.instance.clearCache();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _refreshKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = _lat;
    final lon = _lon;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final double statusBarHeight = isIOS ? MediaQuery.of(context).padding.top : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: const StyledCartFab(),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              child: CustomScrollView(
                key: _refreshKey,
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Image.asset(
                              'assets/images/food_header_bg.webp',
                              width: double.infinity,
                              height: (isIOS ? 260.0 : 240.0) + statusBarHeight,
                              fit: BoxFit.cover,
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: 24, bottom: isIOS ? 130 : 95),
                                child: Text(
                                  context.tr('food.banner_slogan'),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.3,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(0, 2),
                                        blurRadius: 8,
                                        color: Colors.black.withValues(alpha: 0.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, isIOS ? 56 : 32),
                              child: SearchBoxTrigger(
                                hintText: context.tr('food.deliver_prompt'),
                                height: 44,
                                borderRadius: 12,
                                backgroundColor: Colors.white.withValues(alpha: 0.85),
                                contentColor: Colors.grey[600]!,
                                shadowAlpha: 0.08,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const FoodSearchPage()),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const FoodCategoriesSection(),
                        const SizedBox(height: 16),
                        FoodQuickAccessSection(
                          onNearbyTap: () =>
                              _openPage(const RestaurantNearbyListPage()),
                          onForYouTap: () =>
                              _openPage(const FoodForYouPage()),
                          onTrendingTap: () => _openPage(
                            const FoodCollectionListPage(
                              kind: FoodCollectionKind.trending,
                            ),
                          ),
                          onPopularTap: () => _openPage(
                            const FoodCollectionListPage(
                              kind: FoodCollectionKind.popular,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const FoodLeaderboardSection(),
                        const SizedBox(height: 28),
                        const FoodPromotionsCarousel(),
                        CouponRailSection(
                          key: ValueKey('food_eb_coupons_$_refreshKey'),
                          title: context.tr('coupon.discounts_title'),
                          target: 'EARLY_BIRD',
                          topGap: 28,
                        ),
                        CouponRailSection(
                          key: ValueKey('food_coupons_$_refreshKey'),
                          title: context.tr('coupon.coupons_title'),
                          target: 'ALL',
                        ),
                        if (_showDiscountAndCollectionRails) ...[
                          const SizedBox(height: 28),
                          FoodDiscountSelectionSection(
                            key: ValueKey('discount_$_refreshKey'),
                          ),
                          const SizedBox(height: 32),
                          const CollectionsSection(),
                          const SizedBox(height: 32),
                        ] else
                          const SizedBox(height: 32),
                        const FoodRestaurantsSection(),
                        const TrendingShopsSection(),
                        PopularBrandsSection(
                          title: context.tr('food.popular'),
                        ),
                        const SizedBox(height: 24),
                        FoodFeedSection(
                          key: ValueKey('foryou_${lat}_$lon'),
                          feedType: 'for-you',
                          title: context.tr('food.for_you'),
                          latitude: lat,
                          longitude: lon,
                          layoutType: 2,
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                  ExploreMenuSection(
                    key: ValueKey('explore_${lat}_$lon'),
                    title: context.tr('food.explore_menu'),
                    latitude: lat,
                    longitude: lon,
                    scrollController: _scrollController,
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FoodHeader(
                isScrolled: _isScrolled,
                onLocationChanged: _onLocationChanged,
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(child: _buildBackToTopButton()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: const ActiveOrderBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackToTopButton() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      offset: _showBackToTop ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _showBackToTop ? 1 : 0,
        child: IgnorePointer(
          ignoring: !_showBackToTop,
          child: Material(
            color: Colors.white,
            elevation: 4,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _scrollToTop,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('common.back_to_top'),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
  }
}

