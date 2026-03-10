import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_map_theme.dart';
import '../../../home/presentation/screens/location_search_page.dart';
import 'dart:ui' as ui;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../data/active_order_state.dart';
import 'order_complete_page.dart';

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
  
  late AnimationController _progressAnimController;
  
  // Idle progress animation
  late AnimationController _idleSolidController;
  late AnimationController _lightProgressController;
  Timer? _idleSequenceTimer;

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

    // Step-based animation for progress bar
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), 
    );

    // Solid idle trailing animation
    _idleSolidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Light idle trailing animation
    _lightProgressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // Initial animation position based on starting status
    _animateToStatus(_currentStatus);

    // Connect to WebSockets with force: true to ensure topic subscriptions are refreshed with the current orderId
    WebSocketService().connect(force: true);
    
    _orderSubscription = WebSocketService().orderUpdates.listen((update) {
      if (mounted) {
        setState(() {
          // Map ActiveOrderState orderStatus (0-4) to local _currentStatus (1-4)
          _currentStatus = ActiveOrderState.instance.orderStatus.clamp(1, 4);
          _animateToStatus(_currentStatus); 
        });

        // Auto-navigate when status becomes COMPLETED (4)
        if (ActiveOrderState.instance.orderStatus == 4) {
          Future.delayed(const Duration(seconds: 2), () => _navigateToComplete());
        }
      }
    });
  }

  void _animateToStatus(int status) {
    // Stop any existing idle animation
    _idleSequenceTimer?.cancel();
    _idleSolidController.stop();
    _lightProgressController.stop();
    _idleSolidController.value = 0.0;

    // 1 -> 0.0, 2 -> 0.33, 3 -> 0.66, 4 -> 1.0
    double target = (status - 1) / 3.0;
    
    _progressAnimController.animateTo(target, curve: Curves.easeInOut).then((_) {
      if (mounted && status < 4) {
        _startIdleAnimationSequence();
      }
    });
  }

  void _startIdleAnimationSequence() {
    if (!mounted) return;
    _runSequentialIdleSequence();
  }

  Future<void> _runSequentialIdleSequence() async {
    if (!mounted) return;

    // Stage 0: 0% -> 100% Light Trail (Solid stays at 0)
    _idleSolidController.value = 0.0;
    _lightProgressController.duration = const Duration(seconds: 3);
    await _lightProgressController.forward(from: 0.0);
    if (!mounted) return;
    _lightProgressController.value = 0.0; // Disappear

    // Stage 1: Solid glides to 20%, then light trail runs 20% -> 100%
    await _idleSolidController.animateTo(0.2, duration: const Duration(seconds: 3), curve: Curves.linear);
    if (!mounted) return;
    _lightProgressController.duration = const Duration(seconds: 6); // Slowed down to match visual speed
    await _lightProgressController.forward(from: 0.0);
    if (!mounted) return;
    _lightProgressController.value = 0.0; 

    // Stage 2: Solid glides to 40%, then light trail runs 40% -> 100%
    await _idleSolidController.animateTo(0.4, duration: const Duration(seconds: 4), curve: Curves.linear);
    if (!mounted) return;
    _lightProgressController.duration = const Duration(seconds: 8); // Slowed down
    await _lightProgressController.forward(from: 0.0);
    if (!mounted) return;
    _lightProgressController.value = 0.0;

    // Stage 3: Solid glides to 60%, then light trail runs 60% -> 100%
    await _idleSolidController.animateTo(0.6, duration: const Duration(seconds: 4), curve: Curves.linear);
    if (!mounted) return;
    _lightProgressController.duration = const Duration(seconds: 8); // Slowed down
    await _lightProgressController.forward(from: 0.0);
    if (!mounted) return;
    _lightProgressController.value = 0.0;

    // Stage 4: Solid glides to 70%, then light trail loops
    await _idleSolidController.animateTo(0.7, duration: const Duration(seconds: 4), curve: Curves.linear);
    if (!mounted) return;
    _lightProgressController.duration = const Duration(seconds: 6); 
    _lightProgressController.repeat();
  }

  @override
  void dispose() {
    _idleSequenceTimer?.cancel();
    _idleSolidController.dispose();
    _lightProgressController.dispose();
    _orderSubscription?.cancel();
    _progressAnimController.dispose();
    super.dispose();
  }

  void _navigateToComplete() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OrderCompletePage()),
    );
  }

  void _goHome() {
    _idleSequenceTimer?.cancel();
    _idleSolidController.stop();
    _lightProgressController.stop();
    _orderSubscription?.cancel();
    _progressAnimController.stop();
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }



  Future<void> _buildCustomMarkers() async {
    _homeIcon = await _drawMarkerBitmap(
      icon: Icons.home_rounded,
      bgColor: const Color(0xFFED3973),
      iconColor: Colors.white,
      size: 75,
    );
    _shopIcon = await _drawMarkerBitmap(
      icon: Icons.restaurant,
      bgColor: const Color(0xFFED3973),
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
    canvas.drawCircle(Offset(r, r), r - 4, Paint()..color = bgColor);

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
        color: const Color(0xFFED3973),
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
      if (state.restaurantLatLng != null) state.restaurantLatLng!,
      if (state.userLocation != null) state.userLocation!,
      ...state.routePoints,
    ];
    if (all.isEmpty) return;

    double minLat = all.first.latitude;
    double maxLat = all.first.latitude;
    double minLng = all.first.longitude;
    double maxLng = all.first.longitude;

    for (var p in all) {
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

  String get _statusTitle {
    switch (_currentStatus) {
      case 1:
        return 'Checking your Payment';
      case 2:
        return 'Preparing your order';
      case 3:
        return 'On the way!';
      case 4:
        return 'Arrived!';
      default:
        return 'Processing your order';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ActiveOrderState.instance;
    final storeName = state.restaurantName ?? state.storeName ?? 'Restaurant';
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
              child: Text(
                _statusTitle,
                key: ValueKey<int>(_currentStatus),
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Estimate arrival: ${state.estimatedTime ?? "09:45 PM"}',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            
            // Progress Bar
            _buildProgressBar(),
            const SizedBox(height: 32),

            // Map Embed (only if status >= 3)
            AnimatedSize(
              duration: const Duration(milliseconds: 500),
              child: _currentStatus >= 3 
                ? Column(
                    children: [
                      Container(
                        height: 260,
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: GoogleMap(
                          padding: const EdgeInsets.only(bottom: 0),
                          initialCameraPosition: CameraPosition(
                            target: state.restaurantLatLng ?? const LatLng(13.7563, 100.5018),
                            zoom: 14,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _updateMarkers();
                            Future.delayed(const Duration(milliseconds: 300), _fitBounds);
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
                      const SizedBox(height: 16),
                    ],
                  )
                : const SizedBox.shrink(),
            ),

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
                        Text(
                          '$storeName is ${_currentStatus == 1 ? "checking your payment" : _currentStatus == 2 ? "preparing your order" : _currentStatus == 3 ? "delivering your order" : "completing your order"}',
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
                                  ? Image.network(
                                      state.logoPath!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                        if (wasSynchronouslyLoaded || frame != null) return child;
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFED3973))),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) => _buildNoImageAvatar(),
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
                            _buildCircleButton(PhosphorIcons.phoneCall(PhosphorIconsStyle.fill)),
                            const SizedBox(width: 8),
                            _buildCircleButton(PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Payment Method',
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                            ),
                            Row(
                              children: [
                                Icon(PhosphorIcons.qrCode(), size: 18, color: const Color(0xFF1E3A8A)),
                                const SizedBox(width: 6),
                                Text(
                                  'QR Prompt Pay',
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
                              'Total',
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                            ),
                                Row(
                                  children: [
                                    Text(
                                      state.displayTotalAmount ?? '${total.toStringAsFixed(0)} ฿',
                                      style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
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
                                        (_backendStatus?.toUpperCase() == 'PAID' || _currentStatus >= 2) ? 'Paid' : 'Waiting for Payment',
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
                      tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      iconColor: Colors.grey[400],
                      collapsedIconColor: Colors.grey[400],
                      title: Row(
                        children: [
                          Text(
                            'View order summary',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Small Contact Icons
                          GestureDetector(
                            onTap: () {
                              // Phone logic
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.phone, size: 14, color: Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              // Message logic
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble, size: 14, color: Colors.green),
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
                                  child: Text('No items found', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
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
                                            child: CachedNetworkImage(
                                              imageUrl: item.imagePath,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: Colors.grey[100],
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
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
                                          '${(item.price * item.quantity).toStringAsFixed(0)} ฿',
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
                              
                              _buildSummaryRow('Food Total', state.displayFoodPrice ?? '${widget.foodTotal.toStringAsFixed(0)} ฿'),
                              const SizedBox(height: 8),
                              _buildSummaryRow('Delivery Fee', state.displayDeliveryFee ?? '${widget.deliveryFee.toStringAsFixed(0)} ฿'),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(),
                              ),
                              _buildSummaryRow('Total Amount', state.displayTotalAmount ?? '${(widget.foodTotal + widget.deliveryFee).toStringAsFixed(0)} ฿', isBold: true),
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
            _buildInfoCard(
              title: 'Delivery Information',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFED3973).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on, color: Color(0xFFED3973), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.deliveryAddress ?? 'Current Location',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Your delivery address',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LocationSearchPage()),
                          );
                          if (result != null && mounted) {
                            setState(() {});
                          }
                        },
                        child: Text(
                          'Change',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFED3973),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Text(
                    'Order Summary',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...state.orderItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          '${item.quantity}x ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFED3973),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                        Text(
                          '฿${(item.price * item.quantity).toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background line
        Positioned(
          left: 18,
          right: 18,
          child: Container(
            height: 3,
            color: Colors.grey.shade200,
          ),
        ),
        // Animated fill lines
        Positioned(
          left: 18,
          right: 18,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedBuilder(
                animation: Listenable.merge([_progressAnimController, _idleSolidController, _lightProgressController]),
                builder: (context, child) {
                  final double baseFraction = _progressAnimController.value.clamp(0.0, 1.0);
                  final double segmentWidth = constraints.maxWidth / 3.0;
                  final double baseSolidWidth = constraints.maxWidth * baseFraction;
                  
                  final double idleSolidWidth = segmentWidth * _idleSolidController.value;
                  final double totalSolidWidth = (baseSolidWidth + idleSolidWidth).clamp(0.0, constraints.maxWidth);

                  final double remainingIdleDistance = segmentWidth - idleSolidWidth;
                  final double lightProgressWidthRelative = remainingIdleDistance * _lightProgressController.value;
                  final double totalLightTrailWidth = (totalSolidWidth + lightProgressWidthRelative).clamp(0.0, constraints.maxWidth);

                  final bool isFinalStatus = _currentStatus >= 4;

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      children: [
                        // Light Pink Trail (Underneath/Next to solid)
                        if (!isFinalStatus && totalLightTrailWidth > 0)
                          Container(
                            height: 3,
                            width: totalLightTrailWidth,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB3C6),
                            ),
                          ),
                        // Solid Pink Component (With gradient tip)
                        Container(
                          height: 3,
                          width: isFinalStatus ? constraints.maxWidth : totalSolidWidth,
                          decoration: BoxDecoration(
                            color: const Color(0xFFED3973),
                            gradient: (!isFinalStatus && idleSolidWidth > 0)
                                ? const LinearGradient(
                                    colors: [Color(0xFFED3973), Color(0xFFFFB3C6)],
                                    stops: [0.8, 1.0],
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        // The nodes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepNode(1, PhosphorIcons.wallet()),
            _buildStepNode(2, PhosphorIcons.cookingPot()),
            _buildStepNode(3, PhosphorIcons.moped()),
            _buildStepNode(4, PhosphorIcons.house()),
          ],
        ),
      ],
    );
  }

  Widget _buildStepNode(int stepIndex, IconData icon) {
    bool isCompleted = _currentStatus >= stepIndex;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFED3973) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isCompleted ? const Color(0xFFED3973) : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Icon(
        icon,
        size: 18,
        color: isCompleted ? Colors.white : Colors.grey.shade400,
      ),
    );
  }

  Widget _buildCircleButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBF1), // Light primary color
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: const Color(0xFFED3973), size: 24),
    );
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Container(
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
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
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
}
