import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../widgets/category_card.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/todays_overview_section.dart';
import '../widgets/restaurants_nearby_section.dart';
import '../widgets/lost_items_nearby_section.dart';
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
import 'package:mytogetherapp/features/announcements/data/repositories/announcement_repository.dart';
import 'package:mytogetherapp/features/food/presentation/screens/food_search_page.dart';
import 'package:mytogetherapp/features/lost_and_found/presentation/screens/lost_and_found_page.dart';
import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/auth_entry_page.dart';
import 'package:mytogetherapp/features/currency_exchange/presentation/screens/currency_exchange_page.dart';
import 'package:mytogetherapp/features/visa/presentation/screens/visa_page.dart';
import 'places_list_page.dart';
import 'package:mytogetherapp/features/jobs/presentation/screens/jobs_list_page.dart';
import 'package:mytogetherapp/features/cart/presentation/widgets/active_order_bar.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/features/coupons/presentation/widgets/coupon_rail_section.dart';
import '../../../../core/presentation/widgets/notification_bell.dart';
import '../widgets/trending_news_section.dart';
import '../widgets/social_for_you_section.dart';
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
  String? _bgImageUrl;
  String? _bgThemeName;
  int _refreshKey = 0;
  DateTime? _lastResumeRefreshAt;
  Timer? _titleTimer;
  bool _showThemeNameInAppBar = false;

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

    _titleTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (mounted && _bgThemeName != null && _bgThemeName!.trim().isNotEmpty) {
        setState(() {
          _showThemeNameInAppBar = !_showThemeNameInAppBar;
        });
      }
    });

    NotificationRepository().getUnreadCount();
    AnnouncementRepository().getUnreadCount();
    _fetchBanners();

    // Double-tap same bottom tab → scroll to top + refresh
    NavigationController.instance.tabScrollToTopRequest.addListener(
      _onScrollToTopRequested,
    );
  }

  void _onScrollToTopRequested() {
    if (NavigationController.instance.tabScrollToTopRequest.value != 0) return;
    if (!mounted) return;
    // Scroll to top with smooth animation
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
    // Refresh data
    RestaurantRepository.instance.clearCache();
    setState(() {
      _isLoadingBanners = true;
      _refreshKey++;
    });
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    try {
      final topBanners = await RestaurantRepository.instance.getBanners(
        position: 'Promotions',
      );
      final bottomBanners = await RestaurantRepository.instance.getBanners(
        position: 'Ads',
      );

      final bgThemeData = await RestaurantRepository.instance.getBackgroundTheme();

      if (mounted) {
        setState(() {
          _topBanners = topBanners;
          _bottomBanners = bottomBanners;
          if (bgThemeData != null) {
            _bgImageUrl = bgThemeData['url'];
            _bgThemeName = bgThemeData['name'];
          }
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
    // Refresh discount/nearby sections when the app resumes so admin changes
    // show up — but debounce: on web, tab visibility can fire resumed/inactive
    // in quick succession and was reloading every section repeatedly.
    if (state == AppLifecycleState.resumed && mounted) {
      final now = DateTime.now();
      if (_lastResumeRefreshAt != null &&
          now.difference(_lastResumeRefreshAt!) < const Duration(seconds: 30)) {
        return;
      }
      _lastResumeRefreshAt = now;
      RestaurantRepository.instance.clearCache();
      setState(() => _refreshKey++);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _promoTimer?.cancel();
    _titleTimer?.cancel();
    _bannerController.dispose();
    _promoController.dispose();
    _scrollController.dispose();
    NavigationController.instance.tabScrollToTopRequest.removeListener(
      _onScrollToTopRequested,
    );
    super.dispose();
  }

  void _showBannerModal(BannerImageDto banner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Image taking original aspect ratio with bottom fade overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: CachedNetworkImage(
                      imageUrl: _getImageUrl(banner.image),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          const ImageSkeletonLoader(showLogo: true),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        color: AppColors.primary,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Expanded area for the rest of the content (Title/Link)
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banner.nameMm ?? banner.nameEn ?? context.tr('home.promotions'),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if ((banner.descriptionMm ?? banner.descriptionEn) != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            banner.descriptionMm ?? banner.descriptionEn ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.6,
                            ),
                          ),
                        ],
                        // Link text removed per user request
                        const SizedBox(height: 16),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android
        statusBarBrightness: Brightness.light, // iOS
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // White background
        floatingActionButton: const StyledCartFab(),
        body: Stack(
          children: [
            // Fixed Header (Title & Background)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0, // Set to 100% height (full screen)
              child: Container(
                decoration: BoxDecoration(
                  image: (_bgImageUrl != null && _bgImageUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(_bgImageUrl!),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        )
                      : const DecorationImage(
                          image: AssetImage('assets/images/top-bannner.jpg'),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
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
                        height: MediaQuery.of(context).padding.top + 70,
                      ), // Push content below fixed header

                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: SearchBoxTrigger(
                          hintText: context.tr('home.search_hint'),
                          isGlassStyle: true,
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
                          height: MediaQuery.of(context).size.width > 600 ? 220 : 120,
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
                                  return GestureDetector(
                                    onTap: () => _showBannerModal(banner),
                                    child: Image.asset(
                                      image,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  );
                                }
                                return GestureDetector(
                                  onTap: () => _showBannerModal(banner),
                                  child: CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
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
                                gradient: _currentBannerIndex == index
                                    ? AppColors.primaryGradient
                                    : null,
                                color: _currentBannerIndex != index
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : null,
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
                                    ? 6
                                    : 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.95,
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
                                    onTap: () {
                                      if (GuestAuthGuard.isGuest) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AuthEntryPage(),
                                          ),
                                        );
                                        return;
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LostAndFoundPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  CategoryCard(
                                    title: context.tr('home.category_currency'),
                                    assetPath:
                                        'assets/images/services/exchange_3d.png',
                                    onTap: () {
                                      if (GuestAuthGuard.isGuest) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AuthEntryPage(),
                                          ),
                                        );
                                        return;
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const CurrencyExchangePage(),
                                        ),
                                      );
                                    },
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
                                    title: context.tr('home.category_jobs'),
                                    assetPath:
                                        'assets/images/services/jobs_3d.png',
                                    badgeText: 'NEW',
                                    isAnimatedBadge: true,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const JobsListPage(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Social discovery — under service buttons, not in the grid
                            const SocialForYouSection(),
                            const SizedBox(height: 12),
                            // Second Promo Banner Section (Below Categories)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    height: MediaQuery.of(context).size.width > 600 ? 280 : 150,
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
                                          final banner = _bottomBanners[realIndex];
                                          return GestureDetector(
                                            onTap: () => _showBannerModal(banner),
                                            child: CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                              imageUrl: _getImageUrl(banner.image),
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
                                            gradient: _currentPromoIndex == index
                                                ? AppColors.primaryGradient
                                                : null,
                                            color: _currentPromoIndex != index
                                                ? const Color(0xFFD1D1D1)
                                                : null,
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

                            CouponRailSection(
                              key: ValueKey('eb_coupons_$_refreshKey'),
                              title: context.tr('coupon.discounts_title'),
                              target: 'EARLY_BIRD',
                            ),
                            CouponRailSection(
                              key: ValueKey('coupons_$_refreshKey'),
                              title: context.tr('coupon.coupons_title'),
                              target: 'ALL',
                            ),
                            RestaurantsNearbySection(
                              key: ValueKey('nearby_$_refreshKey'),
                            ),
                            TopPlacesNearbySection(
                              key: ValueKey('places_$_refreshKey'),
                            ),
                            const SizedBox(height: 40), // Increased spacing
                            // PopularBrandsSection(
                            //   key: ValueKey('brands_$_refreshKey'),
                            // ),
                            TodaysOverviewSection(
                              key: ValueKey('overview_$_refreshKey'),
                            ),
                            const SizedBox(height: 24),
                            LostItemsNearbySection(
                              key: ValueKey('lost_$_refreshKey'),
                            ),
                            const SizedBox(height: 24),
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
                        child: Opacity(
                          opacity: _headerOpacity,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height,
                            child: Container(
                              decoration: BoxDecoration(
                                image: (_bgImageUrl != null && _bgImageUrl!.isNotEmpty)
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(_bgImageUrl!),
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                      )
                                    : const DecorationImage(
                                        image: AssetImage('assets/images/top-bannner.jpg'),
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                      ),
                              ),
                            ),
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
                                          AppColors.primaryGradient.createShader(bounds),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 800),
                                        transitionBuilder: (Widget child, Animation<double> animation) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0.0, 0.2),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Text(
                                          _showThemeNameInAppBar && _bgThemeName != null && _bgThemeName!.trim().isNotEmpty
                                              ? _bgThemeName!
                                              : context.tr('home.brand_name'),
                                          key: ValueKey<bool>(_showThemeNameInAppBar),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: (_showThemeNameInAppBar && _bgThemeName != null && _bgThemeName!.trim().isNotEmpty) ? 14 : 22,
                                            color: Colors.white,
                                          ),
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

