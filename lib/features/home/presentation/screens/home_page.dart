import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/category_card.dart';
import '../widgets/special_promotion_section.dart';
import '../widgets/todays_overview_section.dart';
import '../widgets/restaurants_nearby_section.dart';
import '../widgets/lost_items_nearby_section.dart';
import '../widgets/trending_news_section.dart';
import '../widgets/top_places_nearby_section.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/screens/login_page.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/features/cart/presentation/widgets/styled_cart_fab.dart';
import 'package:mytogetherapp/features/notifications/data/repositories/notification_repository.dart';
import 'package:mytogetherapp/features/notifications/presentation/screens/notifications_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  Key _refreshKey = UniqueKey();
  late AnimationController _bellAnimationController;
  late Animation<double> _bellScaleAnimation;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    NotificationRepository().unreadCount.removeListener(_onUnreadCountChanged);
    _bellAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _refreshKey = UniqueKey();
    });
    await NotificationRepository().getUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: const StyledCartFab(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/icon.png',
                    height: 40,
                    width: 40,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(PhosphorIcons.warning(), color: theme.colorScheme.error),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MyTogether',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(PhosphorIcons.magnifyingGlass(), size: 28, color: theme.iconTheme.color),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: NotificationRepository().unreadCount,
                    builder: (context, count, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          ScaleTransition(
                            scale: _bellScaleAnimation,
                            child: IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const NotificationsPage()),
                                ).then((_) => NotificationRepository().getUnreadCount());
                              },
                              icon: Icon(
                                PhosphorIcons.bell(), 
                                size: 28, 
                                color: theme.iconTheme.color
                              ),
                            ),
                          ),
                          if (count > 0)
                            Positioned(
                              top: 6,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFED3973),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                                ),
                                child: Text(
                                  count > 9 ? '9+' : count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      AppDialog.show(
                        context: context,
                        title: 'Logout',
                        content: 'Are you sure you want to log out?',
                        buttonText: 'Logout',
                        secondaryButtonText: 'Cancel',
                        onButtonPressed: () async {
                          Navigator.pop(context); // Close dialog
                          
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFED3973))),
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
                      radius: 14,
                      backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=5'),
                      backgroundColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.black.withValues(alpha: 0.05)),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: const Color(0xFFED3A72),
                child: SingleChildScrollView(
                  key: _refreshKey,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
                        child: Text(
                          'Category',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Category Grid
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.8, // Adjusted for better vertical fit with text
                          children: [
                            CategoryCard(
                              title: 'Food & Restaurant',
                              assetPath: 'assets/images/services/food.png',
                              onTap: () => NavigationController.instance.goToFoodTab(),
                            ),
                            CategoryCard(
                              title: 'Lost & \n Found',
                              assetPath: 'assets/images/services/lost-found.png',
                              badgeText: '9+',
                            ),
                            CategoryCard(
                              title: 'Currency Exchange',
                              assetPath: 'assets/images/services/exchange.png',
                            ),
                            CategoryCard(
                              title: 'Visa',
                              assetPath: 'assets/images/services/visa.png',
                            ),
                            CategoryCard(
                              title: 'Places',
                              assetPath: 'assets/images/services/places.png',
                            ),
                            CategoryCard(
                              title: 'Store',
                              assetPath: 'assets/images/services/store.png',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Special Promotion Section
                      const SpecialPromotionSection(),
                      const SizedBox(height: 24),
                      // Restaurants Nearby Section
                      const RestaurantsNearbySection(),
                      const SizedBox(height: 24),
                      // Today's Overview Section (Trending Near By)
                      const TodaysOverviewSection(),
                      const SizedBox(height: 24),
                      // Lost Items Nearby Section
                      const LostItemsNearbySection(),
                      const SizedBox(height: 24),
                      // Top Places Nearby Section
                      const TopPlacesNearbySection(),
                      const SizedBox(height: 32),
                      // Trending News Section
                      const TrendingNewsSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
