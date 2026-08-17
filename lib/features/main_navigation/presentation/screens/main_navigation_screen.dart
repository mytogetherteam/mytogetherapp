import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../../../features/home/presentation/screens/home_page.dart';
import '../../../../features/food/presentation/screens/food_page.dart';
import '../../../../features/social/presentation/screens/social_page.dart';
import '../../../../features/order/presentation/screens/order_history_page.dart';
import '../../../../features/cart/presentation/widgets/styled_cart_fab.dart';
import '../../../../features/cart/data/active_order_state.dart';
import '../../../../features/cart/presentation/screens/order_complete_page.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../../../features/news/presentation/screens/news_page.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/presentation/widgets/permission_rationale_modal.dart';
import '../widgets/guest_welcome_banner.dart';
import '../../../../core/utils/haptic_splash_factory.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int? _lastStatus;
  late List<Widget> _screens;
  String _screenLocaleKey = '';

  @override
  void initState() {
    super.initState();
    _rebuildScreens();
    NavigationController.instance.tabChangeRequest.addListener(
      _onTabChangeRequested,
    );
    LocaleController.instance.addListener(_onLanguageChanged);

    // Global listener for order completion
    _lastStatus = ActiveOrderState.instance.orderStatus;
    ActiveOrderState.instance.addListener(_onOrderStateChanged);

    // Connect WebSocket for real-time updates (signed-in users only)
    if (AuthService().isLoggedIn) {
      WebSocketService().connect();
    }

    // Request permissions after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermissions();
    });
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
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
      SocialPage(key: ValueKey('social_$localeKey')),
      _newsTab(localeKey),
      OrderHistoryPage(key: ValueKey('orders_$localeKey')),
    ];
  }

  Widget _newsTab(String localeKey) {
    return NewsPage(key: ValueKey('news_$localeKey'));
  }

  Future<void> _checkAndRequestPermissions() async {
    final locationStatus = await Permission.location.status;
    final isGuest = GuestAuthGuard.isGuest;

    if (isGuest) {
      if (locationStatus.isDenied) {
        if (!mounted) return;
        await PermissionRationaleModal.show(context, locationOnly: true);
        await Permission.location.request();
      }
      if (await Permission.location.isGranted) {
        await UserLocationRepository.instance
            .ensureSessionCurrentLocationFromDevice();
      }
      return;
    }

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

    // Show the completion screen only when the primary order just reached status 4.
    if (newStatus == 4 && _lastStatus != 4 && state.orderId != null) {
      final completedOrder = state.getOrder(state.orderId);
      if (completedOrder == null || completedOrder.orderStatus != 4) {
        _lastStatus = newStatus;
        return;
      }

      final currentShopId = state.currentShopId;

      // Filter: only show popup if no shop is selected OR it matches the current shop
      if (currentShopId == null ||
          completedOrder.shopId == currentShopId.toString()) {
        OrderCompletePage.navigateTo(context);
      }
    }

    // Shop-cancel navigation is handled globally by [OrderActionPresenter].

    _lastStatus = newStatus;
  }

  void _onTabChangeRequested() {
    final requested = NavigationController.instance.tabChangeRequest.value;
    if (requested != null && mounted) {
      // Tabs: 0=Home, 1=Food, 2=Social, 3=News, 4=Orders.
      final index = requested.clamp(0, 4);
      setState(() => _currentIndex = index);
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
    LocaleController.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onTabTapped(int index) {
    // Fire iOS 3D-touch-style haptic on every bottom nav icon tap
    AppHaptics.buttonTap();

    if (index == _currentIndex) {
      // Same tab tapped again → scroll to top + refresh that tab's content
      NavigationController.instance.triggerScrollToTop(index);
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
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
      floatingActionButton: _buildCartFab(),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hide guest promo on Social — it fights the full-bleed dark feed.
          if (!AuthService().isLoggedIn && _currentIndex != 2)
            GuestWelcomeBanner(
              onAuthFlowComplete: () {
                if (mounted) setState(() {});
              },
            ),
          _buildBottomNavigationBar(context),
        ],
      ),
    );
  }

  /// The cart FAB shown across tabs.
  ///
  /// Tabs: 0=Home, 1=Food, 2=Social, 3=News, 4=Orders.
  /// Profile opens via header avatar (not a tab).
  /// - Hidden on Social and News.
  Widget? _buildCartFab() {
    if (_currentIndex == 2 || _currentIndex == 3) return null;
    return const StyledCartFab();
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final isSocial = _currentIndex == 2;
    final barColor = isSocial ? Colors.black : Colors.white;
    final inactiveColor =
        isSocial ? Colors.white70 : Colors.grey.shade400;
    final bottomInset = Theme.of(context).platform == TargetPlatform.iOS
        ? MediaQuery.of(context).padding.bottom * 0.5
        : MediaQuery.of(context).padding.bottom;

    // Keep the bar at the original ~60px; raised Social button paints above
    // via clipBehavior: Clip.none (does not inflate footer height).
    const barBodyHeight = 60.0;

    return Material(
      color: barColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: barBodyHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (!isSocial)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  _buildNavItem(
                    0,
                    PhosphorIcons.house,
                    PhosphorIcons.houseFill,
                    context.tr('nav.home'),
                    inactiveColor: inactiveColor,
                    socialMode: isSocial,
                    height: barBodyHeight,
                  ),
                  _buildNavItem(
                    1,
                    PhosphorIcons.forkKnife,
                    PhosphorIcons.forkKnifeFill,
                    context.tr('nav.food'),
                    inactiveColor: inactiveColor,
                    socialMode: isSocial,
                    height: barBodyHeight,
                  ),
                  _buildRaisedSocialNavItem(
                    label: context.tr('nav.social'),
                    socialMode: isSocial,
                    height: barBodyHeight,
                  ),
                  _buildNavItem(
                    3,
                    PhosphorIcons.newspaper,
                    PhosphorIcons.newspaperFill,
                    context.tr('nav.news'),
                    inactiveColor: inactiveColor,
                    socialMode: isSocial,
                    height: barBodyHeight,
                  ),
                  _buildNavItem(
                    4,
                    PhosphorIcons.receipt,
                    PhosphorIcons.receiptFill,
                    context.tr('nav.orders'),
                    inactiveColor: inactiveColor,
                    socialMode: isSocial,
                    height: barBodyHeight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRaisedSocialNavItem({
    required String label,
    required bool socialMode,
    required double height,
  }) {
    final isSelected = _currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(2),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                // Sit mostly in the bar; slight lift above without growing footer.
                bottom: 16,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    border: Border.all(
                      color: socialMode ? Colors.black : Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    isSelected
                        ? PhosphorIcons.playCircleFill
                        : PhosphorIcons.playFill,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                left: 2,
                right: 2,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: isSelected
                        ? (socialMode ? Colors.white : AppColors.primary)
                        : (socialMode
                            ? Colors.white70
                            : Colors.grey.shade400),
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    required Color inactiveColor,
    required bool socialMode,
    required double height,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                socialMode
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(activeIcon, color: Colors.white, size: 26),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: AppColors.primaryGradient.colors,
                            ).createShader(bounds),
                            child: Icon(
                              activeIcon,
                              color: Colors.white,
                              size: 26,
                            ),
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
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: inactiveColor, size: 26),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: inactiveColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
