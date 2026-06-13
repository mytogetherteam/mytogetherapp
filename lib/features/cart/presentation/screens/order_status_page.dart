import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/utils/price_formatter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_map_theme.dart';
import '../../../../core/theme/app_colors.dart';
import 'dart:ui' as ui;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/presentation/widgets/gradient_icon.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../data/active_order_state.dart';
import 'order_complete_page.dart';
import 'awaiting_payment_page.dart';
import '../../../home/data/repositories/restaurant_repository.dart';
import '../../../home/presentation/widgets/image_skeleton_loader.dart';
import 'package:geolocator/geolocator.dart';
import 'order_cancel_page.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../chat/presentation/screens/chat_page.dart';

class OrderStatusPage extends StatefulWidget {
  final double foodTotal;
  final double deliveryFee;

  const OrderStatusPage({
    super.key,
    required this.foodTotal,
    required this.deliveryFee,
  });

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> with TickerProviderStateMixin {
  int _currentStatus = 1; 
  String? _backendStatus;
  
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _homeIcon;
  BitmapDescriptor? _shopIcon;
  
  late AnimationController _processingController;

  WebViewController? _webController;
  bool _webViewError = false;
  String? _lastInitedUrl;

  StreamSubscription? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _currentStatus = ActiveOrderState.instance.orderStatus.clamp(1, 4);
    
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
    if (_currentStatus == 3 && state.deliveryTrackingUrl != null && state.deliveryTrackingUrl!.isNotEmpty) {
      _initWebView(state.deliveryTrackingUrl!);
    }

    // Connect to WebSockets with force: true to ensure topic subscriptions are refreshed with the current orderId
    WebSocketService().connect(force: true);
    
    _orderSubscription = WebSocketService().orderUpdates.listen((update) {
      if (mounted) {
        final state = ActiveOrderState.instance;
        setState(() {
          // Map ActiveOrderState orderStatus (0-4) to local _currentStatus (1-4)
          _currentStatus = state.orderStatus.clamp(1, 4);

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
          Future.delayed(const Duration(seconds: 2), () => _navigateToComplete());
        }

        // Auto-navigate when status becomes CANCELLED (-1)
        if (state.orderStatus == -1) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderCancelPage(
                    orderId: state.orderId ?? "",
                    reason: state.cancelReason,
                    shopId: state.shopId,
                    shopName: state.shopNameEn ?? state.shopName,
                    shopNameMm: state.shopNameMm,
                    shopNameTh: state.shopNameTh,
                    shopLogo: state.shopLogo,
                    shopImageUrl: state.shopImageUrl,
                  ),
                ),
              );
            }
          });
        }

        // Auto-navigate back to Payment if requested and not already checking
        if (state.orderStatus == 1 && !state.isPaymentChecking && !AwaitingPaymentPage.isCurrentlyVisible) {
          if (!state.hasNotifiedSlipRequest) {
            state.setNotifiedSlipRequest(true);
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Row(
            //       children: [
            //         Icon(PhosphorIcons.warningCircleFill, color: Colors.white, size: 20),
            //         const SizedBox(width: 10),
            //         Expanded(
            //           child: Text('New payment slip requested by restaurant',
            //               style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
            //         ),
            //       ],
            //     ),
            //     backgroundColor: AppColors.primary,
            //     behavior: SnackBarBehavior.floating,
            //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            //   ),
            // );
          }
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
              state.restaurantAddress = shop.address ?? shop.addressEn ?? shop.addressTh;
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
      debugPrint(' [OrderStatus] Invalid URL (missing scheme): $url');
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
  void dispose() {
    _processingController.dispose();
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _navigateToComplete() {
    if (!mounted) return;
    // navigateTo atomically guards against duplicates; it uses push so we
    // manually replace by popping this page afterward if navigation succeeded.
    if (OrderCompletePage.navigateTo(context)) {
      // Pop this OrderStatusPage so the complete page is the only one on stack
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).removeRoute(ModalRoute.of(context)!);
      });
    }
  }

  LatLng get _restaurantLatLng {
    final state = ActiveOrderState.instance;
    final lat = state.restaurantLatLng?.latitude;
    final lon = state.restaurantLatLng?.longitude;

    if (lat != null && lon != null && lat != 0) {
      final userLat = state.userLocation?.latitude ?? 13.7563;
      final userLon = state.userLocation?.longitude ?? 100.5018;

      final dist = Geolocator.distanceBetween(lat, lon, userLat, userLon);
      if (dist > 100000) { // > 100km mismatch
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

    canvas.drawCircle(Offset(r, r + 4), r * 0.85, Paint()..color = Colors.black.withValues(alpha: 0.18));
    canvas.drawCircle(Offset(r, r), r, Paint()..color = Colors.white);
    
    // Gradient fill
    final paint = Paint()
      ..shader = AppColors.primaryGradient.createShader(Rect.fromLTWH(0, 0, size, size));
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

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  void _updateMarkers() {
    final state = ActiveOrderState.instance;
    final sets = <Marker>{};
    
    if (state.restaurantLatLng != null) {
      sets.add(Marker(
        markerId: const MarkerId('restaurant'),
        position: state.restaurantLatLng!,
        icon: _shopIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
      ));
    }

    if (state.userLocation != null) {
      sets.add(Marker(
        markerId: const MarkerId('user'),
        position: state.userLocation!,
        icon: _homeIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
      ));
    }

    final polySet = <Polyline>{};
    if (state.routePoints.isNotEmpty) {
      polySet.add(Polyline(
        polylineId: const PolylineId('route'),
        points: state.routePoints,
        color: AppColors.primary,
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    }

    if (mounted) {
      setState(() {
        _markers = sets;
        _polylines = polySet;
      });
    }
  }

  void _fitBounds() {
    if (_mapController == null) return;
    final state = ActiveOrderState.instance;
    final all = [
      if (state.restaurantLatLng != null && state.restaurantLatLng!.latitude != 0) state.restaurantLatLng!,
      if (state.userLocation != null && state.userLocation!.latitude != 0) state.userLocation!,
      ...state.routePoints,
    ];
    if (all.isEmpty) return;

    double minLat = all.first.latitude;
    double maxLat = all.first.latitude;
    double minLng = all.first.longitude;
    double maxLng = all.first.longitude;

    for (var p in all) {
      if (p.latitude == 0 && p.longitude == 0) continue; // Ignore invalid points
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 
      60
    ));
  }

  String _statusTitle(BuildContext context) {
    if (_currentStatus == -1) return context.tr('order_status.cancelled');
    switch (_currentStatus) {
      case 1:
        return context.tr('order_status.checking_payment');
      case 2:
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
    final total = widget.foodTotal + widget.deliveryFee;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: _goHome,
        ),
      ),
      body: SingleChildScrollView(
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
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                      ),
                    )
                  : GradientText(
                      _statusTitle(context),
                      key: ValueKey<int>(_currentStatus),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            if (_currentStatus != -1) ...[
              Text(
                context.trArgs('order_status.estimate_arrival', {
                  'time': state.estimatedTime ?? '09:45 PM',
                }),
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              // Progress Bar
              _buildProgressBar(),
              const SizedBox(height: 32),
            ],

            // Map Embed (only if status >= 3)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child));
              },
              child: (() {
                if (_currentStatus < 3 || _currentStatus == -1) return const SizedBox.shrink(key: ValueKey('empty_map'));
                
                final state = ActiveOrderState.instance;
                final bool hasTrackingUrl = state.deliveryTrackingUrl != null && state.deliveryTrackingUrl!.isNotEmpty;
                
                // If we attempted to show WebView but it failed, hide the map section entirely as requested
                if (hasTrackingUrl && _webViewError) {
                  return const SizedBox.shrink(key: ValueKey('webview_error'));
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
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
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
                          Positioned.fill(
                            child: ImageSkeletonLoader(),
                          ),
                          Positioned.fill(
                            child: (hasTrackingUrl && _webController != null)
                              ? WebViewWidget(controller: _webController!)
                              : GoogleMap(
                                  padding: const EdgeInsets.only(bottom: 0),
                                  initialCameraPosition: CameraPosition(
                                    target: _restaurantLatLng,
                                    zoom: 14,
                                  ),
                                  onMapCreated: (controller) {
                                    _mapController = controller;
                                    _updateMarkers();
                                    Future.delayed(const Duration(milliseconds: 400), _fitBounds);
                                  },
                                  markers: _markers,
                                  polylines: _polylines,
                                  myLocationEnabled: false,
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,
                                  compassEnabled: false,
                                  style: AppMapTheme.defaultStyle,
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
            
            // Est Waiting Time and Delivery Fee Gradient Section
            if (_currentStatus != -1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (state.estimatedTime != null && state.estimatedTime!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('order_status.est_waiting_time'),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                              letterSpacing: 0.5,
                            ),
                          ),
                          GradientText(
                            state.estimatedTime!,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          context.tr('order_status.delivery_fee'),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 0.5,
                          ),
                        ),
                        GradientText(
                          state.displayDeliveryFee ?? widget.deliveryFee.toFormattedPrice(),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Info Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentStatus == -1)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    state.cancelReason ?? context.tr('order_status.cancel_reason'),
                                    style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFB91C1C)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            _statusDescription(context, storeName),
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Shop logo with lazy-load and error/empty fallback
                            ClipOval(
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: state.logoPath != null && state.logoPath!.isNotEmpty
                                  ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                      imageUrl: state.logoPath!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[100],
                                        child: const Center(child: CustomLoadingIndicator(size: 24)),
                                      ),
                                      errorWidget: (context, url, error) => _buildNoImageAvatar(),
                                    )
                                  : _buildNoImageAvatar(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                storeName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _buildSmallCircleButton(PhosphorIcons.phoneCallFill),
                            const SizedBox(width: 6),
                            _buildSmallCircleButton(
                              PhosphorIcons.chatCircleTextFill,
                              onTap: () => _openChat(
                                name: storeName,
                                subtitle: context.tr('common.restaurant'),
                                avatarUrl: state.logoPath,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('order_status.payment_method'),
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                            ),
                            Row(
                              children: [
                                Icon(PhosphorIcons.qrCode, size: 18, color: const Color(0xFF1E3A8A)),
                                const SizedBox(width: 6),
                                Text(
                                  context.tr('order_status.qr_promptpay'),
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('cart.total'),
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                            ),
                                Row(
                                  children: [
                                    Text(
                                      state.displayTotalAmount ?? total.toFormattedPrice(),
                                      style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (_backendStatus?.toUpperCase() == 'PAID' || _currentStatus >= 2) 
                                            ? const Color(0xFFDCFCE7) 
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        (_backendStatus?.toUpperCase() == 'PAID' || _currentStatus >= 2) ? context.tr('order_status.paid') : context.tr('order_status.waiting_payment'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: (_backendStatus?.toUpperCase() == 'PAID' || _currentStatus >= 2) 
                                              ? const Color(0xFF16A34A) 
                                              : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      iconColor: Colors.grey[400],
                      collapsedIconColor: Colors.grey[400],
                      title: Row(
                        children: [
                          Text(
                            context.tr('order_status.view_summary'),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              if (state.orderItems.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(context.tr('order_status.no_items'), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                )
                              else
                                ...state.orderItems.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        // Item image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                              imageUrl: item.imagePath,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: Colors.grey[100],
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CustomLoadingIndicator(size: 16),
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                color: Colors.grey[100],
                                                child: const Icon(Icons.restaurant, size: 20, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${item.quantity}x ${item.title}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              if (item.variantName != null)
                                                Text(
                                                  item.variantName!,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          (item.price * item.quantity).toFormattedPrice(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(),
                              ),
                              
                              _buildSummaryRow(context.tr('order_status.food_total'), state.displayFoodPrice ?? widget.foodTotal.toFormattedPrice()),
                              const SizedBox(height: 8),
                              _buildSummaryRow(context.tr('order_status.delivery_fee'), state.displayDeliveryFee ?? widget.deliveryFee.toFormattedPrice()),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(),
                              ),
                              _buildSummaryRow(context.tr('order_status.total_amount'), (widget.foodTotal + (state.deliveryFee ?? widget.deliveryFee)).toFormattedPrice(), isBold: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Delivery Info Card
            if (_currentStatus != -1 && (_currentStatus >= 3 || (state.riderName != null && state.riderName!.isNotEmpty)))
              Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
                        style: GoogleFonts.poppins(
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
                          child: _currentStatus == -1 && state.cancelReason != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      context.tr('order_status.cancelled'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      state.cancelReason!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Restaurant row
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          storeName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (state.restaurantAddress != null && state.restaurantAddress!.isNotEmpty)
                                          Text(
                                            state.restaurantAddress!,
                                            style: GoogleFonts.poppins(
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          state.userLocationName ?? context.tr('food.my_location'),
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (state.deliveryAddress != null && state.deliveryAddress!.isNotEmpty)
                                          Text(
                                            state.deliveryAddress!,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                            maxLines: 2,
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
                  if (_currentStatus != -1 && state.riderName != null) ...[
                    const SizedBox(height: 25),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[100],
                            border: Border.all(color: Colors.grey[200]!, width: 1),
                          ),
                          child: const Icon(Icons.person, size: 24, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (state.riderName != null && state.riderName!.trim().isNotEmpty)
                                    ? state.riderName!
                                    : context.tr('order_status.assigning_rider'),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                context.tr('order_status.delivery_rider'),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.riderPhone != null) ...[
                          _buildSmallCircleButton(PhosphorIcons.phoneCallFill),
                          const SizedBox(width: 6),
                        ],
                        _buildSmallCircleButton(
                          PhosphorIcons.chatCircleTextFill,
                          onTap: () => _openChat(
                            name: state.riderName,
                            subtitle: context.tr('order_status.delivery_rider'),
                            fallbackIcon: Icons.delivery_dining_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Stack(
      children: [
        // Background track (Gray line connecting nodes)
        Positioned(
          left: 18,
          right: 18,
          top: 20,
          child: Container(
            height: 3,
            color: Colors.grey.shade200,
          ),
        ),
        // Animated Segments
        Positioned(
          left: 18,
          right: 18,
          top: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double availableWidth = (constraints.maxWidth - 36).clamp(0.0, double.infinity);
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
            _buildStepNode(3, PhosphorIcons.bicycleFill),
            _buildStepNode(4, PhosphorIcons.house),
          ],
        ),
      ],
    );
  }

  Widget _buildSegment({required double width, required bool filled, bool isProcessing = false}) {
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
                            )
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
        boxShadow: isCompleted ? [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ] : null,
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

  void _openChat({
    required String? name,
    required String subtitle,
    String? avatarUrl,
    IconData fallbackIcon = Icons.storefront_rounded,
  }) {
    final peerName = (name == null || name.trim().isEmpty)
        ? subtitle
        : name;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          peerName: peerName,
          peerSubtitle: subtitle,
          avatarUrl: avatarUrl,
          fallbackIcon: fallbackIcon,
        ),
      ),
    );
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

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isBold ? Colors.black : Colors.grey[600],
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  String _statusDescription(BuildContext context, String storeName) {
    final key = switch (_currentStatus) {
      1 => 'order_status.checking_payment_shop',
      2 => 'order_status.preparing_shop',
      3 => 'order_status.delivering_shop',
      _ => 'order_status.completing_shop',
    };
    return context.trArgs(key, {'shop': storeName});
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

