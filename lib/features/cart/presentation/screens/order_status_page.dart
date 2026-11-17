import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/notifications/notification_service.dart';
import 'dart:async';
import 'dart:math' as math;
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/presentation/widgets/gradient_icon.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/network/api_client.dart';
import 'package:dio/dio.dart';
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
import '../../../home/presentation/widgets/my_together_verified_badge.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../chat/presentation/screens/chat_page.dart';
import '../../../chat/data/services/chat_unread_controller.dart';
import '../../../chat/presentation/widgets/chat_unread_badge.dart';
import '../../../chat/presentation/widgets/chat_shake_animator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/pickup_order_qr_card.dart';
import '../widgets/order_payment_bottom_sheet.dart';
import '../../../../app.dart';
import 'package:mytogetherapp/features/call/presentation/screens/call_screen.dart';
import '../../../call/data/call_session.dart';
import '../widgets/food_game/food_game_banner.dart';
import '../../../home/data/shop_storage.dart';
import '../../../../core/utils/image_utils.dart';
import '../../data/cart_manager.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';

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
  static final Set<String> _shownDeliveryFeeOrderIds = {};
  bool _isPaymentSheetShowing = false;

  static void _markDeliveryFeeShown(String orderId) {
    final cleanId = orderId.replaceAll('#', '').trim();
    if (cleanId.isEmpty) return;
    _shownDeliveryFeeOrderIds.add(cleanId);
    _shownDeliveryFeeOrderIds.add(orderId);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('shown_delivery_fee_$cleanId', true);
    }).catchError((_) {});
  }

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
  BitmapDescriptor? _bikeIcon;
  LatLng? _animatedBikeLocation;
  double _bikeHeading = 0.0;
  Timer? _riderAnimTimer;
  Timer? _deliveryCountdownTimer;
  bool _isFetchingRoute = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  late AnimationController _processingController;

  WebViewController? _webController;
  bool _webViewError = false;
  String? _lastInitedUrl;
  bool _isFullScreenTracking = false;

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

  Future<void> _ensureShopLogo() async {
    final state = ActiveOrderState.instance;
    final hasLogo = (state.logoPath != null && state.logoPath!.trim().isNotEmpty) ||
        (state.shopLogo != null && state.shopLogo!.trim().isNotEmpty) ||
        (state.shopImageUrl != null && state.shopImageUrl!.trim().isNotEmpty);
    if (hasLogo) return;

    final rawShopId = state.restaurantId ?? state.shopId;
    final cleanId = rawShopId?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final id = int.tryParse(cleanId);

    if (id != null && id > 0) {
      try {
        final cachedShop = await ShopStorage.getShop(id);
        if (cachedShop != null) {
          final logo = ShopImageResolver.resolveShopAvatarFromJson(cachedShop) ??
              cachedShop['logoUrl']?.toString() ??
              cachedShop['coverUrl']?.toString();
          if (logo != null && logo.isNotEmpty) {
            final fullUrl = FileUrlUtil.resolve(logo);
            if (mounted) {
              setState(() {
                state.logoPath = fullUrl;
                state.shopLogo = fullUrl;
                state.shopImageUrl = fullUrl;
              });
              _rebuildShopMarker();
              return;
            }
          }
        }

        final restaurant = await RestaurantRepository.instance.getShopById(id);
        final resolved = restaurant.logoPath.isNotEmpty
            ? restaurant.logoPath
            : restaurant.imagePath;
        if (resolved.isNotEmpty && mounted) {
          final fullUrl = FileUrlUtil.resolve(resolved);
          if (mounted) {
            setState(() {
              state.logoPath = fullUrl;
              state.shopLogo = fullUrl;
              state.shopImageUrl = fullUrl;
            });
            _rebuildShopMarker();
            return;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('order_status_page.dart: _ensureShopLogo error: $e');
      }
    }

    // Fallback: match shop from CartManager if shopId is not available
    final name = (state.storeName ?? state.restaurantName)?.trim().toLowerCase();
    if (name != null && name.isNotEmpty && name != 'shop') {
      for (final store in CartManager.instance.stores) {
        if (store.name.trim().toLowerCase() == name ||
            store.nameKey.trim().toLowerCase() == name) {
          if (store.shopImageUrl != null && store.shopImageUrl!.isNotEmpty) {
            final fullUrl = FileUrlUtil.resolve(store.shopImageUrl!);
            if (mounted) {
              setState(() {
                state.logoPath = fullUrl;
                state.shopLogo = fullUrl;
                state.shopImageUrl = fullUrl;
                if (store.shopId != null) {
                  state.restaurantId = store.shopId.toString();
                  state.shopId = store.shopId.toString();
                }
              });
              _rebuildShopMarker();
              return;
            }
          }
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    OrderStatusPage.isCurrentlyVisible = true;
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      ActiveOrderState.instance.focusOrder(widget.orderId!);
    }
    final initialOrderIdStr = widget.orderId ?? ActiveOrderState.instance.orderId;
    if (initialOrderIdStr != null && initialOrderIdStr.isNotEmpty) {
      final clean = initialOrderIdStr.replaceAll('#', '').trim();
      SharedPreferences.getInstance().then((prefs) {
        if (prefs.getBool('shown_delivery_fee_$clean') == true) {
          _shownDeliveryFeeOrderIds.add(clean);
          _shownDeliveryFeeOrderIds.add(initialOrderIdStr);
        }
      }).catchError((_) {});
    }
    _currentStatus = ActiveOrderState.instance.orderStatus.clamp(1, 4);
    _backendStatus = ActiveOrderState.instance.backendStatus;
    _fetchOrderWaitingBanner();
    _ensureShopLogo();

    if ((widget.autoShowPaymentSheet || (_currentStatus == 1 && _isVerifiedShop)) &&
        _isVerifiedShop &&
        !ActiveOrderState.instance.isCodPayment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentStatus == 1 && _isVerifiedShop && !ActiveOrderState.instance.isCodPayment) {
          _openPaymentBottomSheet();
        }
      });
    }

    // Auto-navigate if already completed
    if (ActiveOrderState.instance.orderStatus == 4) {
      Future.delayed(const Duration(seconds: 2), () => _navigateToComplete());
    }

    _buildCustomMarkers().then((_) {
      if (mounted) {
        _fetchRouteIfNeeded();
        _updateMarkers();
        if (_currentStatus >= 3) {
          _syncRealRiderLocation();
        }
      }
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

    _deliveryCountdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _currentStatus == 3) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkRiderNearAlert();
    });

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

          if (_currentStatus >= 3) {
            if (state.riderLocation != null) {
              _animateRiderTo(state.riderLocation!, state.riderHeading);
            } else {
              _updateMarkers();
            }
          } else {
            _updateMarkers();
          }

          // Trigger WebView init if status is 3 and we have a new URL
          if (_currentStatus == 3 &&
              state.deliveryTrackingUrl != null &&
              state.deliveryTrackingUrl!.isNotEmpty &&
              state.deliveryTrackingUrl != _lastInitedUrl) {
            _initWebView(state.deliveryTrackingUrl!);
          }
        });
        _checkRiderNearAlert();
        if (state.routePoints.isEmpty) {
          _fetchRouteIfNeeded();
        }

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
            !state.isPaymentChecking &&
            !state.isCodPayment) {
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
    await ActiveOrderState.instance.syncActiveOrder(
      orderId: widget.orderId ?? ActiveOrderState.instance.orderId,
    );
    if (!mounted) return;
    _ensureShopLogo();
    final state = ActiveOrderState.instance;
    final status = state.orderStatus;
    setState(() => _currentStatus = status.clamp(1, 4));
    _checkRiderNearAlert();

    await _fetchRouteIfNeeded();
    _updateMarkers();
    _fitBounds();

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
    _riderAnimTimer?.cancel();
    _deliveryCountdownTimer?.cancel();
    _mapController?.dispose();
    _sheetController.dispose();
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

  void _goHome() {
    _orderSubscription?.cancel();
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<ui.Image?> _loadNetworkImage(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty || (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://'))) {
      return null;
    }
    try {
      final response = await ApiClient().dio.get<List<int>>(
        cleanUrl,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      if (kDebugMode) debugPrint('order_status_page.dart: _loadNetworkImage failed for $cleanUrl: $e');
      return null;
    }
  }

  void _paintCircularImage(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double radius,
  ) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final scale = math.max(
      (radius * 2) / src.width,
      (radius * 2) / src.height,
    );
    final scaledW = src.width * scale;
    final scaledH = src.height * scale;
    final dst = Rect.fromCenter(
      center: center,
      width: scaledW,
      height: scaledH,
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();
  }

  Future<BitmapDescriptor> _createBikeMarker() async {
    try {
      final byteData = await rootBundle.load('assets/images/delivery_bike.png');
      const double logicalSize = 46.0;
      const double pixelRatio = 2.5;
      final int pixelSize = (logicalSize * pixelRatio).round();

      final codec = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
        targetWidth: pixelSize,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(pixelRatio, pixelRatio);

      // Soft ground shadow for realistic vehicle look on Google Map
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(logicalSize / 2, logicalSize * 0.82),
          width: logicalSize * 0.68,
          height: logicalSize * 0.20,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );

      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final dst = Rect.fromLTWH(2, 2, logicalSize - 4, logicalSize - 4);
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.high);

      final finalImg = await recorder.endRecording().toImage(pixelSize, pixelSize);
      final pngBytes = await finalImg.toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes != null) {
        return BitmapDescriptor.bytes(
          pngBytes.buffer.asUint8List(),
          imagePixelRatio: pixelRatio,
          width: logicalSize,
          height: logicalSize,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error creating bike marker: $e');
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  Future<BitmapDescriptor> _buildShopMarker() async {
    final state = ActiveOrderState.instance;
    final rawLogo = state.logoPath ?? state.shopLogo ?? state.shopImageUrl;
    final logoUrl = (rawLogo != null && rawLogo.trim().isNotEmpty)
        ? FileUrlUtil.resolve(rawLogo.trim())
        : null;
    final shopName = state.displayShopName.isNotEmpty
        ? state.displayShopName
        : 'Restaurant';

    ui.Image? logoImage;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      logoImage = await _loadNetworkImage(logoUrl);
    }

    return _drawShopBubbleMarker(name: shopName, logoImage: logoImage);
  }

  Future<BitmapDescriptor> _drawShopBubbleMarker({
    required String name,
    ui.Image? logoImage,
  }) async {
    const double pixelRatio = 2.5;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio, pixelRatio);

    const double boxHeight = 32.0;
    const double pointerWidth = 10.0;
    const double pointerHeight = 6.0;
    const double dotRadius = 2.5;
    const double logoSize = 22.0;
    const double paddingH = 8.0;
    const double gap = 6.0;
    const double maxTextWidth = 120.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: AppFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxTextWidth);

    final double contentWidth = logoSize + gap + textPainter.width;
    final double boxWidth = contentWidth + paddingH * 2;
    final double totalW = boxWidth;
    final double totalH = boxHeight + pointerHeight + (dotRadius * 2) + 2.0;
    final double centerX = totalW / 2;

    // Shadow for pill
    final pillRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, boxWidth, boxHeight),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      pillRRect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );

    // Pill fill: Clean white background
    canvas.drawRRect(pillRRect, Paint()..color = Colors.white);

    // Pill border: App primary coral
    canvas.drawRRect(
      pillRRect,
      Paint()
        ..color = const Color(0xFFE11D48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Pointer tail
    final pointerPath = Path()
      ..moveTo(centerX - pointerWidth / 2, boxHeight - 0.5)
      ..lineTo(centerX + pointerWidth / 2, boxHeight - 0.5)
      ..lineTo(centerX, boxHeight + pointerHeight)
      ..close();
    canvas.drawPath(pointerPath, Paint()..color = const Color(0xFFE11D48));

    // Pin dot at bottom
    canvas.drawCircle(
      Offset(centerX, boxHeight + pointerHeight + dotRadius),
      dotRadius,
      Paint()..color = const Color(0xFFE11D48),
    );
    canvas.drawCircle(
      Offset(centerX, boxHeight + pointerHeight + dotRadius),
      dotRadius - 1.2,
      Paint()..color = Colors.white,
    );

    // Draw shop logo or initial
    final logoCenter = Offset(paddingH + logoSize / 2, boxHeight / 2);
    if (logoImage != null) {
      canvas.drawCircle(
        logoCenter,
        logoSize / 2 + 0.5,
        Paint()..color = const Color(0xFFE2E8F0),
      );
      _paintCircularImage(canvas, logoImage, logoCenter, logoSize / 2);
    } else {
      // Fallback: Gradient circle with first letter
      final paint = Paint()
        ..shader = AppColors.primaryGradient.createShader(
          Rect.fromCircle(center: logoCenter, radius: logoSize / 2),
        );
      canvas.drawCircle(logoCenter, logoSize / 2, paint);
      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'R';
      final initialPainter = TextPainter(
        text: TextSpan(
          text: initial,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      initialPainter.paint(
        canvas,
        Offset(logoCenter.dx - initialPainter.width / 2, logoCenter.dy - initialPainter.height / 2),
      );
    }

    // Text (Shop Name)
    textPainter.paint(
      canvas,
      Offset(paddingH + logoSize + gap, (boxHeight - textPainter.height) / 2),
    );

    final finalW = (totalW * pixelRatio).ceil();
    final finalH = (totalH * pixelRatio).ceil();
    final img = await recorder.endRecording().toImage(finalW, finalH);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
      width: totalW,
      height: totalH,
    );
  }

  Future<BitmapDescriptor> _buildUserMarker() async {
    final currentUser = AuthService().currentUser;
    final rawAvatar = currentUser?.avatarUrl;
    final avatarUrl = (rawAvatar != null && rawAvatar.trim().isNotEmpty)
        ? FileUrlUtil.resolve(rawAvatar.trim())
        : null;
    final userName = (currentUser?.fullName != null && currentUser!.fullName.trim().isNotEmpty)
        ? currentUser.fullName.trim()
        : (currentUser?.username != null && currentUser!.username.trim().isNotEmpty
            ? currentUser.username.trim()
            : 'Customer');

    ui.Image? userImage;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      userImage = await _loadNetworkImage(avatarUrl);
    }

    return _drawUserMarker(userName: userName, userImage: userImage);
  }

  Future<BitmapDescriptor> _drawUserMarker({
    required String userName,
    ui.Image? userImage,
  }) async {
    const double pixelRatio = 2.5;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio, pixelRatio);

    const double pillHeight = 20.0;
    const double avatarRadius = 16.0;
    const double dotRadius = 2.5;
    const double maxTextWidth = 110.0;
    const double spacing = 3.0;

    final displayName = userName.isNotEmpty ? userName : 'Customer';
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: '📍 ',
            style: TextStyle(fontSize: 10),
          ),
          TextSpan(
            text: displayName,
            style: AppFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxTextWidth);

    final double pillWidth = textPainter.width + 14.0;
    final double avatarDiameter = avatarRadius * 2;
    final double totalW = math.max(pillWidth, avatarDiameter + 12.0);
    final double totalH = pillHeight + spacing + avatarDiameter + spacing + (dotRadius * 2) + 2.0;
    final double centerX = totalW / 2;

    // 1. Top Pill: [ 📍 Name ]
    final pillRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, pillHeight / 2),
        width: pillWidth,
        height: pillHeight,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      pillRRect.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawRRect(pillRRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      pillRRect,
      Paint()
        ..color = const Color(0xFFE11D48) // App primary coral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, (pillHeight - textPainter.height) / 2),
    );

    // 2. Avatar Circle (Brand Primary Gradient & White Ring)
    final avatarCenter = Offset(centerX, pillHeight + spacing + avatarRadius);
    canvas.drawCircle(
      avatarCenter.translate(0, 2),
      avatarRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      avatarCenter,
      avatarRadius + 2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      avatarCenter,
      avatarRadius + 2,
      Paint()
        ..color = const Color(0xFFE11D48) // App primary coral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    if (userImage != null) {
      _paintCircularImage(canvas, userImage, avatarCenter, avatarRadius);
    } else {
      // Fallback: stylish initial avatar with AppColors.primaryGradient
      final avatarPaint = Paint()
        ..shader = AppColors.primaryGradient.createShader(
          Rect.fromCircle(center: avatarCenter, radius: avatarRadius),
        );
      canvas.drawCircle(avatarCenter, avatarRadius, avatarPaint);

      final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
      final initialPainter = TextPainter(
        text: TextSpan(
          text: initial,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      initialPainter.paint(
        canvas,
        Offset(avatarCenter.dx - initialPainter.width / 2, avatarCenter.dy - initialPainter.height / 2),
      );
    }

    // 3. Pin dot at the bottom with primary coral
    final dotCenter = Offset(centerX, totalH - dotRadius - 1);
    canvas.drawCircle(dotCenter, dotRadius, Paint()..color = const Color(0xFFE11D48));
    canvas.drawCircle(dotCenter, dotRadius - 1.2, Paint()..color = Colors.white);

    final finalW = (totalW * pixelRatio).ceil();
    final finalH = (totalH * pixelRatio).ceil();
    final img = await recorder.endRecording().toImage(finalW, finalH);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
      width: totalW,
      height: totalH,
    );
  }

  Future<void> _rebuildShopMarker() async {
    final icon = await _buildShopMarker();
    if (mounted) {
      setState(() {
        _shopIcon = icon;
      });
      _updateMarkers();
    }
  }

  Future<void> _rebuildUserMarker() async {
    final icon = await _buildUserMarker();
    if (mounted) {
      setState(() {
        _homeIcon = icon;
      });
      _updateMarkers();
    }
  }

  Future<void> _buildCustomMarkers() async {
    final bikeFuture = _createBikeMarker();
    final shopFuture = _buildShopMarker();
    final userFuture = _buildUserMarker();

    final results = await Future.wait([bikeFuture, shopFuture, userFuture]);
    if (mounted) {
      setState(() {
        _bikeIcon = results[0];
        _shopIcon = results[1];
        _homeIcon = results[2];
      });
      _updateMarkers();
    }
  }

  Future<BitmapDescriptor> _drawMarkerBitmap({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    double size = 75,
    bool isBike = false,
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

    // Signature MyTogether primary gradient fill for all map markers
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
    if (data == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      imagePixelRatio: 2.0,
      width: size / 2.0,
      height: size / 2.0,
    );
  }

  LatLng? _resolveShopLatLng() {
    final state = ActiveOrderState.instance;
    if (state.restaurantLatLng != null && state.restaurantLatLng!.latitude != 0) {
      return state.restaurantLatLng;
    }
    final order = state.getOrder(widget.orderId ?? state.orderId);
    if (order?.restaurantLatLng != null && order!.restaurantLatLng!.latitude != 0) {
      return order.restaurantLatLng;
    }
    return const LatLng(13.7600, 100.5050);
  }

  LatLng? _resolveUserLatLng() {
    final state = ActiveOrderState.instance;
    if (state.userLocation != null && state.userLocation!.latitude != 0) {
      return state.userLocation;
    }
    final order = state.getOrder(widget.orderId ?? state.orderId);
    if (order?.userLocation != null && order!.userLocation!.latitude != 0) {
      return order.userLocation;
    }
    return const LatLng(13.7563, 100.5018);
  }

  Future<void> _fetchRouteIfNeeded() async {
    if (_isFetchingRoute) return;
    final state = ActiveOrderState.instance;

    final shopId = int.tryParse(state.shopId ?? '');
    if ((state.restaurantLatLng == null || state.restaurantLatLng!.latitude == 0) && shopId != null) {
      try {
        final cached = await ShopStorage.getShop(shopId);
        if (cached != null) {
          final lat = (cached['latitude'] ?? cached['lat']) as num?;
          final lon = (cached['longitude'] ?? cached['lon'] ?? cached['lng']) as num?;
          if (lat != null && lon != null && lat != 0 && lon != 0) {
            state.restaurantLatLng = LatLng(lat.toDouble(), lon.toDouble());
          }
        }
      } catch (_) {}
    }

    final shopPos = state.restaurantLatLng ?? _resolveShopLatLng();
    final userPos = state.userLocation ?? _resolveUserLatLng();

    if (shopPos == null || userPos == null) return;

    if (state.routePoints.isNotEmpty) {
      if (state.routeDurationMins == null || state.routeDurationMins! <= 0) {
        final distanceM = Geolocator.distanceBetween(
          shopPos.latitude,
          shopPos.longitude,
          userPos.latitude,
          userPos.longitude,
        );
        final km = distanceM / 1000.0;
        final mins = (km * 2.5 + 2).ceil().clamp(3, 30);
        state.routeDurationMins = mins;
        state.routeDistanceKm = km;
      }
      _updateMarkers();
      return;
    }

    _isFetchingRoute = true;
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${shopPos.longitude},${shopPos.latitude};${userPos.longitude},${userPos.latitude}?geometries=geojson';
      final response = await ApiClient().dio.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['routes'] != null &&
          (response.data['routes'] as List).isNotEmpty) {
        final route = response.data['routes'][0];
        final List coords = route['geometry']['coordinates'];
        final double distanceM = (route['distance'] as num).toDouble();
        final double durationS = (route['duration'] as num).toDouble();

        final List<LatLng> points = coords
            .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();

        final polyPoints = [shopPos, ...points, userPos];
        final km = distanceM / 1000.0;
        final mins = (durationS / 60.0).ceil().clamp(2, 35);

        state.updateRouteData(
          points: polyPoints,
          distanceKm: km,
          durationMins: mins,
          fee: state.deliveryFee ?? 0,
        );
        state.routeDurationMins = mins;
        state.routeDistanceKm = km;

        if (mounted) {
          _updateMarkers();
          _fitBounds();
          if (_currentStatus >= 3) {
            _syncRealRiderLocation();
          }
        }
      } else {
        _setFallbackRoute(shopPos, userPos);
      }
    } catch (e) {
      debugPrint('OrderStatusPage: OSRM route fetch error, using fallback: $e');
      _setFallbackRoute(shopPos, userPos);
    } finally {
      _isFetchingRoute = false;
    }
  }

  void _setFallbackRoute(LatLng shopPos, LatLng userPos) {
    final state = ActiveOrderState.instance;
    final fallbackPoints = [shopPos, userPos];
    final distanceM = Geolocator.distanceBetween(
      shopPos.latitude,
      shopPos.longitude,
      userPos.latitude,
      userPos.longitude,
    );
    final km = distanceM / 1000.0;
    final mins = (km * 2.5 + 2).ceil().clamp(3, 30);

    state.updateRouteData(
      points: fallbackPoints,
      distanceKm: km,
      durationMins: mins,
      fee: state.deliveryFee ?? 0,
    );
    state.routeDurationMins = mins;
    state.routeDistanceKm = km;

    if (mounted) {
      _updateMarkers();
      _fitBounds();
      if (_currentStatus >= 3) {
        _syncRealRiderLocation();
      }
    }
  }

  void _animateRiderTo(LatLng target, double? newHeading) {
    _riderAnimTimer?.cancel();
    if (_animatedBikeLocation == null) {
      _animatedBikeLocation = target;
      if (newHeading != null && newHeading != 0) _bikeHeading = newHeading;
      _updateMarkers();
      return;
    }

    final from = _animatedBikeLocation!;
    if (from.latitude == target.latitude && from.longitude == target.longitude) {
      if (newHeading != null && newHeading != 0) {
        _bikeHeading = newHeading;
        _updateMarkers();
      }
      return;
    }

    if (newHeading != null && newHeading != 0) {
      _bikeHeading = newHeading;
    } else {
      final dLon = (target.longitude - from.longitude) * (math.pi / 180.0);
      final lat1 = from.latitude * (math.pi / 180.0);
      final lat2 = target.latitude * (math.pi / 180.0);
      final y = math.sin(dLon) * math.cos(lat2);
      final x = math.cos(lat1) * math.sin(lat2) -
          math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
      final radians = math.atan2(y, x);
      _bikeHeading = ((radians * 180.0 / math.pi) + 360.0) % 360.0;
    }

    const int totalSteps = 10;
    int step = 0;
    _riderAnimTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      step++;
      final t = step / totalSteps;
      final curLat = from.latitude + (target.latitude - from.latitude) * t;
      final curLng = from.longitude + (target.longitude - from.longitude) * t;
      setState(() {
        _animatedBikeLocation = LatLng(curLat, curLng);
        _updateMarkers();
      });
      if (step >= totalSteps) {
        timer.cancel();
      }
    });
  }

  void _updateMarkers() {
    final state = ActiveOrderState.instance;
    final sets = <Marker>{};

    // 1. Restaurant Marker
    final shopPos = state.restaurantLatLng ?? _resolveShopLatLng();
    if (shopPos != null && shopPos.latitude != 0) {
      sets.add(
        Marker(
          markerId: const MarkerId('restaurant'),
          position: shopPos,
          icon: _shopIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 5,
          infoWindow: InfoWindow(
            title: state.displayShopName.isNotEmpty ? state.displayShopName : 'Restaurant',
          ),
        ),
      );
    }

    // 2. User Destination Marker
    final userPos = state.userLocation ?? _resolveUserLatLng();
    if (userPos != null && userPos.latitude != 0) {
      sets.add(
        Marker(
          markerId: const MarkerId('user'),
          position: userPos,
          icon: _homeIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 5,
          infoWindow: InfoWindow(
            title: 'Your Delivery Location',
            snippet: state.deliveryAddress,
          ),
        ),
      );
    }

    // 3. Motorbike Rider Marker (Only when status >= 3 and REAL GPS rider location exists)
    final LatLng? riderPos = state.riderLocation ?? _animatedBikeLocation;

    if (_isVerifiedShop &&
        state.isLalamoveDelivery &&
        riderPos != null &&
        riderPos.latitude != 0 &&
        _currentStatus >= 3) {
      sets.add(
        Marker(
          markerId: const MarkerId('rider_bike'),
          position: riderPos,
          icon: _bikeIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          rotation: state.riderHeading ?? _bikeHeading,
          flat: true,
          zIndexInt: 15,
          infoWindow: InfoWindow(
            title: state.riderName ?? '${state.displayDeliveryProvider} Delivery Rider',
            snippet: state.riderVehicleNumber ?? 'Motorcycle',
          ),
        ),
      );
    }

    // 4. Polylines
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

  void _syncRealRiderLocation() {
    final state = ActiveOrderState.instance;
    // Only verified shops with Lalamove real rider GPS tracking
    if (!_isVerifiedShop || state.isOwnFleetDelivery || !state.isLalamoveDelivery) {
      return;
    }
    if (state.riderLocation != null) {
      _animatedBikeLocation = state.riderLocation;
      if (state.riderHeading != null) {
        _bikeHeading = state.riderHeading!;
      }
      _updateMarkers();
    }
  }

  // ignore: unused_element
  void _fitBounds() {
    if (_mapController == null) return;
    final state = ActiveOrderState.instance;
    final shopPos = state.restaurantLatLng ?? _resolveShopLatLng();
    final userPos = state.userLocation ?? _resolveUserLatLng();
    final LatLng? riderPos = state.riderLocation ?? _animatedBikeLocation;
    final all = [
      if (shopPos != null && shopPos.latitude != 0) shopPos,
      if (userPos != null && userPos.latitude != 0) userPos,
      if (riderPos != null && riderPos.latitude != 0) riderPos,
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

    if (minLat == maxLat && minLng == maxLng) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 15.0),
      );
      return;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
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
    final currentOrderIdStr = widget.orderId ?? state.orderId;
    final cleanOrderId = currentOrderIdStr?.replaceAll('#', '').trim() ?? '';
    final bool alreadyShownDeliveryFee = cleanOrderId.isNotEmpty &&
        (_shownDeliveryFeeOrderIds.contains(cleanOrderId) ||
            (currentOrderIdStr != null && _shownDeliveryFeeOrderIds.contains(currentOrderIdStr)));

    if (showFlexibleDeliveryFee && delivery > 0 && !alreadyShownDeliveryFee) {
      if (cleanOrderId.isNotEmpty) {
        _markDeliveryFeeShown(cleanOrderId);
      }
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

    // Grab / Foodpanda Signature Live Tracking Layout when Order is ON THE WAY (Stage 3):
    // 1. Live Map Screen (_buildGrabStyleLiveTrackingScreen):
    //    - If order has a tracking URL (hasTrackingUrl)
    //    - OR if Verified Shop with courier delivery (!isOwnDriver)
    // 2. Full-Screen Status Screen without Map (_buildFullScreenDeliveryStatusScreen):
    //    - If Verified Shop with their own driver and no tracking URL (isOwnDriver && !hasTrackingUrl)
    // 3. Fallback to Standard Stepper Layout:
    //    - Only for Unverified Shop orders without any tracking link (previous version UI)
    if (_currentStatus >= 3 && !state.isPickupFulfillment && _currentStatus != -1) {
      final bool hasTrackingUrl = state.deliveryTrackingUrl != null &&
          state.deliveryTrackingUrl!.trim().isNotEmpty;
      final bool isOwnDriver = state.isOwnFleetDelivery;

      if (hasTrackingUrl || (_isVerifiedShop && !isOwnDriver)) {
        return _buildGrabStyleLiveTrackingScreen(context, state, storeName, total, delivery);
      } else if (_isVerifiedShop && isOwnDriver) {
        return _buildFullScreenDeliveryStatusScreen(context, state, storeName, total, delivery);
      }
    }

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
            Builder(
              builder: (context) {
                final raw = state.logoPath ?? state.shopLogo ?? state.shopImageUrl;
                final resolved = (raw != null && raw.trim().isNotEmpty)
                    ? FileUrlUtil.resolve(raw.trim())
                    : '';
                return ClipOval(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: resolved.isNotEmpty
                        ? CachedNetworkImage(
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            imageUrl: resolved,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: CustomLoadingIndicator(size: 16),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildStoreFallbackLogo(),
                          )
                        : _buildStoreFallbackLogo(),
                  ),
                );
              },
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
                          key: ValueKey<String>('${_currentStatus}_$_backendStatus'),
                          style: AppFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEF4444),
                          ),
                        )
                      : GradientText(
                          _statusTitle(context),
                          key: ValueKey<String>('${_currentStatus}_$_backendStatus'),
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
                    if (_isRiderNearby)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                        ),
                        child: Text(
                          '🛵 ပို့ဆောင်သူ အနီးသို့ ရောက်ရှိနေပါပြီ ($_deliveryRemainingMinutes mins အတွင်း ရောက်ပါမည်)',
                          style: AppFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      )
                    else if (_currentStatus == 3 &&
                        (state.deliveryTrackingUrl == null ||
                            state.deliveryTrackingUrl!.trim().isEmpty))
                      GradientText(
                        '${context.tr('order_status.est_waiting_time')}: ~$_deliveryRemainingMinutes mins',
                        style: AppFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (state.hasPrepTimeEstimate)
                      GradientText(
                        '${context.tr('order_status.est_waiting_time')}: ${TimeFormatter.normalizeDisplay(state.estimatedTime!)}',
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

                if (!hasTrackingUrl && !_isVerifiedShop) {
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
                          if (_isVerifiedShop)
                            RepaintBoundary(
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: state.restaurantLatLng ??
                                      _resolveShopLatLng() ??
                                      state.userLocation ??
                                      _resolveUserLatLng() ??
                                      const LatLng(13.7563, 100.5018),
                                  zoom: 14.5,
                                ),
                                markers: _markers,
                                polylines: _polylines,
                                onMapCreated: (controller) {
                                  _mapController = controller;
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    if (mounted) {
                                      _fetchRouteIfNeeded();
                                      _fitBounds();
                                    }
                                  });
                                },
                                myLocationEnabled: false,
                                zoomControlsEnabled: false,
                                mapToolbarEnabled: false,
                                compassEnabled: false,
                              ),
                            )
                          else if (_webController != null && !_webViewError)
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
                          if (_isVerifiedShop)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: FloatingActionButton.small(
                                heroTag: 'map_recenter_btn',
                                backgroundColor: Colors.white,
                                elevation: 3,
                                onPressed: _fitBounds,
                                child: const Icon(
                                  Icons.my_location_rounded,
                                  color: Colors.black87,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (hasTrackingUrl) ...[
                      const SizedBox(height: 12),
                      PrimaryGradientButton(
                        height: 48,
                        onPressed: () {
                          if (state.deliveryTrackingUrl != null) {
                            _openTrackingUrl(state.deliveryTrackingUrl!);
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
                              'Track Order with ${state.displayDeliveryProvider}',
                              style: AppFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                );
              })(),
            ),

            // Rider Info Card (ONLY for verified shops without external tracking link when status >= 3)
            if (_currentStatus >= 3 &&
                _isVerifiedShop &&
                (state.deliveryTrackingUrl == null ||
                    state.deliveryTrackingUrl!.trim().isEmpty) &&
                !state.isPickupFulfillment) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isVerifiedShop)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(PhosphorIcons.moped, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    state.displayDeliveryProvider,
                                    style: AppFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          ClipOval(
                            child: Container(
                              width: 46,
                              height: 46,
                              color: Colors.grey[100],
                              child: state.riderProfileUrl != null && state.riderProfileUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      memCacheWidth: 132,
                                      fadeInDuration: Duration.zero,
                                      fadeOutDuration: Duration.zero,
                                      imageUrl: FileUrlUtil.resolve(state.riderProfileUrl!),
                                      width: 46,
                                      height: 46,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => const Icon(
                                        Icons.person,
                                        size: 24,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                                  child: Text(
                                    (state.riderName != null && state.riderName!.trim().isNotEmpty)
                                        ? state.riderName!
                                        : 'Assigning ${state.displayDeliveryProvider} Courier...',
                                    style: AppFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white, // required for ShaderMask
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (state.riderPhone != null && state.riderPhone!.trim().isNotEmpty) ...[
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
                                    if (state.riderVehicleNumber != null && state.riderVehicleNumber!.trim().isNotEmpty) ...[
                                      if (state.riderPhone != null && state.riderPhone!.trim().isNotEmpty)
                                        Text('  •  ', style: TextStyle(color: Colors.grey[400])),
                                      Text(
                                        state.riderVehicleNumber!,
                                        style: AppFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                    if (state.riderName == null && _isVerifiedShop)
                                      Text(
                                        'Connecting with nearby rider...',
                                        style: AppFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (state.riderPhone != null && state.riderPhone!.trim().isNotEmpty) ...[
                            GestureDetector(
                              onTap: () => _callRider(state.riderPhone),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  PhosphorIcons.phoneCallFill,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
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
                                color: state.isCodPayment ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: state.isCodPayment ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    state.isCodPayment
                                        ? PhosphorIcons.money
                                        : (state.getOrder(state.orderId)?.preferredOmiseMethod == 'TRUEMONEY' ||
                                                (state.paymentMethod?.toUpperCase().contains('TRUEMONEY') ?? false))
                                            ? PhosphorIcons.wallet
                                            : PhosphorIcons.qrCode,
                                    size: 15,
                                    color: state.isCodPayment ? const Color(0xFF059669) : const Color(0xFF1E3A8A),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    state.isCodPayment
                                        ? 'Cash on Delivery'
                                        : (state.getOrder(state.orderId)?.preferredOmiseMethod == 'TRUEMONEY' ||
                                                (state.paymentMethod?.toUpperCase().contains('TRUEMONEY') ?? false))
                                            ? 'TrueMoney Wallet'
                                            : context.tr('order_status.qr_promptpay'),
                                    style: AppFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: state.isCodPayment ? const Color(0xFF065F46) : const Color(0xFF1E293B),
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
                                  style: AppFonts.poppins(
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
                                                style: AppFonts.poppins(
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
                                    style: AppFonts.poppins(
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
                                          style: AppFonts.poppins(
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
            if (ActiveOrderState.instance.isCodPayment) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFECFDF5),
                  border: Border.all(
                    color: const Color(0xFFA7F3D0),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          PhosphorIconsFill.money,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Cash on Delivery (COD)',
                                style: AppFonts.poppins(
                                  color: const Color(0xFF065F46),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ငွေသား',
                                  style: AppFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'ပို့ဆောင်သူ ရောက်ရှိချိန်တွင် ငွေသား ฿${(ActiveOrderState.instance.totalAmount ?? (widget.foodTotal + widget.deliveryFee)).toStringAsFixed(0)} အတိ ပေးချေပေးပါရန်',
                            style: AppFonts.poppins(
                              color: const Color(0xFF047857),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ] else if (_currentStatus == 1 && _isVerifiedShop && !_isPaymentVerified) ...[
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
                                                style: AppFonts.poppins(
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
                                          _isVerifiedShop
                                              ? 'PromptPay • TrueMoney • Slip'
                                              : 'Bank Transfer • ငွေလွှဲစလစ်တင်ရန်',
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
                                          style: AppFonts.poppins(
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

  /// Calculates remaining minutes for delivery using live GPS distance, backend ETA, or routing.
  int get _deliveryRemainingMinutes {
    final state = ActiveOrderState.instance;

    // 1. If backend or WebSocket pushed remaining minutes directly
    if (state.riderRemainingMins != null && state.riderRemainingMins! > 0) {
      return state.riderRemainingMins!.clamp(1, 40);
    }

    // 2. Real-time GPS distance calculation between Rider and Customer (if rider GPS position exists)
    final LatLng? riderPos = state.riderLocation ?? _animatedBikeLocation;
    final LatLng? userPos = state.userLocation;
    if (riderPos != null &&
        riderPos.latitude != 0 &&
        riderPos.longitude != 0 &&
        userPos != null &&
        userPos.latitude != 0 &&
        userPos.longitude != 0) {
      final meters = Geolocator.distanceBetween(
        riderPos.latitude,
        riderPos.longitude,
        userPos.latitude,
        userPos.longitude,
      );
      final km = meters / 1000.0;
      // ~2.5 mins per km in city motorcycle delivery
      final mins = (km * 2.5).ceil();
      return mins.clamp(1, 35);
    }

    // 3. Calculated route duration between shop and customer (from OSRM routing)
    if (state.routeDurationMins != null && state.routeDurationMins! > 0) {
      return state.routeDurationMins!.clamp(2, 35);
    }

    // 4. If routeDistanceKm is known from quote or backend
    if (state.routeDistanceKm != null && state.routeDistanceKm! > 0) {
      final mins = (state.routeDistanceKm! * 2.5 + 2).ceil();
      return mins.clamp(3, 30);
    }

    // 5. Calculated distance between Restaurant and Customer (using real locations)
    final shopPos = state.restaurantLatLng;
    if (shopPos != null &&
        shopPos.latitude != 0 &&
        shopPos.longitude != 0 &&
        userPos != null &&
        userPos.latitude != 0 &&
        userPos.longitude != 0) {
      final meters = Geolocator.distanceBetween(
        shopPos.latitude,
        shopPos.longitude,
        userPos.latitude,
        userPos.longitude,
      );
      final km = meters / 1000.0;
      if (km > 0.05 && km < 100) {
        final mins = (km * 2.5 + 2).ceil();
        return mins.clamp(3, 30);
      }
    }

    // 6. Sensible fallback for motorcycle delivery when food is already ON THE WAY.
    // Note: state.estimatedTime is TOTAL prep + wait time (e.g. 44 mins), which has
    // already elapsed. Driving time in city delivery is typically 8–15 mins.
    final match = RegExp(r'(\d+)').firstMatch(state.estimatedTime ?? '');
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0) {
        // If parsed value is <= 20, it is already delivery duration
        if (parsed <= 20) return parsed.clamp(3, 20);
        // If it's a large prep/total time (e.g. 40-45 mins), delivery is typically ~25-30% of total
        final deliveryPortion = (parsed * 0.28).round();
        return deliveryPortion.clamp(8, 18);
      }
    }

    return 12; // Standard urban delivery default: ~12 mins
  }

  /// True when order is delivering and rider is within 3 minutes of reaching customer.
  /// (Strictly for verified shops with real Lalamove GPS tracking; unverified shops or own driver deliveries never show this dummy alert)
  bool get _isRiderNearby {
    if (_currentStatus < 3 || _currentStatus >= 4) return false;
    final state = ActiveOrderState.instance;
    final bool hasTrackingUrl = state.deliveryTrackingUrl != null &&
        state.deliveryTrackingUrl!.trim().isNotEmpty;
    // Never show rider nearby alert for unverified shops, tracking link state, or own driver deliveries
    if (!_isVerifiedShop || state.isOwnFleetDelivery || !state.isLalamoveDelivery || hasTrackingUrl) {
      return false;
    }
    if (state.isRiderNear) return true;
    if (state.riderLocation == null) return false;
    return _deliveryRemainingMinutes <= 3;
  }

  /// Triggers haptic buzz and local alert notification once when rider first enters near distance.
  void _checkRiderNearAlert() {
    if (!mounted || !_isRiderNearby) return;
    if (!_isVerifiedShop) return;
    final state = ActiveOrderState.instance;
    if (state.isOwnFleetDelivery || !state.isLalamoveDelivery) return;
    if (state.hasAlertedRiderNear) return;
    state.hasAlertedRiderNear = true;

    // Haptic buzz alert
    HapticFeedback.heavyImpact();

    // Trigger local push notification alert
    final orderId = int.tryParse(state.orderId ?? '') ?? 0;
    final mins = _deliveryRemainingMinutes;
    NotificationService().showRiderNearbyNotification(
      orderId: orderId,
      title: 'ပို့ဆောင်သူ သင့်အနီးသို့ ရောက်ရှိနေပါပြီ 🛵',
      body: 'သင့်တည်နေရာသို့ မကြာမီ ($mins မိနစ်ခန့်အတွင်း) ရောက်ရှိပါတော့မည်။ ကျေးဇူးပြု၍ အော်ဒါလက်ခံရန် အဆင်သင့်ရှိပေးပါ။',
    );
  }

  Widget _buildRiderNearbyAlertCard() {
    final mins = _deliveryRemainingMinutes;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                PhosphorIcons.mopedBold,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ပို့ဆောင်သူ အနီးသို့ ရောက်ရှိနေပါပြီ!',
                      style: AppFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                      ),
                      child: Text(
                        '<$mins mins',
                        style: AppFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'သင့်တည်နေရာသို့ မကြာမီ ရောက်ရှိပါတော့မည်။ ကျေးဇူးပြု၍ အော်ဒါလက်ခံရန် အဆင်သင့်ရှိပေးပါ။',
                  style: AppFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Stack(
      clipBehavior: Clip.none,
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
    final isCompleted = _currentStatus >= stepIndex;

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

  Future<void> _callRider(String? phone) async {
    final raw = (phone ?? ActiveOrderState.instance.riderPhone)?.trim();
    if (raw == null || raw.isEmpty || raw == '-') {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('order_status.no_phone_number'),
          gradient: AppColors.primaryGradient,
          icon: Icons.phone_disabled_rounded,
        );
      }
      return;
    }
    final cleanPhone = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('order_status.could_not_call'),
          gradient: AppColors.primaryGradient,
          icon: Icons.phone_missed_rounded,
        );
      }
    }
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
        // Fallback to phone dialer if in-app VoIP call could not connect
        final fallbackNumber = (phone?.trim().isNotEmpty == true ? phone : state.shopPhone)?.trim() ?? '';
        final cleanPhone = fallbackNumber.replaceAll(RegExp(r'[^\d+]'), '');
        if (cleanPhone.isNotEmpty) {
          final uri = Uri(scheme: 'tel', path: cleanPhone);
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          } catch (_) {}
        }
        AppDialog.showToast(
          context,
          context.tr('order_status.could_not_call'),
          gradient: AppColors.primaryGradient,
          icon: Icons.phone_missed_rounded,
        );
      }
      return;
    }

    final number = phone?.trim() ?? '';
    final cleanPhone = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('order_status.no_phone_number'),
          gradient: AppColors.primaryGradient,
          icon: Icons.phone_disabled_rounded,
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('order_status.could_not_call'),
          gradient: AppColors.primaryGradient,
          icon: Icons.phone_missed_rounded,
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
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('chat.order_unavailable'),
          gradient: AppColors.primaryGradient,
          icon: Icons.chat_bubble_outline_rounded,
        );
      }
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
                  ? AppFonts.poppins(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? const Color(0xFF0F172A),
                    )
                  : AppFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? const Color(0xFF1E293B),
                    ),
            ),
        ],
      ),
    );
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

  // -------------------------------------------------------------
  // Grab & Foodpanda Signature Professional Live Tracking Screen
  // -------------------------------------------------------------
  Widget _buildGrabStyleLiveTrackingScreen(
    BuildContext context,
    ActiveOrderState state,
    String storeName,
    double total,
    double delivery,
  ) {
    final bool hasTrackingUrl =
        state.deliveryTrackingUrl != null &&
        state.deliveryTrackingUrl!.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isFullScreenTracking) {
            setState(() => _isFullScreenTracking = false);
            return;
          }
          _goHome();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Full Hero Google Map / WebView in the background
            Positioned.fill(
              child: _buildHeroGoogleMap(hasTrackingUrl),
            ),

            // 2. Floating Top Bar
            if (_isFullScreenTracking) ...[
              // Floating Header & Close Button when in Full View
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Live Tracking',
                            style: AppFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isFullScreenTracking = false);
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Standard Floating Top Bar: Left = MyTogether Icon, Right = Close Circle Button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: MyTogether Icon in a clean floating circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/app_icon_small.png',
                            width: 26,
                            height: 26,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    // Right: Close Circle Button
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _goHome,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 3. Grab/Foodpanda Signature Smooth Draggable Bottom Sheet
            if (!_isFullScreenTracking)
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.36,
                minChildSize: 0.26,
                maxChildSize: 0.72,
                snap: false,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        10,
                        20,
                        MediaQuery.of(context).padding.bottom + 24,
                      ),
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ..._buildDeliveryStatusCards(
                          context,
                          state,
                          storeName,
                          total,
                        ),
                      ],
                    ),
                  );
                },
              ),

            // 4. Floating Recenter Current Location / Full View Button
            // Standard Default Position: Bottom-Right of visible map, floating right above the bottom sheet
            if (!_isFullScreenTracking)
              ListenableBuilder(
                listenable: _sheetController,
                builder: (context, child) {
                  final currentExtent = _sheetController.isAttached
                      ? _sheetController.size
                      : 0.36;
                  if (currentExtent > 0.65) return const SizedBox.shrink();

                  final bottomOffset =
                      (MediaQuery.of(context).size.height * currentExtent) + 14.0;
                  return Positioned(
                    right: 16,
                    bottom: bottomOffset,
                    child: child!,
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      if (hasTrackingUrl) {
                        HapticFeedback.lightImpact();
                        if (_webController != null && !_webViewError) {
                          setState(() => _isFullScreenTracking = true);
                        } else if (state.deliveryTrackingUrl != null) {
                          _openTrackingUrl(state.deliveryTrackingUrl!);
                        }
                      } else {
                        _fitBounds();
                      }
                    },
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          hasTrackingUrl
                              ? Icons.fullscreen_rounded
                              : Icons.my_location_rounded,
                          color: const Color(0xFF0F172A),
                          size: hasTrackingUrl ? 24 : 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Full-Screen Order & Delivery Status Screen (For Own Driver / No Tracking URL)
  // -------------------------------------------------------------
  Widget _buildFullScreenDeliveryStatusScreen(
    BuildContext context,
    ActiveOrderState state,
    String storeName,
    double total,
    double delivery,
  ) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Bar matching style: Left = MyTogether Icon, Right = Close Circle Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: MyTogether Icon in a clean circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/app_icon_small.png',
                            width: 26,
                            height: 26,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    // Right: Close Circle Button
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _goHome,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Full-screen scrollable order & delivery details
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                  children: _buildDeliveryStatusCards(
                    context,
                    state,
                    storeName,
                    total,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Shared Delivery & Order Status Cards (Shared between Map Sheet & Full Screen)
  // -------------------------------------------------------------
  List<Widget> _buildDeliveryStatusCards(
    BuildContext context,
    ActiveOrderState state,
    String storeName,
    double total,
  ) {
    final bool hasTrackingUrl = state.deliveryTrackingUrl != null &&
        state.deliveryTrackingUrl!.trim().isNotEmpty;
    return [
      // Status Badge Row
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 11, vertical: 4.5),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsFill.moped,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  _currentStatus == 4 ? 'ARRIVED' : 'ON THE WAY',
                  style: AppFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Main Status Title & Estimated Time
      Text(
        _currentStatus == 4
            ? context.tr('order_status.arrived')
            : (_isRiderNearby
                ? 'ပို့ဆောင်သူ သင့်အနီးသို့ ရောက်ရှိပါတော့မည် 🛵'
                : 'ပို့ဆောင်နေပါပြီ ခဏနော် ...'),
        style: AppFonts.poppins(
          fontSize: 18.5,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 4),
      if (_currentStatus != 4) ...[
        if (_isRiderNearby)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$_deliveryRemainingMinutes mins အတွင်း ရောက်ပါမည် (အနီးသို့ ရောက်ရှိနေပါပြီ)',
                  style: AppFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          )
        else if (!hasTrackingUrl)
          Row(
            children: [
              Text(
                '${context.tr('order_status.est_waiting_time')}: ',
                style: AppFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.primaryGradient.createShader(bounds),
                child: Text(
                  '~$_deliveryRemainingMinutes mins',
                  style: AppFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
      ],
      if (_isRiderNearby && _currentStatus != 4) ...[
        const SizedBox(height: 12),
        _buildRiderNearbyAlertCard(),
      ],

      // Professional Rider Card (Shown only for Verified shops without external tracking link)
      if (_isVerifiedShop &&
          (state.deliveryTrackingUrl == null ||
              state.deliveryTrackingUrl!.trim().isEmpty) &&
          !state.isPickupFulfillment) ...[
        const SizedBox(height: 16),
        Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withValues(alpha: 0.07),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 5,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 1,
              spreadRadius: 0,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rider Avatar with online green dot
            Stack(
              children: [
                ClipOval(
                  child: Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFFF1F5F9),
                    child: (state.riderProfileUrl != null &&
                            state.riderProfileUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: FileUrlUtil.resolve(
                                state.riderProfileUrl!),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const Center(
                              child: CustomLoadingIndicator(
                                  size: 14),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(
                              Icons.sports_motorsports_rounded,
                              color: Color(0xFF94A3B8),
                              size: 26,
                            ),
                          )
                        : const Icon(
                            Icons.sports_motorsports_rounded,
                            color: Color(0xFF94A3B8),
                            size: 26,
                          ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: (state.riderPhone != null &&
                              state.riderPhone!.isNotEmpty)
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Rider Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          (state.riderName != null &&
                                  state.riderName!.trim().isNotEmpty)
                              ? state.riderName!
                              : '${state.displayDeliveryProvider} Driver',
                          style: AppFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('🛵',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        PhosphorIcons.motorcycle,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          (state.riderVehicleNumber != null &&
                                  state.riderVehicleNumber!.trim().isNotEmpty)
                              ? state.riderVehicleNumber!
                              : ((state.riderPhone != null &&
                                      state.riderPhone!.trim().isNotEmpty)
                                  ? 'Motorcycle'
                                  : (state.isOwnFleetDelivery
                                      ? 'Own Fleet Delivery'
                                      : 'Lalamove Delivery')),
                          style: AppFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ONLY CALL BUTTON for Rider
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _callRider(state.riderPhone);
                },
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      PhosphorIconsFill.phone,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ],
      const SizedBox(height: 14),

      // Food Game Card (Like other order status page)
      if (_currentStatus != -1 && _currentStatus < 4) ...[
        const FoodGameBanner(),
        const SizedBox(height: 14),
      ],

      // Route Summary Timeline (Store -> Customer Location)
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withValues(alpha: 0.07),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 5,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 1,
              spreadRadius: 0,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final rawLogo = state.logoPath ??
                        state.shopLogo ??
                        state.shopImageUrl;
                    final logoUrl = (rawLogo != null &&
                            rawLogo.trim().isNotEmpty)
                        ? FileUrlUtil.resolve(rawLogo.trim())
                        : '';
                    return Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: ClipOval(
                        child: logoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: logoUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: const Center(
                                    child: CustomLoadingIndicator(
                                        size: 10),
                                  ),
                                ),
                                errorWidget:
                                    (context, url, error) =>
                                        Center(
                                  child: Icon(
                                    Icons.storefront_rounded,
                                    size: 13,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.storefront_rounded,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: AppFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (state.restaurantAddress != null &&
                          state.restaurantAddress!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          state.restaurantAddress!,
                          style: AppFonts.poppins(
                            fontSize: 11.5,
                            color: const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 16,
                  width: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomerDestinationIcon(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ပို့ဆောင်မည့် လိပ်စာ',
                        style: AppFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.deliveryAddress ??
                            'Customer delivery location',
                        style: AppFonts.poppins(
                          fontSize: 11.5,
                          color: const Color(0xFF94A3B8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Order Summary Compact Card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withValues(alpha: 0.07),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 5,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 1,
              spreadRadius: 0,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'အော်ဒါ အနှစ်ချုပ်',
                  style: AppFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.primary
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${state.orderItems.length} items • ${total.toFormattedPrice()}',
                    style: AppFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            ...state.orderItems.take(4).map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.5),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.quantity}x',
                        style: AppFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      (item.price * item.quantity).toFormattedPrice(),
                      style: AppFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.orderItems.length > 4) ...[
              const SizedBox(height: 4),
              Text(
                '+${state.orderItems.length - 4} items more',
                style: AppFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Shop Contact Section (Chat & Call - Same Style as Other Tracking States)
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
                      color: const Color(0xFF0F172A)
                          .withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0F172A)
                          .withValues(alpha: 0.02),
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
                            storeName,
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
                        const SizedBox(width: 10),
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
                  color: const Color(0xFF0F172A)
                      .withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A)
                      .withValues(alpha: 0.02),
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
    ];
  }

  Widget _buildHeroGoogleMap(bool hasTrackingUrl) {
    final state = ActiveOrderState.instance;
    final shopPos = state.restaurantLatLng ?? _resolveShopLatLng();
    final userPos = state.userLocation ?? _resolveUserLatLng();

    if (hasTrackingUrl && _webController != null && !_webViewError) {
      return WebViewWidget(controller: _webController!);
    }

    if (_isVerifiedShop || (_webController == null || _webViewError)) {
      return RepaintBoundary(
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: shopPos ?? userPos ?? const LatLng(13.7563, 100.5018),
            zoom: 15.0,
          ),
          markers: _markers,
          polylines: _polylines,
          padding: const EdgeInsets.only(bottom: 240),
          onMapCreated: (controller) {
            _mapController = controller;
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _fetchRouteIfNeeded();
                _fitBounds();
              }
            });
          },
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
      );
    } else if (_webController != null && !_webViewError) {
      return WebViewWidget(controller: _webController!);
    } else {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.mapPinLine, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Tracking view unavailable',
                style: AppFonts.poppins(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildStoreFallbackLogo() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 19,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildCustomerDestinationIcon() {
    final rawAvatar = AuthService().currentUser?.avatarUrl;
    final avatarUrl = (rawAvatar != null && rawAvatar.trim().isNotEmpty)
        ? FileUrlUtil.resolve(rawAvatar.trim())
        : '';

    Widget locationFallback() {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.location_on_rounded,
            size: 13.5,
            color: Colors.white,
          ),
        ),
      );
    }

    if (avatarUrl.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 2),
        child: locationFallback(),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 2),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: CustomLoadingIndicator(size: 10),
            ),
          ),
          errorWidget: (context, url, error) => locationFallback(),
        ),
      ),
    );
  }



  Future<void> _openTrackingUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (kDebugMode) debugPrint('order_status_page.dart: ignored error: $e');
      }
    }
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
