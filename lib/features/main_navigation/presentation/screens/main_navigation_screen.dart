import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../features/home/presentation/screens/home_page.dart';
import '../../../../features/food/presentation/screens/food_page.dart';
import '../../../../features/order/presentation/screens/order_history_page.dart';
import '../../../../features/news/presentation/screens/news_page.dart';
import '../../../../features/cart/presentation/widgets/styled_cart_fab.dart';
import '../../../../features/cart/data/active_order_state.dart';
import '../../../../features/cart/presentation/screens/order_complete_page.dart';
import '../../../../features/cart/presentation/screens/order_cancel_page.dart';
import '../../../../features/cart/presentation/widgets/active_order_bar.dart';
import '../../../../core/utils/navigation_controller.dart';

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
    NewsPage(),
  ];

  @override
  void initState() {
    super.initState();
    NavigationController.instance.tabChangeRequest.addListener(_onTabChangeRequested);
    
    // Global listener for order completion
    _lastStatus = ActiveOrderState.instance.orderStatus;
    ActiveOrderState.instance.addListener(_onOrderStateChanged);
  }

  void _onOrderStateChanged() {
    if (!mounted) return;
    final state = ActiveOrderState.instance;
    final newStatus = state.orderStatus;
    
    // Check for transition to COMPLETED (4)
    if (newStatus == 4 && _lastStatus != 4 && !OrderCompletePage.isCurrentlyVisible) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OrderCompletePage()),
      );
    }
    
    // Check for any order that just became CANCELLED (-1)
    // We check allOrdersList to find terminal states that are filtered out of activeOrdersList
    for (final order in state.allOrdersList) {
      if (order.orderStatus == -1 && !_notifiedCancelledOrders.contains(order.orderId)) {
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
    NavigationController.instance.tabChangeRequest.removeListener(_onTabChangeRequested);
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const ActiveOrderBar(),
          ),
        ],
      ),
      floatingActionButton: const StyledCartFab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFED3A72),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(PhosphorIcons.house()),
            activeIcon: Icon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIcons.forkKnife()),
            activeIcon: Icon(PhosphorIcons.forkKnife(PhosphorIconsStyle.fill)),
            label: 'Food',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIcons.receipt()),
            activeIcon: Icon(PhosphorIcons.receipt(PhosphorIconsStyle.fill)),
            label: 'Order History',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIcons.newspaper()),
            activeIcon: Icon(PhosphorIcons.newspaper(PhosphorIconsStyle.fill)),
            label: 'News',
          ),
        ],
      ),
    );
  }
}
