import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../widgets/category_card.dart';
import '../widgets/home_discount_section.dart';
import '../widgets/todays_overview_section.dart';
import '../widgets/restaurants_nearby_section.dart';
import '../widgets/lost_items_nearby_section.dart';
import '../widgets/trending_news_section.dart';
import '../widgets/top_places_nearby_section.dart';
import '../widgets/popular_brands_section.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../data/models/banner_image_dto.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/image_skeleton_loader.dart';
import '../../data/repositories/restaurant_repository.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/features/cart/presentation/widgets/styled_cart_fab.dart';
import 'package:mytogetherapp/features/notifications/data/repositories/notification_repository.dart';
import 'package:mytogetherapp/features/notifications/presentation/screens/notifications_page.dart';
import 'package:mytogetherapp/features/announcements/data/repositories/announcement_repository.dart';
import 'package:mytogetherapp/features/food/presentation/screens/food_search_page.dart';
import 'package:mytogetherapp/features/lost_and_found/presentation/screens/lost_and_found_page.dart';
import 'package:mytogetherapp/features/lost_and_found/data/repositories/item_post_repository.dart';
import 'package:mytogetherapp/features/currency_exchange/presentation/screens/currency_exchange_page.dart';
import 'package:mytogetherapp/features/visa/presentation/screens/visa_page.dart';
import 'places_list_page.dart';
import 'package:mytogetherapp/features/cart/presentation/widgets/active_order_bar.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../../../core/presentation/widgets/notification_bell.dart';
import '../../../../core/presentation/widgets/search_box_trigger.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late PageController _bannerController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  late PageController _promoController;
  Timer? _promoTimer;
  int _currentPromoIndex = 0;
  late ScrollController _scrollController;
  double _headerOpacity = 0.0;

  List<BannerImageDto> _topBanners = [];
  List<BannerImageDto> _bottomBanners = [];
  bool _isLoadingBanners = true;
  int _refreshKey = 0;
  int _lostFoundCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController()..addListener(_onScroll);
    _bannerController = PageController(initialPage: 10000);
    _promoController = PageController(initialPage: 10000);

    // Forcefully remove splash screen after 3 seconds to prevent getting stuck
    Future.delayed(const Duration(seconds: 3), () {
      FlutterNativeSplash.remove();
    });

    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_bannerController.hasClients) {
        _bannerController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });

    _promoTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_promoController.hasClients) {
        _promoController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });

    NotificationRepository().getUnreadCount();
    AnnouncementRepository().getUnreadCount();
    _fetchBanners();
    _fetchLostFoundCount();
  }

  Future<void> _fetchLostFoundCount() async {
    try {
      final feed = await ItemPostRepository.instance.fetchFeed(size: 1);
      if (mounted) {
        setState(() => _lostFoundCount = feed.totalElements);
      }
    } catch (_) {
      // Leave count at 0 (badge hidden) on failure.
    }
  }

  Future<void> _fetchBanners() async {
    try {
      final topBanners = await RestaurantRepository.instance.getBanners(
        position: 'Promotions',
      );
      final bottomBanners = await RestaurantRepository.instance.getBanners(
        position: 'Ads',
      );

      if (mounted) {
        setState(() {
          _topBanners = topBanners;
          _bottomBanners = bottomBanners;
          _isLoadingBanners = false;
        });

        // After setting state, precache the first image of each to ensure they are ready
        // then remove splash
        _removeSplashAfterImagesLoaded();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBanners = false;
        });
        FlutterNativeSplash.remove(); // Remove even on error
      }
    }
  }

  Future<void> _removeSplashAfterImagesLoaded() async {
    try {
      final List<Future> precacheTasks = [];

      if (_topBanners.isNotEmpty) {
        final firstTop = _topBanners.first.image;
        if (!firstTop.startsWith('assets/')) {
          precacheTasks.add(
            precacheImage(
              CachedNetworkImageProvider(_getImageUrl(firstTop)),
              context,
            ),
          );
        }
      }

      if (_bottomBanners.isNotEmpty) {
        final firstBottom = _bottomBanners.first.image;
        if (!firstBottom.startsWith('assets/')) {
          precacheTasks.add(
            precacheImage(
              CachedNetworkImageProvider(_getImageUrl(firstBottom)),
              context,
            ),
          );
        }
      }

      // Wait for at most 2 seconds for images to load, then remove splash anyway
      await Future.wait(
        precacheTasks,
      ).timeout(const Duration(seconds: 2), onTimeout: () => []);
    } catch (_) {
      // Ignore errors in precaching
    } finally {
      FlutterNativeSplash.remove();
    }
  }

  String _getImageUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  void _onScroll() {
    final double offset = _scrollController.offset;
    final double newOpacity = (offset / 80).clamp(0.0, 1.0);
    if (newOpacity != _headerOpacity) {
      setState(() {
        _headerOpacity = newOpacity;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh the discount config + carousel when the app resumes, so admin
    // changes (which invalidate the server cache immediately) show up.
    if (state == AppLifecycleState.resumed && mounted) {
      RestaurantRepository.instance.clearCache();
      setState(() => _refreshKey++);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _promoTimer?.cancel();
    _bannerController.dispose();
    _promoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle
          .dark, // Using dark for black text on light background
      child: Scaffold(
        backgroundColor: Colors.white, // White background
        floatingActionButton: const StyledCartFab(),
        body: Stack(
          children: [
            // Fixed Background Image
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0, // Set to 100% height (full screen)
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const AssetImage('assets/images/top-bannner.jpg'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withValues(alpha: 0.70),
                      BlendMode.lighten,
                    ),
                  ),
                ),
              ),
            ),

            // Scrollable Content
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: () async {
                  RestaurantRepository.instance.clearCache();
                  setState(() {
                    _isLoadingBanners = true;
                    _refreshKey++;
                  });
                  await _fetchBanners();
                  await _fetchLostFoundCount();
                },
                color: AppColors.primary,
                displacement: MediaQuery.of(context).padding.top + 60,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).padding.top + (Theme.of(context).platform == TargetPlatform.iOS ? 16 : 42),
                      ), // Push content below fixed header
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: SearchBoxTrigger(
                          hintText: context.tr('home.search_hint'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FoodSearchPage(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Banner Carousel
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: PageView.builder(
                              controller: _bannerController,
                              onPageChanged: (index) {
                                if (_topBanners.isEmpty) return;
                                setState(() {
                                  _currentBannerIndex =
                                      index % _topBanners.length;
                                });
                              },
                              itemBuilder: (context, index) {
                                if (_isLoadingBanners) {
                                  return const ImageSkeletonLoader(
                                    showLogo: true,
                                  );
                                }
                                if (_topBanners.isEmpty) {
                                  return Container(
                                    color: Colors.grey.shade100,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                final realIndex = index % _topBanners.length;
                                final banner = _topBanners[realIndex];
                                final image = banner.image;
                                if (image.startsWith('assets/')) {
                                  return Image.asset(
                                    image,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  );
                                }
                                return CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                  imageUrl: _getImageUrl(image),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const ImageSkeletonLoader(showLogo: true),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: AppColors.primary,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.white,
                                        ),
                                      ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Dots Indicator
                      if (!_isLoadingBanners && _topBanners.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _topBanners.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentBannerIndex == index ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentBannerIndex == index
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(
                        height: 10,
                      ), // Added back small spacer for better rhythm
                      // Main White Section (Category Grid & Below)
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                              child: GridView.count(
                                padding: const EdgeInsets.only(top: 16),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount:
                                    MediaQuery.of(context).size.width > 600
                                    ? 5
                                    : 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.85,
                                children: [
                                  CategoryCard(
                                    title: context.tr('home.category_food'),
                                    assetPath:
                                        'assets/images/services/food_3d.png',
                                    onTap: () => NavigationController.instance
                                        .goToFoodTab(),
                                  ),
                                  CategoryCard(
                                    title: context.tr('home.category_lost_found'),
                                    assetPath:
                                        'assets/images/services/lost_found_3d.png',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LostAndFoundPage(),
                                      ),
                                    ),
                                  ),
                                  CategoryCard(
                                    title: context.tr('home.category_currency'),
                                    assetPath:
                                        'assets/images/services/exchange_3d.png',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CurrencyExchangePage(),
                                      ),
                                    ),
                                  ),
                                  CategoryCard(
                                    title: context.tr('home.category_visa'),
                                    assetPath:
                                        'assets/images/services/visa_3d.png',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const VisaPage(),
                                      ),
                                    ),
                                  ),
                                  CategoryCard(
                                    title: context.tr('home.category_places'),
                                    assetPath:
                                        'assets/images/services/places_3d.png',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const PlacesListPage(),
                                      ),
                                    ),
                                  ),
                                  CategoryCard(
                                    title: context.tr('home.category_store'),
                                    assetPath:
                                        'assets/images/services/store_3d.png',
                                    isComingSoon: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Second Promo Banner Section (Below Categories)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    height: 200,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: PageView.builder(
                                        controller: _promoController,
                                        onPageChanged: (index) {
                                          if (_bottomBanners.isEmpty) return;
                                          setState(() {
                                            _currentPromoIndex =
                                                index % _bottomBanners.length;
                                          });
                                        },
                                        itemBuilder: (context, index) {
                                          if (_isLoadingBanners) {
                                            return const ImageSkeletonLoader(
                                              showLogo: true,
                                            );
                                          }
                                          if (_bottomBanners.isEmpty) {
                                            return Container(
                                              color: Colors.grey.shade100,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey,
                                              ),
                                            );
                                          }
                                          final realIndex =
                                              index % _bottomBanners.length;
                                          return CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                            imageUrl: _getImageUrl(
                                              _bottomBanners[realIndex].image,
                                            ),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            placeholder: (context, url) =>
                                                const ImageSkeletonLoader(
                                                  showLogo: true,
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                                      color: AppColors.primary,
                                                      alignment:
                                                          Alignment.center,
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Dots Indicator for Second Banner
                                  if (!_isLoadingBanners &&
                                      _bottomBanners.isNotEmpty)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        _bottomBanners.length,
                                        (index) => AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          width: _currentPromoIndex == index
                                              ? 24
                                              : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _currentPromoIndex == index
                                                ? AppColors.primary
                                                : const Color(0xFFD1D1D1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            HomeDiscountSection(
                              key: ValueKey('discount_$_refreshKey'),
                            ),
                            RestaurantsNearbySection(
                              key: ValueKey('nearby_$_refreshKey'),
                            ),
                            PopularBrandsSection(
                              key: ValueKey('brands_$_refreshKey'),
                            ),
                            const SizedBox(height: 24),
                            TodaysOverviewSection(
                              key: ValueKey('overview_$_refreshKey'),
                            ),
                            const SizedBox(height: 24),
                            LostItemsNearbySection(
                              key: ValueKey('lost_$_refreshKey'),
                            ),
                            const SizedBox(height: 24),
                            TopPlacesNearbySection(
                              key: ValueKey('places_$_refreshKey'),
                            ),
                            const SizedBox(height: 32),
                            TrendingNewsSection(
                              key: ValueKey('news_$_refreshKey'),
                            ),
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                context.tr('food.end_of_list'),
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                decoration: BoxDecoration(
                  boxShadow: _headerOpacity > 0.8
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          child: Image.asset(
                            'assets/images/top-bannner.jpg',
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            color: Colors.white.withValues(alpha: 0.70),
                            colorBlendMode: BlendMode.lighten,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 2,
                          bottom: 6,
                        ),
                        // Top Row: Gift Icon, Logo, Notification Bell
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // App Icon (Top Left)
                              Image.asset(
                                'assets/images/app_icon_small.png',
                                width: 34,
                                height: 34,
                              ),
                              // Logo (Center)
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: ShaderMask(
                                      shaderCallback: (bounds) =>
                                          LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              const Color(0xFFF96232),
                                            ],
                                          ).createShader(bounds),
                                      child: Text(
                                        context.tr('home.brand_name'),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 22,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Notification Bell (Top Right)
                              const NotificationBell(hasShadow: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Active Order Bar (Floating at bottom, home page only)
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
}

