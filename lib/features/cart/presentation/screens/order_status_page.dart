import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/time_formatter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/utils/file_url_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import 'dart:ui' as ui;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/presentation/widgets/gradient_icon.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/animated_dots_text.dart';
import '../../data/active_order_state.dart';
import '../../../coupons/presentation/widgets/order_coupon_discount_section.dart';
import '../widgets/flexible_delivery_note.dart';
import 'order_complete_page.dart';
import 'awaiting_payment_page.dart';
import 'order_cancel_page.dart';
import '../../../home/data/repositories/restaurant_repository.dart';
import '../../../home/presentation/widgets/image_skeleton_loader.dart';
import '../../../home/presentation/widgets/my_together_verified_badge.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../chat/presentation/screens/chat_page.dart';
import '../../../chat/data/services/chat_unread_controller.dart';
import '../../../chat/presentation/widgets/chat_unread_badge.dart';
import '../../../chat/presentation/widgets/chat_shake_animator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/pickup_order_qr_card.dart';
import '../widgets/order_payment_bottom_sheet.dart';
import '../../../../app.dart';
import '../../../chat/presentation/widgets/floating_chat_head.dart';
import 'package:mytogetherapp/features/call/presentation/screens/call_screen.dart';
import '../../../call/data/call_session.dart';
import '../widgets/food_game/food_game_banner.dart';

class OrderStatusPage extends StatefulWidget {
  final double foodTotal;
  final double deliveryFee;
  final bool autoShowPaymentSheet;
  final String? orderId;

  static bool isCurrentlyVisible = false;

  const OrderStatusPage({
    super.key,
    required this.foodTotal,
    required this.deliveryFee,
    this.autoShowPaymentSheet = false,
    this.orderId,
  });

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  int _currentStatus = 1;
  String? _backendStatus;
  bool _hasShownDeliveryFeeModal = false;
  bool _isPaymentSheetShowing = false;

  Future<void> _openPaymentBottomSheet() async {
    if (_isPaymentSheetShowing || !mounted) return;
    final orderIdStr = widget.orderId ?? ActiveOrderState.instance.orderId;
    final order = ActiveOrderState.instance.getOrder(orderIdStr);
    if (order == null) return;

    _isPaymentSheetShowing = true;
    final intId = _currentOrderId ??
        int.tryParse(order.orderId.replaceAll('#', '')) ??
        0;

    await OrderPaymentBottomSheet.show(
      context,
      order: order,
      orderId: intId,
      foodTotal: widget.foodTotal,
      deliveryFee: ActiveOrderState.instance.deliveryFee ?? widget.deliveryFee,
      onPaymentCompleted: () {
        final active = ActiveOrderState.instance.getOrder(order.orderId);
        if (active != null) {
          active.orderStatus = 2;
          active.backendStatus = 'COOKING';
        }
        if (mounted) {
          setState(() {
            _currentStatus = 2;
            _backendStatus = 'COOKING';
          });
          _animateToStatus(2);
        }
      },
    );

    _isPaymentSheetShowing = false;
    if (mounted) setState(() {});
  }

  GoogleMapController? _mapController;
  // ignore: unused_field
  Set<Marker> _markers = {};
  // ignore: unused_field
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _homeIcon;
  BitmapDescriptor? _shopIcon;

  late AnimationController _processingController;

  WebViewController? _webController;
  bool _webViewError = false;
  String? _lastInitedUrl;

  Timer? _fakeTimer;
  static final Map<String, DateTime> _orderStartTimes = {};

  StreamSubscription? _orderSubscription;

  /// Remote Order-position banner (waiting/cooking visual). Null = use asset GIF.
  // ignore: unused_field
  String? _orderWaitingImageUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      App.routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = true);
  }

  @override
  void didPopNext() {
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = true);
  }

  @override
  void didPop() {
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = false);
  }

  void _startFakeTimer() {
    final orderId = ActiveOrderState.instance.orderId;
    if (orderId != null && !_orderStartTimes.containsKey(orderId)) {
      _orderStartTimes[orderId] = DateTime.now();
    }
    _fakeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchOrderWaitingBanner() async {
    try {
      final banners = await RestaurantRepository.instance.getBanners(
        position: 'Order',
      );
      if (!mounted || banners.isEmpty) return;
      final url = banners.first.imageUrl;
      if (url.isEmpty) return;
      setState(() => _orderWaitingImageUrl = url);
    } catch (e) {
      if (kDebugMode) debugPrint('order_status_page.dart: ignored error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = true);
    OrderStatusPage.isCurrentlyVisible = true;
    _currentStatus = ActiveOrderState.instance.orderStatus.clamp(1, 4);
    _backendStatus = ActiveOrderState.instance.backendStatus;
    _startFakeTimer();
    _fetchOrderWaitingBanner();

    if (widget.autoShowPaymentSheet || _currentStatus == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentStatus == 1) {
          _openPaymentBottomSheet();
        }
      });
    }

    // Auto-navigate if already completed
    if (ActiveOrderState.instance.orderStatus == 4) {
      Future.delayed(const Duration(seconds: 2), () => _navigateToComplete());
    }

    _buildCustomMarkers().then((_) {
      if (mounted) _updateMarkers();
    });

    // Processing animation for current segment (repeating 0 -> 1)
    _processingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Initial animation position based on starting status
    _animateToStatus(_currentStatus);

    // Initialize WebView if already on the way
    final state = ActiveOrderState.instance;
    if (_currentStatus == 3 &&
        state.deliveryTrackingUrl != null &&
        state.deliveryTrackingUrl!.isNotEmpty) {
      _initWebView(state.deliveryTrackingUrl!);
    }

    // Connect to WebSockets with force: true to ensure topic subscriptions are refreshed with the current orderId
    WebSocketService().connect(force: true);

    // Reconcile with the backend on open and on resume so a stale local status
    // (from missed WebSocket events) can't keep the user on an earlier stage
    // than the order has actually reached.
    WidgetsBinding.instance.addObserver(this);
    _reconcileWithBackend();

    // Track unread chat messages for this order so the chat icon can badge them.
    ChatUnreadController.instance.start();
    final chatOrderId = _currentOrderId;
    if (chatOrderId != null) {
      ChatUnreadController.instance.refreshOrder(chatOrderId);
    }

    _orderSubscription = WebSocketService().orderUpdates.listen((update) {
      if (mounted) {
        final state = ActiveOrderState.instance;
        setState(() {
          // Map ActiveOrderState orderStatus (0-4) to local _currentStatus (1-4)
          _currentStatus = state.orderStatus.clamp(1, 4);
          _backendStatus = state.backendStatus;

          // Trigger WebView init if status is 3 and we have a new URL
          if (_currentStatus == 3 &&
              state.deliveryTrackingUrl != null &&
              state.deliveryTrackingUrl!.isNotEmpty &&
              state.deliveryTrackingUrl != _lastInitedUrl) {
            _initWebView(state.deliveryTrackingUrl!);
          }
        });

        // Auto-navigate when status becomes COMPLETED (4)
        if (state.orderStatus == 4) {
          Future.delayed(
            const Duration(seconds: 2),
            () => _navigateToComplete(),
          );
        }

        if (state.orderStatus == -1) {
          final order = state.getOrder(state.orderId);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderCancelPage(
                orderId: state.orderId ?? '',
                reason: order?.cancelReason,
                shopId: order?.shopId,
                shopName:
                    order?.shopName ??
                    order?.restaurantName ??
                    order?.storeName,
                shopNameMm: order?.shopNameMm ?? order?.statusLabelMm,
                shopNameTh: order?.shopNameTh ?? order?.statusLabelTh,
                shopLogo: order?.shopLogo ?? order?.logoPath,
                shopImageUrl: order?.shopImageUrl,
              ),
            ),
          );
          return;
        }

        // Auto-navigate back to Payment ONLY when the shop explicitly requested
        // a (new) payment slip. Gating on isSlipRequested prevents other
        // status-1 states (e.g. payment verified in flight) from bouncing the
        // user off the status screen.
        if (state.orderStatus == 1 &&
            state.isSlipRequested &&
            !state.isPaymentChecking) {
          if (!state.hasNotifiedSlipRequest) {
            state.setNotifiedSlipRequest(true);
          }
          final currentOrder = state.getOrder(state.orderId);
          if (currentOrder?.isVerified == true) {
            _openPaymentBottomSheet();
          } else if (!AwaitingPaymentPage.isCurrentlyVisible) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AwaitingPaymentPage(
                  orderId: state.orderId,
                  foodTotal: widget.foodTotal,
                  deliveryFee: state.deliveryFee ?? widget.deliveryFee,
                ),
              ),
            );
          }
        }
      }
    });

    // Proactively fetch restaurant address if missing (e.g. on app restart)
    _recoverMissingRestaurantAddress();
  }

  Future<void> _recoverMissingRestaurantAddress() async {
    final state = ActiveOrderState.instance;
    if ((state.restaurantAddress == null || state.restaurantAddress!.isEmpty) &&
        state.restaurantId != null) {
      try {
        final id = int.tryParse(state.restaurantId!);
        if (id != null) {
          final shop = await RestaurantRepository.instance.getShopById(id);
          if (mounted) {
            setState(() {
              state.restaurantAddress =
                  shop.address ?? shop.addressEn ?? shop.addressTh;
              state.saveToPrefs();
            });
          }
        }
      } catch (e) {
        // Ignore error recovering restaurant address
      }
    }
  }

  void _initWebView(String url) {
    _lastInitedUrl = url;
    _webViewError = false;

    // Safety check for scheme
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      if (mounted) setState(() => _webViewError = true);
      return;
    }

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (mounted) {
              setState(() => _webViewError = true);
            }
          },
          onNavigationRequest: (request) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(uri);
  }

  void _animateToStatus(int status) {
    // This method is now legacy as segment colors update via setState
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconcileWithBackend();
    }
  }

  /// Fetches the authoritative order status from the backend and syncs the
  /// stepper / completion navigation, covering cases where live WebSocket
  /// updates were missed while the app was backgrounded or disconnected.
  Future<void> _reconcileWithBackend() async {
    await ActiveOrderState.instance.syncActiveOrder();
    if (!mounted) return;
    final state = ActiveOrderState.instance;
    final status = state.orderStatus;
    setState(() => _currentStatus = status.clamp(1, 4));

    if (status == -1) {
      final order = state.getOrder(state.orderId);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderCancelPage(
            orderId: state.orderId ?? '',
            reason: order?.cancelReason,
            shopId: order?.shopId,
            shopName:
                order?.shopName ?? order?.restaurantName ?? order?.storeName,
            shopNameMm: order?.shopNameMm ?? order?.statusLabelMm,
            shopNameTh: order?.shopNameTh ?? order?.statusLabelTh,
            shopLogo: order?.shopLogo ?? order?.logoPath,
            shopImageUrl: order?.shopImageUrl,
          ),
        ),
      );
      return;
    }

    if (status == 4) {
      Future.delayed(const Duration(seconds: 1), _navigateToComplete);
    }
  }

  @override
  void dispose() {
    OrderStatusPage.isCurrentlyVisible = false;
    _fakeTimer?.cancel();
    _processingController.dispose();
    App.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _navigateToComplete() {
    if (!mounted) return;
    OrderCompletePage.navigateReplacing(context);
  }

  // ignore: unused_element
  LatLng get _restaurantLatLng {
    final state = ActiveOrderState.instance;
    final lat = state.restaurantLatLng?.latitude;
    final lon = state.restaurantLatLng?.longitude;

    if (lat != null && lon != null && lat != 0) {
      final userLat = state.userLocation?.latitude ?? 13.7563;
      final userLon = state.userLocation?.longitude ?? 100.5018;

      final dist = Geolocator.distanceBetween(lat, lon, userLat, userLon);
      if (dist > 100000) {
        // > 100km mismatch
        return LatLng(userLat + 0.005, userLon + 0.005); // Move shop near user
      }
      return LatLng(lat, lon);
    }
    return const LatLng(13.7563, 100.5018); // Default Bangkok
  }

  void _goHome() {
    _orderSubscription?.cancel();
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _buildCustomMarkers() async {
    _homeIcon = await _drawMarkerBitmap(
      icon: Icons.home_rounded,
      bgColor: AppColors.primary,
      iconColor: Colors.white,
      size: 75,
    );
    _shopIcon = await _drawMarkerBitmap(
      icon: Icons.restaurant,
      bgColor: AppColors.primary,
      iconColor: Colors.white,
      size: 75,
    );
  }

  Future<BitmapDescriptor> _drawMarkerBitmap({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    double size = 75,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final double r = size / 2;

    canvas.drawCircle(
      Offset(r, r + 4),
      r * 0.85,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawCircle(Offset(r, r), r, Paint()..color = Colors.white);

    // Gradient fill
    final paint = Paint()
      ..shader = AppColors.primaryGradient.createShader(
        Rect.fromLTWH(0, 0, size, size),
      );
    canvas.drawCircle(Offset(r, r), r - 4, paint);

    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.44,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: iconColor,
        ),
      );
    tp.layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2 - 2));

    final img = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  void _updateMarkers() {
    final state = ActiveOrderState.instance;
    final sets = <Marker>{};

    if (state.restaurantLatLng != null) {
      sets.add(
        Marker(
          markerId: const MarkerId('restaurant'),
          position: state.restaurantLatLng!,
          icon: _shopIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (state.userLocation != null) {
      sets.add(
        Marker(
          markerId: const MarkerId('user'),
          position: state.userLocation!,
          icon: _homeIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    final polySet = <Polyline>{};
    if (state.routePoints.isNotEmpty) {
      polySet.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: state.routePoints,
          color: AppColors.primary,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = sets;
        _polylines = polySet;
      });
    }
  }

  // ignore: unused_element
  void _fitBounds() {
    if (_mapController == null) return;
    final state = ActiveOrderState.instance;
    final all = [
      if (state.restaurantLatLng != null &&
          state.restaurantLatLng!.latitude != 0)
        state.restaurantLatLng!,
      if (state.userLocation != null && state.userLocation!.latitude != 0)
        state.userLocation!,
      ...state.routePoints,
    ];
    if (all.isEmpty) return;

    double minLat = all.first.latitude;
    double maxLat = all.first.latitude;
    double minLng = all.first.longitude;
    double maxLng = all.first.longitude;

    for (var p in all) {
      if (p.latitude == 0 && p.longitude == 0) {
        continue; // Ignore invalid points
      }
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  bool get _isVerifiedShop {
    final state = ActiveOrderState.instance;
    final order = state.getOrder(widget.orderId ?? state.orderId);
    return order?.isVerified == true || state.isVerified;
  }

  bool get _isPaymentVerified {
    final upper = _backendStatus?.toUpperCase();
    return upper == 'PAID' ||
        upper == 'PAYMENT_VERIFIED' ||
        _currentStatus >= 2;
  }

  String _statusTitle(BuildContext context) {
    if (_currentStatus == -1) return context.tr('order_status.cancelled');
    final isPickup = ActiveOrderState.instance.isPickupFulfillment;
    if (isPickup && ActiveOrderState.instance.isReadyForPickup) {
      return context.tr('order_status.ready_for_pickup');
    }
    if (isPickup && _currentStatus == 4) {
      return context.tr('order_status.picked_up');
    }

    if (_isVerifiedShop) {
      if (!_isPaymentVerified) {
        return context.tr('order.status.waiting_payment');
      }
      final isExplicitPaymentVerified =
          _backendStatus?.toUpperCase() == 'PAYMENT_VERIFIED' ||
              _backendStatus?.toUpperCase() == 'PAID';
      if (_currentStatus == 1 || (_currentStatus == 2 && isExplicitPaymentVerified)) {
        return context.tr('order.status.payment_verified');
      }
      switch (_currentStatus) {
        case 2:
          if (_backendStatus?.toUpperCase() == 'COOKING') {
            return context.tr('order_status.cooking_now');
          }
          return context.tr('order_status.preparing');
        case 3:
          return context.tr('order_status.delivering');
        case 4:
          return context.tr('order_status.arrived');
        default:
          return context.tr('order.status.payment_verified');
      }
    }

    switch (_currentStatus) {
      case 1:
        return context.tr('order_status.checking_payment');
      case 2:
        if (_backendStatus?.toUpperCase() == 'COOKING') {
          return context.tr('order_status.cooking_now');
        }
        return context.tr('order_status.preparing');
      case 3:
        return context.tr('order_status.delivering');
      case 4:
        return context.tr('order_status.arrived');
      default:
        return context.tr('order_status.processing');
    }
  }


  @override
  Widget build(BuildContext context) {
    final state = ActiveOrderState.instance;
    final storeName = state.displayShopName.isNotEmpty
        ? state.displayShopName
        : context.tr('common.restaurant');
    final taxAmount = state.resolvedTaxAmount;
    final delivery = state.deliveryFee ?? widget.deliveryFee;
    final showFlexibleDeliveryFee = state.isFlexibleDelivery && _currentStatus >= 3;
    
    if (showFlexibleDeliveryFee && delivery > 0 && !_hasShownDeliveryFeeModal) {
      _hasShownDeliveryFeeModal = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDeliveryFeeModal(delivery);
      });
    }
    
    double? adjustedTotalAmount = state.totalAmount;
    bool backendTotalAdjusted = false;
    if (showFlexibleDeliveryFee && adjustedTotalAmount != null) {
      final payNowWithoutDelivery = state.resolvedPayNowTotal(fallbackDeliveryFee: 0);
      if ((adjustedTotalAmount - payNowWithoutDelivery).abs() < 0.01) {
        adjustedTotalAmount += delivery;
        backendTotalAdjusted = true;
      }
    }

    final total = (state.usesPayNowTotal && !showFlexibleDeliveryFee)
        ? state.resolvedPayNowTotal(fallbackDeliveryFee: delivery)
        : (adjustedTotalAmount ??
              state.resolvedGrandTotal(fallbackDeliveryFee: delivery));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: _goHome,
        ),
        title: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 32,
                height: 32,
                child: state.logoPath != null && state.logoPath!.isNotEmpty
                    ? CachedNetworkImage(
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        imageUrl: state.logoPath!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[100],
                          child: const Center(
                            child: CustomLoadingIndicator(size: 16),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildNoImageAvatar(),
                      )
                    : _buildNoImageAvatar(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: VerifiedRestaurantNameRow(
                name: storeName,
                isVerified: state.isVerified,
                style: AppFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                badgeSize: MyTogetherVerifiedBadge.detailSize,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated Header text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: _currentStatus == -1
                      ? Text(
                          _statusTitle(context),
                          key: ValueKey<int>(_currentStatus),
                          style: AppFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEF4444),
                          ),
                        )
                      : GradientText(
                          _statusTitle(context),
                          key: ValueKey<int>(_currentStatus),
                          style: AppFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                if (_currentStatus != -1) ...[
                  if (!(state.isPickupFulfillment && state.isReadyForPickup)) ...[
                    if (state.hasPrepTimeEstimate)
                      GradientText(
                        '${context.tr('order_status.est_waiting_time')}: ${_getFakeEstTime(state.estimatedTime!, state.orderId)}',
                        style: AppFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      AnimatedDotsText(
                        baseText: state.isPickupFulfillment
                            ? context.tr('order_status.preparing')
                            : (_isVerifiedShop && !_isPaymentVerified)
                                ? context.tr('order.status.waiting_payment')
                                : context.tr('order_tracking.restaurant_reviewing'),
                        style: AppFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  // Progress Bar
                  if (!(state.isPickupFulfillment && state.isReadyForPickup)) ...[
                    _buildProgressBar(),
                    const SizedBox(height: 32),
                  ],
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentStatus != -1) ...[

              
              if (state.isFlexibleDelivery && !state.isAwaitingShopConfirmation) ...[
                const SizedBox(height: 16),
                FlexibleDeliveryNote(
                  estimatedFee:
                      state.displayDeliveryFee ??
                      state.deliveryFee!.toFormattedPrice(),
                  isActualFee: _currentStatus >= 3,
                ),
                const SizedBox(height: 16),
              ],
              
              if (state.isPickupFulfillment &&
                  state.isReadyForPickup &&
                  state.orderId != null) ...[
                PickupOrderQrCard(
                  orderId: state.orderId!,
                  lastOrderNo: state.lastOrderNo,
                ),
                const SizedBox(height: 24),
              ],
            ],

            // Map Embed (only if status >= 3)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(sizeFactor: animation, child: child),
                );
              },
              child: (() {
                if (ActiveOrderState.instance.isPickupFulfillment ||
                    _currentStatus < 3 ||
                    _currentStatus == -1) {
                  return const SizedBox.shrink(key: ValueKey('empty_map'));
                }

                final state = ActiveOrderState.instance;
                final bool hasTrackingUrl =
                    state.deliveryTrackingUrl != null &&
                    state.deliveryTrackingUrl!.isNotEmpty;

                if (!hasTrackingUrl) {
                  return const SizedBox.shrink(key: ValueKey('empty_map'));
                }

                return Column(
                  key: const ValueKey('map_section'),
                  children: [
                    Container(
                      height: 260,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(child: ImageSkeletonLoader()),
                          if (_webController != null && !_webViewError)
                            Positioned.fill(
                              child: WebViewWidget(controller: _webController!),
                            )
                          else
                            Positioned.fill(
                              child: Container(
                                color: Colors.grey[50],
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        PhosphorIcons.mapPinLine,
                                        size: 40,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Tracking view unavailable',
                                        style: AppFonts.poppins(
                                          color: Colors.grey[600],
                                          fontSize: 13,
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
                    const SizedBox(height: 12),
                    PrimaryGradientButton(
                      height: 48,
                      onPressed: () async {
                        final uri = Uri.parse(state.deliveryTrackingUrl!);
                        try {
                          final launched = await launchUrl(
                            uri,
                            mode: LaunchMode.inAppBrowserView,
                          );
                          if (!launched) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        } catch (e) {
                          try {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (e) {
                            if (kDebugMode) debugPrint('order_status_page.dart: ignored error: $e');
                          }
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            PhosphorIcons.arrowSquareOut,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (context.tr('order_status.track_order_link') ==
                                    'order_status.track_order_link')
                                ? 'Track Order'
                                : context.tr('order_status.track_order_link'),
                            style: AppFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              })(),
            ),

            // Shop Info Card
            if (_currentStatus != -1 && state.riderName != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _statusDescription(context, storeName),
                          style: AppFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          if (state.riderProfileUrl != null &&
                              state.riderProfileUrl!.isNotEmpty)
                            ClipOval(
                              child: CachedNetworkImage(memCacheWidth: 132, 
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                imageUrl: FileUrlUtil.resolve(
                                  state.riderProfileUrl!,
                                ),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[100],
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    size: 24,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[100],
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 24,
                                color: Colors.grey,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => AppColors
                                      .primaryGradient
                                      .createShader(bounds),
                                  child: Text(
                                    (state.riderName != null &&
                                            state.riderName!.trim().isNotEmpty)
                                        ? state.riderName!
                                        : context.tr(
                                            'order_status.assigning_rider',
                                          ),
                                    style: AppFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors
                                          .white, // required for ShaderMask
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (state.riderPhone != null &&
                                        state.riderPhone!
                                            .trim()
                                            .isNotEmpty) ...[
                                      Text(
                                        'Phone: ',
                                        style: AppFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        state.riderPhone!,
                                        style: AppFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                    if (state.riderPhone != null &&
                                        state.riderPhone!.trim().isNotEmpty &&
                                        state.riderVehicleNumber != null &&
                                        state.riderVehicleNumber!
                                            .trim()
                                            .isNotEmpty)
                                      Text(
                                        '  |  ',
                                        style: AppFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[300],
                                        ),
                                      ),
                                    if (state.riderVehicleNumber != null &&
                                        state.riderVehicleNumber!
                                            .trim()
                                            .isNotEmpty) ...[
                                      Text(
                                        'Vehicle No: ',
                                        style: AppFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        state.riderVehicleNumber!,
                                        style: AppFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_currentStatus == -1) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.cancelReason ??
                                    context.tr('order_status.cancel_reason'),
                                style: AppFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Mini Food Game Banner (for engaging user while order is preparing/delivering)
            if (_currentStatus != -1 && _currentStatus < 4) ...[
              const FoodGameBanner(),
              const SizedBox(height: 16),
            ],

            // Order Summary Card (myshop profile top menu border style)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ALWAYS VISIBLE PAYMENT BOX
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('order_status.payment_method'),
                              style: AppFonts.poppins(
                                fontSize: 13.5,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    PhosphorIcons.qrCode,
                                    size: 15,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    context.tr('order_status.qr_promptpay'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              state.usesPayNowTotal
                                  ? context.tr('cart.total_pay_now')
                                  : context.tr('cart.total'),
                              style: AppFonts.poppins(
                                fontSize: 13.5,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  (backendTotalAdjusted ? null : state.displayTotalAmount) ??
                                      total.toFormattedPrice(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isPaymentVerified
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isPaymentVerified
                                          ? const Color(0xFFBBF7D0)
                                          : const Color(0xFFFDE68A),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _isPaymentVerified
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFD97706),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _isVerifiedShop
                                            ? (_isPaymentVerified
                                                ? context.tr(
                                                    'order.status.payment_verified',
                                                  )
                                                : context.tr(
                                                    'order.status.waiting_payment',
                                                  ))
                                            : ((_backendStatus?.toUpperCase() ==
                                                        'PAID' ||
                                                    _currentStatus >= 2)
                                                ? context.tr('order_status.paid')
                                                : context.tr(
                                                    'order_status.waiting_payment',
                                                  )),
                                        style: AppFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _isPaymentVerified
                                              ? const Color(0xFF15803D)
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      iconColor: const Color(0xFF64748B),
                      collapsedIconColor: const Color(0xFF64748B),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              PhosphorIcons.receipt,
                              size: 17,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr('order_status.view_summary'),
                            style: AppFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        if (state.orderItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              context.tr('order_status.no_items'),
                              style: AppFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          )
                        else
                          ...state.orderItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFF1F5F9),
                                          width: 1,
                                        ),
                                      ),
                                      child: CachedNetworkImage(
                                        fadeInDuration: Duration.zero,
                                        fadeOutDuration: Duration.zero,
                                        imageUrl: item.imagePath,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const Center(
                                              child: CustomLoadingIndicator(size: 14),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            const Center(
                                              child: Icon(
                                                PhosphorIcons.forkKnife,
                                                size: 18,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '${item.quantity}x ',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                              TextSpan(
                                                text: item.title,
                                                style: AppFonts.poppins(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF1E293B),
                                                ),
                                              ),
                                            ],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.variantName != null &&
                                            item.variantName!.trim().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.variantName!,
                                            style: AppFonts.poppins(
                                              fontSize: 12,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (item.price * item.quantity)
                                        .toFormattedPrice(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                        ),

                        _buildSummaryRow(
                          context.tr('order_status.food_total'),
                          state.displayFoodPrice ??
                              widget.foodTotal.toFormattedPrice(),
                        ),
                        if (state.taxEnable) ...[
                          const SizedBox(height: 4),
                          _buildSummaryRow(
                            context.tr('order_status.tax'),
                            state.displayTaxAmount ??
                                taxAmount.toFormattedPrice(),
                          ),
                        ],
                        if (state.hasAppliedCoupon) ...[
                          const SizedBox(height: 4),
                          OrderCouponDiscountSection(
                            couponName: state.couponName,
                            discountAmount: state.discountAmount,
                            displayDiscountAmount: state.displayDiscountAmount,
                            shopCoupon: state.shopCoupon,
                          ),
                        ],
                        if (state.hasTransactionDiscount) ...[
                          const SizedBox(height: 4),
                          _buildSummaryRow(
                            context.tr('order_status.transaction_discount'),
                            '- ${state.displayTransactionDiscount ?? state.transactionDiscount.toFormattedPrice()}',
                            valueColor: AppColors.primary,
                          ),
                        ],
                        if (!state.isPickupFulfillment &&
                            state.hasDeliveryFeeEstimate &&
                            !state.isAwaitingShopConfirmation &&
                            (!state.isFlexibleDelivery || showFlexibleDeliveryFee)) ...[
                          const SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              final isFree = (state.displayDeliveryFee?.toUpperCase() == 'FREE') ||
                                  (state.deliveryFee == 0);
                              return _buildSummaryRow(
                                context.tr('order_status.delivery_fee'),
                                isFree ? 'FREE' : (state.displayDeliveryFee ?? state.deliveryFee!.toFormattedPrice()),
                                valueWidget: isFree
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
                                        ),
                                        child: Text(
                                          'FREE',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF16A34A),
                                          ),
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, thickness: 1.2, color: Color(0xFFE2E8F0)),
                        ),
                        _buildSummaryRow(
                          (state.usesPayNowTotal && !showFlexibleDeliveryFee)
                              ? context.tr('cart.total_pay_now')
                              : context.tr('order_status.total_amount'),
                          (state.usesPayNowTotal && !showFlexibleDeliveryFee)
                              ? total.toFormattedPrice()
                              : ((backendTotalAdjusted ? null : state.displayTotalAmount) ??
                                    total.toFormattedPrice()),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Delivery Info Card
            if (!state.isPickupFulfillment &&
                _currentStatus != -1 &&
                (_currentStatus >= 3 ||
                    (state.riderName != null && state.riderName!.isNotEmpty)))
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: bike icon + title
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/delivery_bike.png',
                          width: 40,
                          height: 40,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          context.tr('order_status.delivery_info'),
                          style: AppFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    // Route: restaurant -> destination with dotted line
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left: icons + dotted line
                          Column(
                            children: [
                              Container(
                                width: 15,
                                height: 15,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4A90E2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: CustomPaint(
                                  painter: _DottedLinePainter(),
                                  child: const SizedBox(width: 2),
                                ),
                              ),
                              const GradientIcon(
                                icon: Icons.location_on,
                                size: 22,
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          // Right: Info (either Cancelled or Route text)
                          Expanded(
                            child:
                                _currentStatus == -1 &&
                                    state.cancelReason != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        context.tr('order_status.cancelled'),
                                        style: AppFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        state.cancelReason!,
                                        style: AppFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Restaurant row
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          VerifiedRestaurantNameRow(
                                            name: storeName,
                                            isVerified: state.isVerified,
                                            style: AppFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            badgeSize: MyTogetherVerifiedBadge.cardSize,
                                          ),
                                          if (state.restaurantAddress != null &&
                                              state
                                                  .restaurantAddress!
                                                  .isNotEmpty)
                                            Text(
                                              state.restaurantAddress!,
                                              style: AppFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 40),
                                      // Destination row
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (state.deliveryAddress != null &&
                                                    state
                                                        .deliveryAddress!
                                                        .isNotEmpty)
                                                ? state.deliveryAddress!
                                                : context.tr(
                                                    'food.my_location',
                                                  ),
                                            style: AppFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Reorder/Cancel Actions
            if (_currentStatus == -1)
              PrimaryGradientButton(
                onPressed: () {
                  ActiveOrderState.instance.clearOrder();
                  _goHome();
                },
                child: Text(
                  context.tr('order_status.order_again'),
                  style: AppFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showFlexibleDeliveryFee && delivery > 0) ...[
              GestureDetector(
                onTap: () => _showDeliveryFeeModal(delivery),
                child: Container(
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            context.tr('order_status.delivery_fee'),
                            style: AppFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(PhosphorIconsRegular.info, size: 16, color: Colors.grey[400]),
                        ],
                      ),
                      GradientText(
                        delivery.toFormattedPrice(),
                        style: AppFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_currentStatus == 1 && (!_isVerifiedShop || !_isPaymentVerified)) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.38),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openPaymentBottomSheet();
                    },
                    borderRadius: BorderRadius.circular(20),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // Ambient glowing background circles for visual depth
                            Positioned(
                              right: -15,
                              top: -20,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 60,
                              bottom: -25,
                              child: Container(
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                            // Content
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  // Left Icon Badge with glassmorphic styling
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        PhosphorIconsBold.qrCode,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Center Info (Title + Urgent Tag + Methods)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'ငွေပေးချေရန်',
                                                style: AppFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.2,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.25),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'PAY NOW',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'PromptPay • TrueMoney • Slip',
                                          style: AppFonts.poppins(
                                            color: Colors.white.withValues(alpha: 0.92),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Right Price Pill with modern circular arrow button
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.28),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          (state.totalAmount ??
                                                  (widget.foodTotal +
                                                      widget.deliveryFee))
                                              .toFormattedPrice(),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: AppColors.primary,
                                              size: 10,
                                            ),
                                          ),
                                        ),
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
                  ),
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: ChatShakeAnimator(
                    orderId: _currentOrderId,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: const Color(0xFF64748B).withValues(alpha: 0.04),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openChat(
                              name: state.shopName ??
                                  state.restaurantName ??
                                  state.storeName ??
                                  'Restaurant',
                              subtitle: context.tr('common.restaurant'),
                              avatarUrl: state.logoPath ?? state.shopLogo,
                            );
                          },
                          borderRadius: BorderRadius.circular(24),
                          splashColor: AppColors.primary.withValues(alpha: 0.1),
                          highlightColor:
                              AppColors.primary.withValues(alpha: 0.05),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ChatUnreadBadge(
                                orderId: _currentOrderId,
                                child: const Icon(
                                  PhosphorIcons.chatCircleTextFill,
                                  color: Color(0xFF1E293B),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                context.tr('order_confirm.chat'),
                                style: AppFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: const Color(0xFF64748B).withValues(alpha: 0.04),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _makeCall(state.shopPhone);
                      },
                      customBorder: const CircleBorder(),
                      splashColor: AppColors.primary.withValues(alpha: 0.1),
                      highlightColor: AppColors.primary.withValues(alpha: 0.05),
                      child: const Center(
                        child: Icon(
                          PhosphorIcons.phoneFill,
                          color: Color(0xFF1E293B),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getFakeEstTime(String original, String? orderId) {
    if (orderId == null) return TimeFormatter.normalizeDisplay(original);

    // Try to parse max minutes from original string (e.g., "25 mins" -> 25)
    final match = RegExp(r'(\d+)').firstMatch(original);
    if (match == null) return TimeFormatter.normalizeDisplay(original);

    int maxMins = int.tryParse(match.group(1)!) ?? 0;
    if (maxMins <= 5) return TimeFormatter.normalizeDisplay(original);

    final startTime = _orderStartTimes[orderId] ?? DateTime.now();
    final elapsedMins = DateTime.now().difference(startTime).inMinutes;

    int currentMax = maxMins - elapsedMins;
    int floorMax = (maxMins * 0.4).ceil(); // Stop at 40% of original
    if (floorMax < 5) floorMax = 5;

    if (currentMax <= floorMax) {
      return 'Anytime now';
    }

    int currentMin = currentMax > 5 ? currentMax - 5 : 0;

    return '$currentMin - $currentMax mins';
  }

  Widget _buildProgressBar() {
    return Stack(
      children: [
        // Background track (Gray line connecting nodes)
        Positioned(
          left: 18,
          right: 18,
          top: 20,
          child: Container(height: 3, color: Colors.grey.shade200),
        ),
        // Animated Segments
        Positioned(
          left: 18,
          right: 18,
          top: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double availableWidth = (constraints.maxWidth - 36).clamp(
                0.0,
                double.infinity,
              );
              if (availableWidth <= 0) return const SizedBox.shrink();
              final segmentWidth = availableWidth / 3.0;
              return Row(
                children: [
                  _buildSegment(
                    width: segmentWidth,
                    filled: _currentStatus > 1,
                    isProcessing: _currentStatus == 1,
                  ),
                  _buildSegment(
                    width: segmentWidth,
                    filled: _currentStatus > 2,
                    isProcessing: _currentStatus == 2,
                  ),
                  _buildSegment(
                    width: segmentWidth,
                    filled: _currentStatus > 3,
                    isProcessing: _currentStatus == 3,
                  ),
                ],
              );
            },
          ),
        ),
        // The nodes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepNode(1, PhosphorIcons.packageFill),
            _buildStepNode(2, PhosphorIcons.cookingPotFill),
            _buildStepNode(
              3,
              ActiveOrderState.instance.isPickupFulfillment
                  ? PhosphorIcons.packageFill
                  : PhosphorIcons.mopedFill,
            ),
            _buildStepNode(4, PhosphorIcons.house),
          ],
        ),
      ],
    );
  }

  Widget _buildSegment({
    required double width,
    required bool filled,
    bool isProcessing = false,
  }) {
    return SizedBox(
      width: width,
      height: 3,
      child: Stack(
        children: [
          if (filled)
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (isProcessing)
            AnimatedBuilder(
              animation: _processingController,
              builder: (context, child) {
                return Stack(
                  children: [
                    // Growing fill line
                    Container(
                      width: width * _processingController.value,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.1),
                            AppColors.primary,
                            AppColors.secondary,
                          ],
                        ),
                      ),
                    ),
                    // Moving dot/glow at the tip
                    Positioned(
                      left: width * _processingController.value - 6,
                      top: -1.5,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStepNode(int stepIndex, IconData icon) {
    bool isCompleted = _currentStatus >= stepIndex;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isCompleted ? AppColors.primaryGradient : null,
        color: isCompleted ? null : Colors.grey.shade200,
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          icon,
          size: 20,
          color: isCompleted ? Colors.white : Colors.grey.shade500,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSmallCircleButton(IconData icon, {VoidCallback? onTap}) {
    final button = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: GradientIcon(icon: icon, size: 18),
    );

    if (onTap == null) return button;
    return GestureDetector(onTap: onTap, child: button);
  }

  Future<void> _makeCall(String? phone) async {
    final state = ActiveOrderState.instance;
    final shopId = int.tryParse(state.shopId ?? '');
    
    if (shopId != null && shopId > 0) {
      final shopName = state.displayShopName.isNotEmpty ? state.displayShopName : context.tr('common.restaurant');
      final shopImageUrl = state.shopImageUrl ?? state.logoPath;
      
      final success = await CallSession().initiateCall(
        shopId: shopId,
        shopName: shopName,
        shopImageUrl: shopImageUrl,
      );
      
      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              shopName: shopName,
              shopImageUrl: shopImageUrl,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('order_status.could_not_call'))),
        );
      }
      return;
    }

    final number = phone?.trim() ?? '';
    if (number.isEmpty || number == '-') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('order_status.no_phone_number'))),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('order_status.could_not_call'))),
        );
      }
    }
  }

  /// Parsed integer id of the active order, or null when unavailable.
  int? get _currentOrderId {
    final orderIdStr = ActiveOrderState.instance.orderId?.replaceAll('#', '');
    final orderId = int.tryParse(orderIdStr ?? '');
    return (orderId != null && orderId > 0) ? orderId : null;
  }

  Future<void> _openChat({
    required String? name,
    required String subtitle,
    String? avatarUrl,
    IconData fallbackIcon = Icons.storefront_rounded,
  }) async {
    final orderId = _currentOrderId;
    if (orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('chat.order_unavailable'))),
      );
      return;
    }

    ChatUnreadController.instance.clear(orderId);

    final peerName = (name == null || name.trim().isEmpty) ? subtitle : name;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          orderId: orderId,
          peerName: peerName,
          peerSubtitle: subtitle,
          avatarUrl: avatarUrl,
          fallbackIcon: fallbackIcon,
        ),
      ),
    );
    if (!mounted) return;
    await ChatUnreadController.instance.refreshOrder(orderId);
  }

  Widget _buildNoImageAvatar() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.grey),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    Widget? valueWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppFonts.poppins(
              fontSize: isBold ? 14.5 : 13.5,
              color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          if (valueWidget != null)
            valueWidget
          else
            Text(
              value,
              style: isBold
                  ? GoogleFonts.poppins(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? const Color(0xFF0F172A),
                    )
                  : GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? const Color(0xFF1E293B),
                    ),
            ),
        ],
      ),
    );
  }

  String _statusDescription(BuildContext context, String storeName) {
    if (ActiveOrderState.instance.isPickupFulfillment) {
      if (ActiveOrderState.instance.isReadyForPickup) {
        return context.tr('order_status.pickup_qr_subtitle');
      }
      if (_isVerifiedShop && _currentStatus == 1) {
        return _isPaymentVerified
            ? context.tr('order.status.payment_verified')
            : context.tr('order.status.waiting_payment');
      }
      final key = switch (_currentStatus) {
        1 => 'order_status.checking_payment_shop',
        2 => _backendStatus?.toUpperCase() == 'COOKING' ? 'order_status.cooking_now_shop' : 'order_status.preparing_shop',
        _ => 'order_status.picked_up',
      };
      return context.trArgs(key, {'shop': storeName});
    }
    if (_isVerifiedShop && _currentStatus == 1) {
      return _isPaymentVerified
          ? context.tr('order.status.payment_verified')
          : context.tr('order.status.waiting_payment');
    }
    final key = switch (_currentStatus) {
      1 => 'order_status.checking_payment_shop',
      2 => _backendStatus?.toUpperCase() == 'COOKING' ? 'order_status.cooking_now_shop' : 'order_status.preparing_shop',
      3 => 'order_status.delivering_shop',
      _ => 'order_status.completing_shop',
    };
    return context.trArgs(key, {'shop': storeName});
  }

  void _showDeliveryFeeModal(double delivery) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const GradientIcon(icon: PhosphorIcons.mopedFill, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('order_status.delivery_fee'),
              style: AppFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            GradientText(
              delivery.toFormattedPrice(),
              style: AppFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(25),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'OK',
                  style: AppFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double dashHeight = 4;
    const double dashSpace = 4;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, (startY + dashHeight).clamp(0, size.height)),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
