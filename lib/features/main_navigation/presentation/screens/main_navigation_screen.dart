import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../features/home/presentation/screens/home_page.dart';
import '../../../../features/food/presentation/screens/food_page.dart';
import '../../../../features/order/presentation/screens/order_history_page.dart';
import '../../../../features/news/presentation/screens/news_page.dart';
import '../../../../features/cart/presentation/widgets/styled_cart_fab.dart';
import '../../../../features/cart/presentation/widgets/active_order_bar.dart';
import '../../../../core/utils/navigation_controller.dart';
import 'package:geolocator/geolocator.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomePage(),
    FoodPage(),
    OrderHistoryPage(),
    NewsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    NavigationController.instance.tabChangeRequest.addListener(_onTabChangeRequested);
  }

  void _onTabChangeRequested() {
    final requested = NavigationController.instance.tabChangeRequest.value;
    if (requested != null && mounted) {
      setState(() => _currentIndex = requested);
      NavigationController.instance.tabChangeRequest.value = null;
    }
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
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
