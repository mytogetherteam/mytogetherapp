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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                  child: RefreshIndicator(
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
                            onNearbyTap: () => _openPage(
                              const RestaurantNearbyListPage(),
                            ),
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
                          FoodFeedSection(
                            feedType: 'explore',
                            title: context.tr('food.explore_menu'),
                            latitude: lat,
                            longitude: lon,
                          ),
                          _buildEndOfListMessage(),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
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
}
