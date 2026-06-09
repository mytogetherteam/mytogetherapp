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
import 'package:mytogetherapp/features/home/presentation/widgets/together_deals_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/explore_menu_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/promo_banner_section.dart';
import 'package:mytogetherapp/features/home/presentation/screens/restaurant_nearby_list_page.dart';
import 'package:mytogetherapp/features/home/presentation/screens/food_collection_list_page.dart';
import 'package:mytogetherapp/features/home/presentation/screens/food_for_you_page.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  Key _refreshKey = UniqueKey();
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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
    final activeLoc = UserLocationRepository.instance.activeLocation;
    final pos = LocationService().cachedPosition;
    final lat =
        activeLoc?.latitude ?? pos?.latitude ?? LocationService.defaultLat;
    final lon =
        activeLoc?.longitude ?? pos?.longitude ?? LocationService.defaultLon;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: const StyledCartFab(),
        body: Stack(
          children: [
            Column(
              children: [
                FoodHeader(onLocationChanged: _onRefresh),
                Expanded(
                  child: Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: _onRefresh,
                        color: AppColors.primary,
                        child: SingleChildScrollView(
                          key: _refreshKey,
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            children: [
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
                          const SizedBox(height: 20),
                          const PromoBannerSection(position: 'Promotions'),
                          const SizedBox(height: 20),
                          const FoodRestaurantsSection(),
                              const TrendingShopsSection(),
                              PopularBrandsSection(
                                title: context.tr('food.popular'),
                              ),
                              const CollectionsSection(),
                              const SizedBox(height: 24),
                              FoodFeedSection(
                                feedType: 'for-you',
                                title: context.tr('food.for_you'),
                                latitude: lat,
                                longitude: lon,
                                layoutType: 2,
                              ),
                              const TogetherDealsSection(
                                useApiSectionTitle: true,
                              ),
                              ExploreMenuSection(
                                title: context.tr('food.explore_menu'),
                                latitude: lat,
                                longitude: lon,
                                scrollController: _scrollController,
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: Center(child: _buildBackToTopButton()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 4 + MediaQuery.of(context).padding.bottom,
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
      offset: _showBackToTop ? Offset.zero : const Offset(0, -2),
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
