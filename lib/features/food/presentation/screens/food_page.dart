import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_feed_section.dart';
import 'package:mytogetherapp/features/auth/data/repositories/user_location_repository.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_header.dart';
// import 'package:mytogetherapp/features/home/presentation/widgets/special_promotion_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_quick_access_section.dart';
import 'package:mytogetherapp/features/home/presentation/screens/all_restaurants_page.dart';
import 'package:mytogetherapp/features/cart/presentation/widgets/styled_cart_fab.dart';
import 'package:mytogetherapp/features/cart/presentation/widgets/active_order_bar.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_restaurants_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/trending_shops_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/popular_categories_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/collections_section.dart';

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  Key _refreshKey = UniqueKey();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    'for-you': GlobalKey(),
    'trending': GlobalKey(),
    'popular-dishes': GlobalKey(),
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(String sectionKey) {
    final key = _sectionKeys[sectionKey];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.1, // Near the top
      );
    }
  }

  Future<void> _onRefresh() async {
    // Small delay for better UX and to allow skeletons to show
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _refreshKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      physics: const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator to work on short lists
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          FoodQuickAccessSection(
                            onNearbyTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AllRestaurantsPage()),
                              );
                            },
                            onForYouTap: () => _scrollToSection('for-you'),
                            onTrendingTap: () => _scrollToSection('trending'),
                            onPopularTap: () => _scrollToSection('popular-dishes'),
                          ),
                          // Hiding special promotion for now
                          // const SpecialPromotionSection(),
                          const SizedBox(height: 20),
                          // ── New backend-powered rails ──────────────────────
                          const PopularCategoriesSection(),
                          const CollectionsSection(),
                          const TrendingShopsSection(),
                          // ── 5 live feed sections ───────────────────────────
                          const FoodRestaurantsSection(),
                          ..._buildFeedSections(),
                          _buildEndOfListMessage(),
                          const SizedBox(height: 80), // Space for ActiveOrderBar
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

  List<Widget> _buildFeedSections() {
    final activeLoc = UserLocationRepository.instance.activeLocation;
    final pos = LocationService().cachedPosition;
    
    final lat = activeLoc?.latitude ?? pos?.latitude ?? LocationService.defaultLat;
    final lon = activeLoc?.longitude ?? pos?.longitude ?? LocationService.defaultLon;

    const sections = [
      ('trending',       'Trending Near You', 1),
      ('right-now',      'Right Now', 1),
      ('popular-dishes', 'Popular Dishes', 1),
      ('hot-deals',      'Hot Deals', 1),
      ('for-you',        'For You Now', 2),
    ];

    return [
      for (final s in sections) ...[
        FoodFeedSection(
          key: _sectionKeys[s.$1],
          feedType: s.$1,
          title: s.$2,
          latitude: lat,
          longitude: lon,
          layoutType: s.$3,
        ),
      ],
    ];
  }

  Widget _buildEndOfListMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 20),
      child: Center(
        child: Text(
          "That's all for now!",
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
