import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../../../features/home/presentation/screens/home_page.dart';
import '../../../../features/food/presentation/screens/food_page.dart';
import '../../../../features/order/presentation/screens/order_history_page.dart';
import '../../../../features/news/presentation/screens/news_page.dart';
import '../../../../features/cart/presentation/widgets/styled_cart_fab.dart';
import '../../../../features/cart/data/active_order_state.dart';
import '../../../../features/cart/presentation/screens/order_complete_page.dart';
import '../../../../features/cart/presentation/screens/order_cancel_page.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../features/auth/presentation/screens/profile_page.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int? _lastStatus;
  final Set<String> _notifiedCancelledOrders = {};

  final List<Widget> _screens = const [
    HomePage(),
    FoodPage(),
    OrderHistoryPage(),
    // NewsPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    NavigationController.instance.tabChangeRequest.addListener(
      _onTabChangeRequested,
    );

    // Global listener for order completion
    _lastStatus = ActiveOrderState.instance.orderStatus;
    ActiveOrderState.instance.addListener(_onOrderStateChanged);

    // Connect WebSocket for real-time updates
    WebSocketService().connect();
  }

  void _onOrderStateChanged() {
    if (!mounted) return;
    final state = ActiveOrderState.instance;
    final newStatus = state.orderStatus;

    // Check for transition to COMPLETED (4)
    if (newStatus == 4 && _lastStatus != 4) {
      final currentShopId = state.currentShopId;
      // Find the specific order that just completed
      final completedOrder = state.allOrdersList.firstWhere(
        (o) => o.orderStatus == 4,
        orElse: () => state.activeOrdersList.first, // Fallback
      );

      // Filter: only show popup if no shop is selected OR it matches the current shop
      if (currentShopId == null ||
          completedOrder.shopId == currentShopId.toString()) {
        OrderCompletePage.navigateTo(context);
      }
    }

    // Check for any order that just became CANCELLED (-1)
    // We check allOrdersList to find terminal states that are filtered out of activeOrdersList
    for (final order in state.allOrdersList) {
      if (order.orderStatus == -1 &&
          !_notifiedCancelledOrders.contains(order.orderId)) {
        final currentShopId = state.currentShopId;

        // Filter: only show if no shop context OR it matches
        if (currentShopId != null && order.shopId != currentShopId.toString()) {
          continue; // Skip this notification for now
        }

        _notifiedCancelledOrders.add(order.orderId);

        // Use a small delay to ensure WS state has settled and avoid UI jank
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderCancelPage(
                  orderId: order.orderId,
                  reason: order.cancelReason,
                  shopId: order.shopId,
                  shopName: order.shopName,
                  shopNameMm: order.shopNameMm,
                  shopLogo: order.shopLogo,
                  shopImageUrl: order.shopImageUrl,
                ),
              ),
            );
          }
        });
      }
    }

    _lastStatus = newStatus;
  }

  void _onTabChangeRequested() {
    final requested = NavigationController.instance.tabChangeRequest.value;
    if (requested != null && mounted) {
      setState(() => _currentIndex = requested);
      NavigationController.instance.tabChangeRequest.value = null;
    }
  }

  @override
  void dispose() {
    NavigationController.instance.tabChangeRequest.removeListener(
      _onTabChangeRequested,
    );
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[BOOT] Building MainNavigationScreen...');
    return Scaffold(
      body: Stack(
        children: [IndexedStack(index: _currentIndex, children: _screens)],
      ),
      floatingActionButton: const StyledCartFab(),
      bottomNavigationBar: Container(
        height: 70 + MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              0,
              PhosphorIcons.house,
              PhosphorIcons.houseFill,
              context.tr('nav.home'),
            ),
            _buildNavItem(
              1,
              PhosphorIcons.forkKnife,
              PhosphorIcons.forkKnifeFill,
              context.tr('nav.food'),
            ),
            _buildNavItem(
              2,
              PhosphorIcons.receipt,
              PhosphorIcons.receiptFill,
              context.tr('nav.orders'),
            ),
            // _buildNavItem(
            //   3,
            //   PhosphorIcons.newspaper,
            //   PhosphorIcons.newspaperFill,
            //   context.tr('nav.news'),
            // ),
            _buildNavItem(
              3,
              PhosphorIcons.user,
              PhosphorIcons.userFill,
              context.tr('nav.profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              Column(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: AppColors.primaryGradient.colors,
                    ).createShader(bounds),
                    child: Icon(activeIcon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: AppColors.primaryGradient.colors,
                    ).createShader(bounds),
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Icon(icon, color: Colors.grey.shade400, size: 26),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
