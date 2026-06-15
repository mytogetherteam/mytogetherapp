import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../../../features/home/presentation/screens/home_page.dart';
import '../../../../features/food/presentation/screens/food_page.dart';
import '../../../../features/order/presentation/screens/order_history_page.dart';
import '../../../../features/cart/presentation/widgets/styled_cart_fab.dart';
import '../../../../features/cart/data/active_order_state.dart';
import '../../../../features/cart/presentation/screens/order_complete_page.dart';
import '../../../../features/cart/presentation/screens/order_cancel_page.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../features/auth/presentation/screens/profile_page.dart';
import '../../../../features/news/presentation/screens/news_page.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/presentation/widgets/permission_rationale_modal.dart';
import '../widgets/welcome_modal.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int? _lastStatus;
  final Set<String> _notifiedCancelledOrders = {};
  late List<Widget> _screens;
  String _screenLocaleKey = '';

  @override
  void initState() {
    super.initState();
    _rebuildScreens();
    NavigationController.instance.tabChangeRequest.addListener(
      _onTabChangeRequested,
    );

    // Global listener for order completion
    _lastStatus = ActiveOrderState.instance.orderStatus;
    ActiveOrderState.instance.addListener(_onOrderStateChanged);

    // Connect WebSocket for real-time updates
    WebSocketService().connect();

    // Show welcome modal if first time, then check permissions after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WelcomeModal.showIfFirstTime(context, () {
        _checkAndRequestPermissions();
      });
    });
  }

  /// Tab bodies are keyed by locale so a language change rebuilds copy, but
  /// ordinary parent rebuilds (e.g. from unrelated notifiers) do not recreate
  /// every tab and re-trigger their initState/fetch logic.
  void _rebuildScreens() {
    final localeKey = LocaleController.instance.language.code;
    _screenLocaleKey = localeKey;
    _screens = <Widget>[
      HomePage(key: ValueKey('home_$localeKey')),
      FoodPage(key: ValueKey('food_$localeKey')),
      OrderHistoryPage(key: ValueKey('orders_$localeKey')),
      NewsPage(key: ValueKey('news_$localeKey')),
      ProfilePage(key: ValueKey('profile_$localeKey')),
    ];
  }

  Future<void> _checkAndRequestPermissions() async {
    final locationStatus = await Permission.location.status;
    final notificationStatus = await Permission.notification.status;
    
    // If either permission is implicitly denied (not yet asked or just denied), show rationale
    if (locationStatus.isDenied || notificationStatus.isDenied) {
      if (!mounted) return;
      await PermissionRationaleModal.show(context);
      
      // Request them together
      await [
        Permission.location,
        Permission.notification,
      ].request();
      
      // Trigger service initialization if granted
      if (await Permission.notification.isGranted) {
        await NotificationService().requestPermission();
      }
      if (await Permission.location.isGranted) {
        LocationService().getCurrentPosition();
      }
    } else {
      // Already handled before. Just fetch if granted.
      if (locationStatus.isGranted) {
        LocationService().getCurrentPosition();
      }
    }
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
        // The shop-cancellation page is only for orders cancelled BY the
        // restaurant. When the user cancels their own order they're shown a
        // dedicated apology page, so skip this notification for those.
        if (state.wasCancelledByUser(order.orderId)) {
          _notifiedCancelledOrders.add(order.orderId);
          continue;
        }
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
                  shopName: order.shopNameEn ??
                      order.shopName ??
                      order.restaurantName ??
                      order.storeName,
                  shopNameMm: order.shopNameMm,
                  shopNameTh: order.shopNameTh,
                  shopLogo: order.shopLogo ?? order.logoPath,
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
      // Reset the request after the current notification dispatch completes,
      // rather than re-entrantly mutating the notifier from inside its own
      // listener (which can swallow subsequent identical requests).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (NavigationController.instance.tabChangeRequest.value == requested) {
          NavigationController.instance.tabChangeRequest.value = null;
        }
      });
    }
  }

  @override
  void dispose() {
    NavigationController.instance.tabChangeRequest.removeListener(
      _onTabChangeRequested,
    );
    ActiveOrderState.instance.removeListener(_onOrderStateChanged);
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild tab list only when the active language changes.
    final localeKey = LocaleController.instance.language.code;
    if (localeKey != _screenLocaleKey) {
      _rebuildScreens();
    }

    return Scaffold(
      body: Stack(
        children: [IndexedStack(index: _currentIndex, children: _screens)],
      ),
      floatingActionButton: const StyledCartFab(),
      bottomNavigationBar: Container(
        height: 60 + (Theme.of(context).platform == TargetPlatform.iOS ? MediaQuery.of(context).padding.bottom * 0.5 : MediaQuery.of(context).padding.bottom),
        padding: EdgeInsets.only(bottom: Theme.of(context).platform == TargetPlatform.iOS ? MediaQuery.of(context).padding.bottom * 0.5 : MediaQuery.of(context).padding.bottom),
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
            _buildNavItem(
              3,
              PhosphorIcons.newspaper,
              PhosphorIcons.newspaperFill,
              context.tr('nav.news'),
            ),
            _buildNavItem(
              4,
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
        width: MediaQuery.of(context).size.width / 5,
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
