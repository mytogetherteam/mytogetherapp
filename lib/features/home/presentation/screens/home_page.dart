import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/category_card.dart';
import '../widgets/together_deals_section.dart';
import '../widgets/todays_overview_section.dart';
import '../widgets/restaurants_nearby_section.dart';
import '../widgets/lost_items_nearby_section.dart';
import '../widgets/trending_news_section.dart';
import '../widgets/top_places_nearby_section.dart';
import '../widgets/popular_brands_section.dart';
import '../../../../core/utils/navigation_controller.dart';
import 'package:mytogetherapp/features/cart/presentation/widgets/styled_cart_fab.dart';
import 'package:mytogetherapp/features/notifications/data/repositories/notification_repository.dart';
import 'package:mytogetherapp/features/notifications/presentation/screens/notifications_page.dart';
import 'package:mytogetherapp/features/lost_and_found/presentation/screens/lost_and_found_page.dart';
import 'package:mytogetherapp/features/currency_exchange/presentation/screens/currency_exchange_page.dart';
import 'package:mytogetherapp/features/visa/presentation/screens/visa_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _bellAnimationController;
  late Animation<double> _bellScaleAnimation;

  late PageController _bannerController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  late PageController _promoController;
  Timer? _promoTimer;
  int _currentPromoIndex = 0;
  late ScrollController _scrollController;
  double _headerOpacity = 0.0;

  final List<String> _promotionImages = [
    'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?q=80&w=800&auto=format&fit=crop', // Food spread
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=800&auto=format&fit=crop', // Food spread promo
    'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?q=80&w=800&auto=format&fit=crop', // Pizza promo
    'https://images.unsplash.com/photo-1550547660-d9450f859349?q=80&w=800&auto=format&fit=crop', // Burger promo
  ];

  final List<String> _promoBannerImages = [
    'https://images.unsplash.com/photo-1599481238505-b8b0537a3f77?q=80&w=800&auto=format&fit=crop', // Chips promo
    'https://images.unsplash.com/photo-1566478433399-8474cb7bc140?q=80&w=800&auto=format&fit=crop', // Snacks/Coke
    'https://images.unsplash.com/photo-1621447509323-5705627f45b2?q=80&w=800&auto=format&fit=crop', // Korean snacks
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _bannerController = PageController(initialPage: 10000);
    _promoController = PageController(initialPage: 10000);
    
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

    _bellAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bellScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _bellAnimationController, curve: Curves.easeInOut));

    NotificationRepository().getUnreadCount();
    
    NotificationRepository().unreadCount.addListener(_onUnreadCountChanged);
  }

  void _onUnreadCountChanged() {
    if (NotificationRepository().unreadCount.value > 0) {
      _bellAnimationController.forward(from: 0.0);
    }
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
  void dispose() {
    _bannerTimer?.cancel();
    _promoTimer?.cancel();
    _bannerController.dispose();
    _promoController.dispose();
    _scrollController.dispose();
    NotificationRepository().unreadCount.removeListener(_onUnreadCountChanged);
    _bellAnimationController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, // Using dark for black text on light background
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
                    colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: 0.70), BlendMode.lighten),
                  ),
                ),
              ),
            ),
            
            // Scrollable Content
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Column(
                  children: [
                    SizedBox(height: MediaQuery.of(context).padding.top + 70), // Push content below fixed header
                    
                    // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(PhosphorIcons.magnifyingGlass(), color: Colors.grey.shade500, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Search food, restaurants & more ...',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
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
                            setState(() {
                              _currentBannerIndex = index % _promotionImages.length;
                            });
                          },
                          itemBuilder: (context, index) {
                            final realIndex = index % _promotionImages.length;
                            final image = _promotionImages[realIndex];
                            if (image.startsWith('assets/')) {
                              return Image.asset(image, fit: BoxFit.cover, width: double.infinity);
                            }
                            return Image.network(
                              image,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFFED3973),
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image, color: Colors.white),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dots Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_promotionImages.length, (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentBannerIndex == index ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentBannerIndex == index ? const Color(0xFFED3973) : const Color(0xFFFFC0CB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                    
                    const SizedBox(height: 10), // Added back small spacer for better rhythm
                    // Main White Section (Category Grid & Below)
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                            child: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.95,
                              children: [
                                      CategoryCard(
                                        title: 'Food &\nRestaurant',
                                        assetPath: 'assets/images/services/food_3d.png',
                                        onTap: () => NavigationController.instance.goToFoodTab(),
                                      ),
                                      CategoryCard(
                                        title: 'Lost &\nFound',
                                        assetPath: 'assets/images/services/lost_found_3d.png',
                                        badgeText: '4',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const LostAndFoundPage(),
                                          ),
                                        ),
                                      ),
                                      CategoryCard(
                                        title: 'Currency\nExchange',
                                        assetPath: 'assets/images/services/exchange_3d.png',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const CurrencyExchangePage(),
                                          ),
                                        ),
                                      ),
                                      CategoryCard(
                                        title: 'Visa',
                                        assetPath: 'assets/images/services/visa_3d.png',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const VisaPage(),
                                          ),
                                        ),
                                      ),
                                      CategoryCard(
                                        title: 'Places',
                                        assetPath: 'assets/images/services/places_3d.png',
                                      ),
                                      CategoryCard(
                                        title: 'Store',
                                        assetPath: 'assets/images/services/store_3d.png',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // Second Promo Banner Section (Below Categories)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 160,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFF0084FF), width: 2), // Blue border from screenshot
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(18),
                                          child: PageView.builder(
                                            controller: _promoController,
                                            onPageChanged: (index) {
                                              setState(() {
                                                _currentPromoIndex = index % _promoBannerImages.length;
                                              });
                                            },
                                            itemBuilder: (context, index) {
                                              final realIndex = index % _promoBannerImages.length;
                                              return Image.network(
                                                _promoBannerImages[realIndex],
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Dots Indicator for Second Banner
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(_promoBannerImages.length, (index) => AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          width: _currentPromoIndex == index ? 24 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _currentPromoIndex == index ? const Color(0xFFED3973) : const Color(0xFFD1D1D1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        )),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                const TogetherDealsSection(),
                                const RestaurantsNearbySection(),
                                const PopularBrandsSection(),
                                const SizedBox(height: 24),
                                const TodaysOverviewSection(),
                                const SizedBox(height: 24),
                                const LostItemsNearbySection(),
                                const SizedBox(height: 24),
                                const TopPlacesNearbySection(),
                                const SizedBox(height: 32),
                                const TrendingNewsSection(),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                    ],
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
                  boxShadow: _headerOpacity > 0.8 ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ] : [],
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
                        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 8),
                        // Top Row: Gift Icon, Logo, Notification Bell
                        child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Gift Icon (Top Left)
                        Image.asset(
                          'assets/images/gift.gif',
                          width: 34,
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                        // Logo (Center)
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/icon.png',
                              height: 32,
                              width: 32,
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFFED3973), Color(0xFFF96232)],
                                ).createShader(bounds),
                                child: Text(
                                  'MyTogether',
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
                        ValueListenableBuilder<int>(
                          valueListenable: NotificationRepository().unreadCount,
                          builder: (context, count, _) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const NotificationsPage(),
                                  ),
                                );
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      PhosphorIcons.bell(),
                                      size: 24,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Positioned(
                                    top: -2,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFED3973),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Text(
                                        count > 0 ? (count > 9 ? '9+' : count.toString()) : '4', // Mockup shows 4
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
        ),
      ),
    );
  }
}
