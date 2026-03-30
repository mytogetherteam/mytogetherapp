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
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/screens/login_page.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import 'package:mytogetherapp/features/cart/presentation/widgets/styled_cart_fab.dart';
import 'package:mytogetherapp/features/notifications/data/repositories/notification_repository.dart';
import 'package:mytogetherapp/features/notifications/presentation/screens/notifications_page.dart';
import 'package:mytogetherapp/features/lost_and_found/presentation/screens/lost_and_found_page.dart';
import 'package:mytogetherapp/features/currency_exchange/presentation/screens/currency_exchange_page.dart';
import 'package:mytogetherapp/features/visa/presentation/screens/visa_page.dart';
import 'package:mytogetherapp/features/home/presentation/screens/places_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _bellAnimationController;

  @override
  void initState() {
    super.initState();
    _bellAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    NotificationRepository().getUnreadCount();
    
    NotificationRepository().unreadCount.addListener(_onUnreadCountChanged);
  }

  void _onUnreadCountChanged() {
    if (NotificationRepository().unreadCount.value > 0) {
      _bellAnimationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    NotificationRepository().unreadCount.removeListener(_onUnreadCountChanged);
    _bellAnimationController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // Using light for white text on pink background
      child: Scaffold(
        backgroundColor: const Color(0xFFED3973), // Pink background from mockup
        floatingActionButton: const StyledCartFab(),
        body: Column(
          children: [
            // Pink Header Section
            Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: Stack(
                children: [
                  // Background logo patterns (wavy mockup style)
                  // Background logo patterns (wavy mockup style)
                  Positioned(
                    top: -200,
                    right: -73,
                    child: Transform.rotate(
                      angle: 0.01,
                      child: Opacity(
                        opacity: 1, // Balanced visibility
                        child: Image.asset(
                          'assets/images/logo_white.png',
                          width: 350,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -140,
                    left: -60,
                    child: Transform.rotate(
                      angle: 0.4,
                      child: Opacity(
                        opacity: 0.15,
                        child: Image.asset(
                          'assets/images/logo_white.png',
                          width: 420,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -20,
                    left: -140,
                    child: Transform.rotate(
                      angle: 0.8,
                      child: Opacity(
                        opacity: 0.12,
                        child: Image.asset(
                          'assets/images/logo_white.png',
                          width: 360,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.transparent, // Explicitly transparent to show stack background
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      bottom: 10,
                    ),
                    child: Column(
                      children: [
                        // Top Row: Logo, Brand Name, Icons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            children: [
                              // Logo
                              Image.asset(
                                'assets/images/icon.png',
                                height: 36,
                                width: 36,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'MyTogether',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Notification Bell
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
                                          padding: const EdgeInsets.all(4), // Slightly increased padding
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            PhosphorIcons.bell(),
                                            size: 25, // Increased size as requested
                                            color: Colors.black,
                                          ),
                                        ),
                                        Positioned(
                                          top: -3,
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
                              const SizedBox(width: 12),
                              // Profile Avatar
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    AppDialog.show(
                                      context: context,
                                      title: 'Logout',
                                      content: 'Are you sure you want to log out?',
                                      buttonText: 'Logout',
                                      secondaryButtonText: 'Cancel',
                                      onButtonPressed: () async {
                                        Navigator.pop(context); // Close dialog
                                        
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Center(child: CustomLoadingIndicator(size: 40)),
                                        );
                                        
                                        await AuthRepository.instance.logout();
                                        
                                        if (context.mounted) {
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(builder: (context) => const LoginPage()),
                                            (route) => false,
                                          );
                                        }
                                      },
                                    );
                                  },
                                  child: const CircleAvatar(
                                    radius: 16,
                                    backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=5'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Container(
                            height: 43,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(PhosphorIcons.magnifyingGlass(), color: Colors.grey.shade500, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Search food, restaurants & more',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10), // Added back small spacer for better rhythm
                    // Wrapper: dark pink bg so white section's rounded corners blend in
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBE2E5B),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: Column(
                        children: [
                          // 1. Delivery Info Bar
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            decoration: const BoxDecoration(
                              color: Color(0xFFBE2E5B),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                            ),
                            child: Row(
                              children: [
                                Icon(PhosphorIcons.bicycle(), color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Add more items — pay delivery once',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5), // Added spacing below delivery bar
                          // 2. Main White Section (Category Grid & Below)
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
                                    childAspectRatio: 0.85, // Taller to prevent text overflow on narrow devices
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
                                            builder: (context) => LostAndFoundPage(),
                                          ),
                                        ),
                                      ),
                                      CategoryCard(
                                        title: 'Currency\nExchange',
                                        assetPath: 'assets/images/services/exchange_3d.png',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CurrencyExchangePage(),
                                          ),
                                        ),
                                      ),
                                      CategoryCard(
                                        title: 'Visa',
                                        assetPath: 'assets/images/services/visa_3d.png',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => VisaPage(),
                                          ),
                                        ),
                                      ),
                                      CategoryCard(
                                        title: 'Places',
                                        assetPath: 'assets/images/services/places_3d.png',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PlacesListPage(),
                                          ),
                                        ),
                                      ),
                                      CategoryCard(
                                        title: 'Store',
                                        assetPath: 'assets/images/services/store_3d.png',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const TogetherDealsSection(),
                                const RestaurantsNearbySection(),
                                const SizedBox(height: 12),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
