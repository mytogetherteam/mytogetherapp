import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/utils/file_url_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/animated_dots_text.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:mytogetherapp/core/network/media_url.dart';
import '../../data/cart_manager.dart';
import '../../../coupons/presentation/widgets/order_coupon_discount_section.dart';
import '../../data/active_order_state.dart';
import '../../../home/data/restaurant_data.dart' show Restaurant;
import 'awaiting_payment_page.dart';
import 'order_cancel_page.dart';
import 'order_complete_page.dart';
import 'order_status_page.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/utils/price_formatter.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../chat/presentation/screens/chat_page.dart';
import '../../../chat/data/services/chat_unread_controller.dart';
import '../../../chat/presentation/widgets/chat_unread_badge.dart';
import '../../../../app.dart';
import '../../../chat/presentation/widgets/floating_chat_head.dart';
import '../../../home/data/repositories/restaurant_repository.dart';

class OrderTrackingPage extends StatefulWidget {
  final CartStore store;
  final Restaurant? restaurant;
  final int foodTotal;

  const OrderTrackingPage({
    super.key,
    required this.store,
    this.restaurant,
    this.foodTotal = 0,
  });

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  bool _isRouting = false;
  bool _showMap = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  late AnimationController _idleSolidController;
  late AnimationController _lightProgressController;
  Timer? _idleSequenceTimer;
  late AnimationController _dotsAnimController;

  /// When the user landed on this screen; used to soften the wait-time copy.
  late final DateTime _waitingStartedAt;
  Timer? _waitingHintTimer;
  bool _showLongWaitHint = false;

  double? _deliveryFee;
  bool _isCancelling = false;
  bool _showCancelLoading = false;

  int _currentImageIndex = 0;
  Timer? _slideshowTimer;
  List<String> _slideImages = [];

  late final Dio _dio;

  static const LatLng _defaultLocation = LatLng(13.7563, 100.5018);

  String get _restaurantName {
    final state = ActiveOrderState.instance;
    if (state.displayShopName.isNotEmpty) return state.displayShopName;
    final restaurant = widget.restaurant;
    if (restaurant != null && restaurant.name.isNotEmpty) {
      return restaurant.name;
    }
    return widget.store.name;
  }

  String? get _restaurantLogoUrl {
    final state = ActiveOrderState.instance;
    final raw = state.shopLogo ??
        state.logoPath ??
        widget.restaurant?.logoPath ??
        widget.store.shopImageUrl;
    final url = resolveMediaUrl(raw);
    return url.isNotEmpty ? url : null;
  }

  LatLng get _rawRestaurantLatLng {
    final lat = widget.restaurant?.latitude;
    final lon = widget.restaurant?.longitude;
    if (lat != null && lon != null && lat != 0) {
      return LatLng(lat, lon);
    }
    final fromState = ActiveOrderState.instance.restaurantLatLng;
    if (fromState != null && fromState.latitude != 0) {
      return fromState;
    }
    return const LatLng(13.7600, 100.5050);
  }

  LatLng get _homeLatLng {
    final saved = ActiveOrderState.instance.userLocation;
    if (saved != null && saved.latitude != 0 && saved.longitude != 0) {
      return saved;
    }

    if (_routePoints.length >= 2) {
      final first = _routePoints.first;
      final last = _routePoints.last;
      final restaurant = _rawRestaurantLatLng;
      final dFirst = Geolocator.distanceBetween(
        first.latitude,
        first.longitude,
        restaurant.latitude,
        restaurant.longitude,
      );
      final dLast = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        restaurant.latitude,
        restaurant.longitude,
      );
      // Pin home to the route endpoint that is not the restaurant.
      return dFirst <= dLast ? last : first;
    }

    if (_routePoints.isNotEmpty) return _routePoints.first;
    return _currentLocation ?? _defaultLocation;
  }

  LatLng get _restaurantLatLng {
    final restaurant = _rawRestaurantLatLng;

    // Demo Safety: If the restaurant is way too far (e.g. in Yangon while user is in Bangkok),
    // we fallback to a local Bangkok location for a realistic demo route.
    if (restaurant.latitude != 0) {
      final userLat = _homeLatLng.latitude;
      final userLon = _homeLatLng.longitude;

      final dist = Geolocator.distanceBetween(
        restaurant.latitude,
        restaurant.longitude,
        userLat,
        userLon,
      );
      if (dist > 100000) {
        // > 100km
        return LatLng(userLat + 0.005, userLon + 0.005); // Move shop near user
      }
      return restaurant;
    }
    return const LatLng(13.7600, 100.5050);
  }

  StreamSubscription? _orderSubscription;
  Timer? _statusPollTimer;
  int? _lastReconciledOrderStatus;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _homeIcon;
  BitmapDescriptor? _shopIcon;
  BitmapDescriptor? _restaurantBubbleIcon;

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

  @override
  void initState() {
    super.initState();
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = true);
    _initSlideImages();
    if (ActiveOrderState.instance.shopPhone == null || ActiveOrderState.instance.shopPhone!.isEmpty) {
      if (widget.restaurant?.phone != null && widget.restaurant!.phone!.isNotEmpty) {
        ActiveOrderState.instance.shopPhone = widget.restaurant!.phone;
      }
    }

    _waitingStartedAt = DateTime.now();
    _waitingHintTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final longWait = DateTime.now().difference(_waitingStartedAt).inMinutes >= 5;
      if (longWait != _showLongWaitHint) {
        setState(() => _showLongWaitHint = longWait);
      }
    });

    // Solid idle trailing animation
    final initialProgress = ActiveOrderState.instance.idleSolidProgress ?? 0.0;
    _idleSolidController =
        AnimationController(
          vsync: this,
          duration: const Duration(seconds: 3),
          value: initialProgress,
        )..addListener(() {
          ActiveOrderState.instance.updateIdleProgress(
            _idleSolidController.value,
          );
        });

    // Light idle trailing animation
    _lightProgressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _startIdleAnimationSequence();

    WebSocketService().connect(force: true);

    // Live WebSocket order events can be missed entirely: the backend's STOMP
    // broker drops messages for any user whose socket isn't connected at that
    // instant (no durable queue). To avoid getting stuck on "awaiting
    // confirmation" for minutes, reconcile against the backend on open, when
    // the app resumes, and on a short poll while we wait.
    WidgetsBinding.instance.addObserver(this);
    _lastReconciledOrderStatus = ActiveOrderState.instance.orderStatus;
    _reconcileWithBackend();
    _statusPollTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _reconcileWithBackend(),
    );

    _orderSubscription = WebSocketService().orderUpdates.listen((update) {
      if (!mounted) return;

      // Handle the server wrapper: { "type": "ORDER_UPDATE", "order": { ... } }
      Map<String, dynamic> data = update;
      if (update.containsKey('order') && update['order'] is Map) {
        data = update['order'] as Map<String, dynamic>;
      } else if (update.containsKey('data') && update['data'] is Map) {
        data = update['data'] as Map<String, dynamic>;
      }
      final status = (data['status'] as String?) ?? (update['type'] as String?);

      if (mounted) {
        setState(() {});
      }

      if (status != null) {
        final upperStatus = status.toUpperCase();

        if (ActiveOrderState.isPaymentTransitionStatus(upperStatus)) {
          final state = ActiveOrderState.instance;
          if (upperStatus == 'PAYMENT_SLIP_REQUESTED') {
            if (!state.hasNotifiedSlipRequest) {
              state.setNotifiedSlipRequest(true);
            }
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _navigateToPayment();
          });
        } else if (ActiveOrderState.isCookingTransitionStatus(upperStatus)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _navigateToOrderStatus();
          });
        } else if (upperStatus == 'CANCELLED' ||
            upperStatus == 'CANCELED' ||
            status == '-1') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _navigateToCancelPage();
          });
        }
      }
    });

    // Dots animation
    _dotsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _dio = Dio();

    _checkCachedData();
    if (_routePoints.isNotEmpty) {
      _showMap = true;
    }

    // Pre-build custom marker icons
    if (ActiveOrderState.instance.isPickupFulfillment) {
      if (mounted) setState(() => _showMap = false);
    } else {
      _buildCustomMarkers().then((_) {
        _updateRestaurantBubbleBitmap();
        _initLocationAndRoute();
      });
    }
  }

  void _startIdleAnimationSequence() {
    if (!mounted) return;

    // Orchestrate the sequence using async/await to ensure they are sequential
    _runSequentialIdleSequence();
  }

  Future<void> _runSequentialIdleSequence() async {
    if (!mounted) return;

    final startValue = _idleSolidController.value;
    final remainingSeconds = (600 * (1.0 - startValue)).toInt(); // 10 minutes total

    if (remainingSeconds > 0) {
      _idleSolidController.animateTo(
        1.0,
        duration: Duration(seconds: remainingSeconds),
        curve: Curves.linear,
      );
    }
  }

  void _checkCachedData() {
    final state = ActiveOrderState.instance;
    if (state.routePoints.isNotEmpty) {
      _routePoints = state.routePoints;
      _deliveryFee = state.deliveryFee;
    }
    final savedUser = state.userLocation;
    if (savedUser != null &&
        savedUser.latitude != 0 &&
        savedUser.longitude != 0) {
      _currentLocation = savedUser;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Socket may have been torn down while backgrounded; force a reconnect
      // and immediately catch up via REST in case an update was missed.
      WebSocketService().connect(force: true);
      _reconcileWithBackend(forceNavigation: true);
    }
  }

  /// Syncs order state from the API. Navigation only runs when [forceNavigation]
  /// is true (app resume) or when status advances past "awaiting shop" (0→…)
  /// so the 12s poll does not repeatedly replace routes.
  Future<void> _reconcileWithBackend({bool forceNavigation = false}) async {
    await ActiveOrderState.instance.syncActiveOrder();
    if (!mounted) return;

    final state = ActiveOrderState.instance;
    final status = state.orderStatus;
    final previousStatus = _lastReconciledOrderStatus;
    _lastReconciledOrderStatus = status;

    if (mounted) setState(() {});

    final advancedFromAwaitingShop =
        previousStatus == 0 && status != 0;
    final advancedToCooking = previousStatus == 1 && status == 2;
    final shouldNavigate = (forceNavigation ||
            advancedFromAwaitingShop ||
            advancedToCooking) &&
        status != 0 &&
        status != 3;

    if (!shouldNavigate) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (status == 1) {
        if (!AwaitingPaymentPage.isCurrentlyVisible) {
          _navigateToPayment();
        }
      } else if (status == 2) {
        if (!OrderStatusPage.isCurrentlyVisible) {
          _navigateToOrderStatus();
        }
      } else if (status == 4 && !OrderCompletePage.isCurrentlyVisible) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OrderCompletePage()),
        );
      } else if (status == -1) {
        if (state.wasCancelledByUser(state.orderId)) {
          Navigator.popUntil(context, (route) => route.isFirst);
        } else {
          _navigateToCancelPage();
        }
      }
    });
  }

  void _navigateToCancelPage() {
    if (!mounted) return;
    _statusPollTimer?.cancel();
    final cancelledOrder = ActiveOrderState.instance.getOrder(ActiveOrderState.instance.orderId);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderCancelPage(
          orderId: cancelledOrder?.orderId ?? '',
          reason: cancelledOrder?.cancelReason,
          shopId: cancelledOrder?.shopId,
          shopName: cancelledOrder?.shopNameEn ??
              cancelledOrder?.shopName ??
              cancelledOrder?.restaurantName ??
              cancelledOrder?.storeName,
          shopNameMm: cancelledOrder?.shopNameMm,
          shopNameTh: cancelledOrder?.shopNameTh,
          shopLogo: cancelledOrder?.shopLogo ?? cancelledOrder?.logoPath,
          shopImageUrl: cancelledOrder?.shopImageUrl,
          cancelledByUser: ActiveOrderState.instance.wasCancelledByUser(cancelledOrder?.orderId),
        ),
      ),
    );
  }

  @override
  void dispose() {
    App.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _statusPollTimer?.cancel();
    _idleSolidController.dispose();
    _lightProgressController.dispose();
    _idleSequenceTimer?.cancel();
    _waitingHintTimer?.cancel();
    _slideshowTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _orderSubscription?.cancel();
    _mapController?.dispose();
    _dotsAnimController.dispose();
    super.dispose();
  }

  void _initSlideImages() {
    final urls = <String>{};
    for (final item in widget.store.items) {
      final url = FileUrlUtil.resolve(item.imageUrl ?? item.imagePath);
      if (url.isNotEmpty) urls.add(url);
    }
    if (urls.isEmpty && _restaurantLogoUrl != null) {
      urls.add(_restaurantLogoUrl!);
    }
    _slideImages = urls.toList();

    if (_slideImages.length > 1) {
      _slideshowTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) setState(() => _currentImageIndex++);
      });
    }

    // Prefer admin "Order Waiting" banners as the confirming-screen hero.
    _fetchOrderWaitingBanner();
  }

  Future<void> _fetchOrderWaitingBanner() async {
    try {
      final banners = await RestaurantRepository.instance.getBanners(
        position: 'Order',
      );
      if (!mounted || banners.isEmpty) return;
      final orderUrls = banners
          .map((b) => b.imageUrl)
          .where((url) => url.isNotEmpty)
          .toList();
      if (orderUrls.isEmpty) return;

      _slideshowTimer?.cancel();
      setState(() {
        _slideImages = orderUrls;
        _currentImageIndex = 0;
      });
      if (_slideImages.length > 1) {
        _slideshowTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          if (mounted) setState(() => _currentImageIndex++);
        });
      }
    } catch (e) {
      debugPrint('Order waiting banner fetch failed: $e');
    }
  }

  Future<void> _initLocationAndRoute() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    LatLng? userLoc;
    if (serviceEnabled &&
        permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever) {
      // Last-known position is fast on mobile but unsupported on web.
      if (!kIsWeb) {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null &&
              ActiveOrderState.instance.userLocation == null &&
              _routePoints.isEmpty) {
            userLoc = LatLng(last.latitude, last.longitude);
            if (mounted) setState(() => _currentLocation = userLoc);
          }
        } catch (_) {}
      }

      // Start continuous updates in background
      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 15,
            ),
          ).listen((pos) {
            // Keep the home pin on the saved delivery address / route endpoint.
            // Emulator GPS often drifts to a default city center and breaks alignment.
            if (ActiveOrderState.instance.userLocation != null ||
                _routePoints.isNotEmpty) {
              return;
            }
            final newLoc = LatLng(pos.latitude, pos.longitude);
            if (mounted) {
              setState(() {
                _currentLocation = newLoc;
                _updateMarkersAndPolylines();
              });
            }
          });
    }

    final startLoc = _homeLatLng;
    if (mounted) setState(() => _currentLocation ??= startLoc);

    if (_routePoints.isEmpty) {
      // Show map immediately with skeleton/default state, then fetch route
      if (mounted) setState(() => _showMap = true);
      await _fetchRoute(startLoc);
    } else {
      _buildInitialMarkersAndPolylines();
      _updateRestaurantBubbleBitmap();
      if (mounted) setState(() => _showMap = true);
      // Zoom to cached route
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _routePoints.isNotEmpty && _mapController != null) {
          _fitBounds(_routePoints);
        }
      });
    }
  }

  void _buildInitialMarkersAndPolylines() {
    _updateMarkersAndPolylines();
  }

  // ---------------------------------------------------------------------------
  // Custom Marker Builders
  // ---------------------------------------------------------------------------

  Future<void> _buildCustomMarkers() async {
    _homeIcon = await _drawMarkerBitmap(
      icon: Icons.home_rounded,
      bgColor: AppColors.primary,
      iconColor: Colors.white,
      size: 45, // Reduced from 60
    );
    _shopIcon = await _drawMarkerBitmap(
      icon: Icons.restaurant,
      bgColor: AppColors.primary,
      iconColor: Colors.white,
      size: 45, // Reduced from 60
    );
    if (mounted) setState(() {});
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

    // Shadow
    canvas.drawCircle(
      Offset(r, r + 4),
      r * 0.85,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // White border ring
    canvas.drawCircle(Offset(r, r), r, Paint()..color = Colors.white);

    // Gradient fill
    final paint = Paint()
      ..shader = AppColors.primaryGradient.createShader(
        Rect.fromLTWH(0, 0, size, size),
      );
    canvas.drawCircle(Offset(r, r), r - 4, paint);

    // Icon
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

  Future<void> _updateRestaurantBubbleBitmap() async {
    final bmp = await _drawRestaurantBubbleBitmap(
      name: _restaurantName,
      logoUrl: _restaurantLogoUrl,
    );

    if (mounted) {
      setState(() {
        _restaurantBubbleIcon = bmp;
        _updateMarkersAndPolylines();
      });
    }
  }

  Future<ui.Image?> _loadNetworkImage(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
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
    canvas.drawImageRect(image, src, dst, Paint());
    canvas.restore();
  }

  Future<BitmapDescriptor> _drawRestaurantBubbleBitmap({
    required String name,
    String? logoUrl,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    const double boxHeight = 52.0;
    const double pointerWidth = 16.0;
    const double pointerHeight = 10.0;
    const double shadowBottomPadding = 4.0;
    const double bubbleLogoSize = 28.0;
    const double bubblePadding = 12.0;
    const double bubbleLogoGap = 8.0;
    const double maxBubbleTextWidth = 150.0;

    final ui.Image? logoImage =
        logoUrl != null ? await _loadNetworkImage(logoUrl) : null;

    final TextPainter namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxBubbleTextWidth);

    final double bubbleContentWidth = (logoImage != null
            ? bubbleLogoSize + bubbleLogoGap
            : 0) +
        namePainter.width;
    final double boxWidth = bubbleContentWidth + bubblePadding * 2;
    final double totalWidth = boxWidth;
    final double totalHeight = boxHeight + pointerHeight + shadowBottomPadding;
    final double centerX = totalWidth / 2;

    final RRect bubbleRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerX - boxWidth / 2, 0, boxWidth, boxHeight),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      bubbleRRect.shift(const Offset(0, 8)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    final Path pointerPath = Path()
      ..moveTo(centerX - pointerWidth / 2, boxHeight - 2)
      ..lineTo(centerX + pointerWidth / 2, boxHeight - 2)
      ..lineTo(centerX, boxHeight + pointerHeight)
      ..close();

    final Path fullBubble = Path.combine(
      PathOperation.union,
      Path()..addRRect(bubbleRRect),
      pointerPath,
    );

    canvas.drawPath(
      fullBubble,
      Paint()
        ..shader = AppColors.primaryGradient.createShader(
          Rect.fromLTWH(0, 0, totalWidth, boxHeight),
        ),
    );
    canvas.drawPath(
      fullBubble,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final double bubbleContentStartX = centerX - bubbleContentWidth / 2;
    final double bubbleContentCenterY = boxHeight / 2;

    if (logoImage != null) {
      final logoCenter = Offset(
        bubbleContentStartX + bubbleLogoSize / 2,
        bubbleContentCenterY,
      );
      canvas.drawCircle(
        logoCenter,
        bubbleLogoSize / 2,
        Paint()..color = Colors.white,
      );
      _paintCircularImage(
        canvas,
        logoImage,
        logoCenter,
        bubbleLogoSize / 2 - 2,
      );
    }

    namePainter.paint(
      canvas,
      Offset(
        bubbleContentStartX +
            (logoImage != null ? bubbleLogoSize + bubbleLogoGap : 0),
        bubbleContentCenterY - namePainter.height / 2,
      ),
    );

    final ui.Image img = await pictureRecorder.endRecording().toImage(
      totalWidth.toInt(),
      totalHeight.toInt(),
    );
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  // ---------------------------------------------------------------------------

  void _updateMarkersAndPolylines() {
    final sets = <Marker>{};

    sets.add(
      Marker(
        markerId: const MarkerId('restaurant'),
        position: _restaurantLatLng,
        icon:
            _shopIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        anchor: const Offset(0.5, 0.5),
      ),
    );

    if (_restaurantBubbleIcon != null) {
      sets.add(
        Marker(
          markerId: const MarkerId('restaurant_bubble'),
          position: _restaurantLatLng,
          icon: _restaurantBubbleIcon!,
          anchor: const Offset(0.5, 1.15),
          zIndexInt: 3,
        ),
      );
    }

    if (_homeLatLng.latitude != 0) {
      sets.add(
        Marker(
          markerId: const MarkerId('user'),
          position: _homeLatLng,
          icon:
              _homeIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    final polySet = <Polyline>{};
    if (_routePoints.isNotEmpty) {
      // Primary app pink route to match the image
      polySet.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: AppColors.primary,
          width: 3,
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

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    // Include both user and restaurant in the bounds
    final all = [...points, _restaurantLatLng, _homeLatLng];

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

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 150));
  }

  Future<void> _fetchRoute(LatLng start) async {
    final dest = _restaurantLatLng;
    setState(() => _isRouting = true);

    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${dest.longitude},${dest.latitude}?geometries=geojson';
      final response = await _dio
          .get(url)
          .timeout(const Duration(seconds: 5)); // Reduced from 10s

      if (response.statusCode == 200 &&
          response.data['routes'] != null &&
          (response.data['routes'] as List).isNotEmpty) {
        final route = response.data['routes'][0];
        final List coords = route['geometry']['coordinates'];
        final double distanceM = (route['distance'] as num).toDouble();
        final double durationS = (route['duration'] as num).toDouble();

        final List<LatLng> points = coords
            .map<LatLng>((c) => LatLng(c[1], c[0]))
            .toList();

        final km = distanceM / 1000;
        final mins = (durationS / 60).ceil();

        // Demo Safety: Cap fee if distance is unrealistic for food delivery
        final actualKm = km > 100 ? 5.0 : km;

        // Prefer backend delivery fee from WebSocket if available; otherwise estimate
        final backendFee = ActiveOrderState.instance.deliveryFee;
        final fee = (backendFee != null && backendFee > 0 && backendFee < 1000)
            ? backendFee
            : (30.0 + (actualKm * 15.0)).roundToDouble();

        if (mounted) {
          final polyPoints = [start, ...points, dest];
          setState(() {
            _routePoints = polyPoints;
            _deliveryFee = fee;
            _isRouting = false;
            if (ActiveOrderState.instance.userLocation == null) {
              _currentLocation = start;
            }
            _updateMarkersAndPolylines();
          });

          // Cache in global state
          ActiveOrderState.instance.updateRouteData(
            points: polyPoints,
            distanceKm: km,
            durationMins: mins,
            fee: fee,
          );

          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _fitBounds(polyPoints);
            }
          });
        }
      } else {
        if (mounted) setState(() => _isRouting = false);
      }
    } catch (e) {
      if (mounted) {
        final fallbackPoints = [start, dest];
        final distanceM = Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          dest.latitude,
          dest.longitude,
        );
        final km = distanceM / 1000;
        final mins = (km * 2).ceil(); // Rough estimate: 2 mins per km

        // Use backend fee or estimate
        final backendFee = ActiveOrderState.instance.deliveryFee;
        final fee = (backendFee != null && backendFee > 0)
            ? backendFee
            : (30.0 + (km * 15.0)).roundToDouble();

        setState(() {
          _routePoints = fallbackPoints;
          _deliveryFee = fee;
          _isRouting = false;
          if (ActiveOrderState.instance.userLocation == null) {
            _currentLocation = start;
          }
          _updateMarkersAndPolylines();
        });

        ActiveOrderState.instance.updateRouteData(
          points: fallbackPoints,
          distanceKm: km,
          durationMins: mins,
          fee: fee,
        );

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _mapController != null) {
            _fitBounds(fallbackPoints);
          }
        });
      }
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToPayment() {
    if (!mounted || AwaitingPaymentPage.isCurrentlyVisible) return;
    _statusPollTimer?.cancel();
    _idleSequenceTimer?.cancel();
    _idleSolidController.stop();
    _lightProgressController.stop();
    _dotsAnimController.stop();
    final fee = _deliveryFee ?? 0.0;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AwaitingPaymentPage(
          orderId: ActiveOrderState.instance.orderId,
          foodTotal: widget.foodTotal.toDouble(),
          deliveryFee: fee,
        ),
      ),
    );
  }

  void _navigateToOrderStatus() {
    if (!mounted || OrderStatusPage.isCurrentlyVisible) return;
    _statusPollTimer?.cancel();
    final fee = _deliveryFee ?? ActiveOrderState.instance.deliveryFee ?? 0.0;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderStatusPage(
          foodTotal: widget.foodTotal.toDouble(),
          deliveryFee: fee,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    // Grab-style: ads dominate (~72%), compact order sheet (~28%).
    final sheetH = screenH * 0.28;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── FULL-BLEED WAITING ADS (~72%) ──────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: sheetH - 24, // tuck slightly under sheet corners
            child: _buildShopImageBackground(),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: _goHome,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.black, size: 20),
              ),
            ),
          ),

          // ── COMPACT ORDER BOTTOM SHEET (~28%) ──────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: sheetH,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 2),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                'order_tracking.awaiting_confirmation',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedDotsText(
                              baseText: context.tr(
                                'order_tracking.restaurant_reviewing',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                return AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _idleSolidController,
                                    _lightProgressController,
                                  ]),
                                  builder: (context, _) {
                                    final double idleSolidWidth =
                                        constraints.maxWidth *
                                        _idleSolidController.value;
                                    final double remainingIdleDistance =
                                        constraints.maxWidth - idleSolidWidth;
                                    final double lightProgressWidthFactor =
                                        _lightProgressController.value;
                                    final double totalLightTrailWidth =
                                        idleSolidWidth +
                                        (remainingIdleDistance *
                                            lightProgressWidthFactor);

                                    return Container(
                                      height: 10,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Stack(
                                        children: [
                                          if (totalLightTrailWidth > 0)
                                            Container(
                                              height: 10,
                                              width: totalLightTrailWidth,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          if (idleSolidWidth > 0)
                                            Container(
                                              height: 10,
                                              width: idleSolidWidth,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            ChatUnreadBadge(
                              orderId: _currentOrderId,
                              child: GestureDetector(
                                onTap: () {
                                  final state = ActiveOrderState.instance;
                                  _openChat(
                                    name: state.restaurantName ??
                                        widget.store.name,
                                    subtitle: context.tr('common.restaurant'),
                                    avatarUrl: state.logoPath,
                                  );
                                },
                                child: Container(
                                  height: 44,
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        PhosphorIcons.chatCircleTextFill,
                                        color: const Color(0xFF1E293B),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        context.tr('order_confirm.chat'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildInfoRow(
                                    label: context.tr(
                                      'order_status.food_total',
                                    ),
                                    value: ActiveOrderState
                                            .instance.displayFoodPrice ??
                                        widget.foodTotal.toFormattedPrice(),
                                    valueColor: const Color(0xFF334155),
                                  ),

                                  if (ActiveOrderState.instance.taxEnable) ...[
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      label: context.tr('order_status.tax'),
                                      value: ActiveOrderState
                                              .instance.displayTaxAmount ??
                                          ActiveOrderState
                                              .instance.resolvedTaxAmount
                                              .toFormattedPrice(),
                                      valueColor: const Color(0xFF334155),
                                    ),
                                  ],

                                  if (ActiveOrderState
                                      .instance.hasAppliedCoupon) ...[
                                    const SizedBox(height: 12),
                                    OrderCouponDiscountSection(
                                      couponName: ActiveOrderState
                                          .instance.couponName,
                                      discountAmount: ActiveOrderState
                                          .instance.discountAmount,
                                      displayDiscountAmount: ActiveOrderState
                                          .instance.displayDiscountAmount,
                                      shopCoupon: ActiveOrderState
                                          .instance.shopCoupon,
                                    ),
                                  ],

                                  if (!ActiveOrderState
                                      .instance.isPickupFulfillment) ...[
                                    const SizedBox(height: 16),
                                    _buildDeliveryFeeRow(),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GradientText(
                                      context.tr(
                                        _showLongWaitHint
                                            ? 'order_tracking.taking_longer'
                                            : 'order_tracking.usually_takes',
                                      ),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            Center(
                              child: TextButton(
                                onPressed: () => _showCancelConfirm(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  context.tr('order_tracking.cancel_order'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
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
    );
  }



  int? get _currentOrderId {
    final orderIdStr = ActiveOrderState.instance.orderId?.replaceAll('#', '');
    final orderId = int.tryParse(orderIdStr ?? '');
    return (orderId != null && orderId > 0) ? orderId : null;
  }

  Future<void> _makeCall(String? phone) async {
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
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isGradientValue = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
        ),
        if (isGradientValue)
          GradientText(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          )
        else
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black,
            ),
          ),
      ],
    );
  }

  String _getEstimatedDeliveryFeeText() {
    final state = ActiveOrderState.instance;
    final km = state.routeDistanceKm ?? 0.0;
    
    if (km == 0.0) {
      return state.displayDeliveryFee ?? 
          (_deliveryFee ?? state.deliveryFee ?? 0.0).toFormattedPrice();
    }
    
    final double baseFee = (15.0 + (km * 8.5)).floorToDouble();
    final double maxFee = (35.0 + (km * 7.2)).ceilToDouble();
    
    final minVal = baseFee < maxFee ? baseFee : maxFee;
    final maxVal = baseFee > maxFee ? baseFee : maxFee;
    
    if (minVal == maxVal) return minVal.toFormattedPrice();
    return '฿ ${minVal.toStringAsFixed(0)} - ฿ ${maxVal.toStringAsFixed(0)}';
  }

  Widget _buildDeliveryFeeRow() {
    final state = ActiveOrderState.instance;
    final isPickup = state.isPickupFulfillment;
    final feeValue = _getEstimatedDeliveryFeeText();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isPickup ? Icons.storefront : Icons.delivery_dining, 
                  size: 18, 
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isPickup
                        ? context.tr('order_status.pickup_fee')
                        : context.tr('cart.est_delivery_fee'),
                    style: GoogleFonts.poppins(
                      fontSize: 14, 
                      fontWeight: FontWeight.w600, 
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Text(
            feeValue,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopImageBackground() {
    if (_slideImages.isEmpty) {
      return Container(
        color: const Color(0xFF1E293B),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_restaurantLogoUrl != null) ...[
                CircleAvatar(
                  radius: 28,
                  backgroundImage: CachedNetworkImageProvider(
                    _restaurantLogoUrl!,
                  ),
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
              ],
              Image.asset(
                'assets/images/pickup_bag.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _restaurantName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentUrl = _slideImages[_currentImageIndex % _slideImages.length];
    final topSafe = MediaQuery.of(context).padding.top;
    final slideCount = _slideImages.length;
    final activeIndex = _currentImageIndex % slideCount;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed ad slideshow (Grab-style, no radar / no inset card)
          ..._slideImages.asMap().entries.map((entry) {
            final isActive = entry.value == currentUrl;
            return AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: CachedNetworkImage(
                imageUrl: entry.value,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            );
          }),

          // Soft top scrim for controls readability
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topSafe + 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Soft bottom fade into the sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
          ),

          // Slideshow progress segments (Grab-style story bars)
          if (slideCount > 1)
            Positioned(
              top: topSafe + 8,
              left: 16,
              right: 64,
              child: Row(
                children: List.generate(slideCount, (i) {
                  final filled = i < activeIndex;
                  final current = i == activeIndex;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: i == slideCount - 1 ? 0 : 4,
                      ),
                      height: 3,
                      decoration: BoxDecoration(
                        color: filled || current
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

          // Restaurant chip over the ad (bottom-left of media)
          Positioned(
            left: 16,
            bottom: 36,
            right: 16,
            child: Row(
              children: [
                if (_restaurantLogoUrl != null) ...[
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: CachedNetworkImageProvider(
                      _restaurantLogoUrl!,
                    ),
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    _restaurantName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirm() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
              const SizedBox(height: 20),
              Text(
                context.tr('order_tracking.cancel_title'),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('order_tracking.cancel_confirm'),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        context.tr('order_tracking.keep_order'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryGradientButton(
                      onPressed: _isCancelling
                          ? null
                          : () async {
                              setState(() => _isCancelling = true);
                              setModalState(
                                () => {},
                              ); // Rebuild button to show disabled state


                              // Delayed loading indicator (500ms)
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  if (mounted && _isCancelling) {
                                    setState(() => _showCancelLoading = true);
                                    setModalState(() => {});
                                  }
                                },
                              );

                              try {
                                final success = await ActiveOrderState.instance
                                    .cancelActiveOrder();

                                if (!success) {
                                  if (mounted) {
                                    AppDialog.showToast(
                                      this.context,
                                      this.context.tr('payment.cancel_failed'),
                                      isError: true,
                                    );
                                  }
                                  return;
                                }

                                // Clear local store
                                CartManager.instance.removeStore(
                                  widget.store.nameKey,
                                );

                                // Navigation → order cancellation screen.
                                // Dismiss the confirm sheet, then replace the
                                // tracking page (via the State's context, not
                                // the sheet's) with the cancellation screen.
                                if (context.mounted) Navigator.pop(context);
                                if (mounted) {
                                  Navigator.popUntil(context, (route) => route.isFirst);
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isCancelling = false;
                                    _showCancelLoading = false;
                                  });
                                  setModalState(() => {});
                                }
                              }
                            },
                      isLoading: _showCancelLoading,
                      child: Text(
                        context.tr('order_tracking.cancel_order'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
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
