import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/cart_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../home/data/repositories/restaurant_repository.dart';
import '../../../home/data/restaurant_data.dart';
import '../../../home/presentation/screens/restaurant_detail_page.dart';
import '../../../home/presentation/screens/menu_detail_page.dart';
import '../../../home/presentation/widgets/image_skeleton_loader.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/presentation/widgets/global_modal.dart';
import '../../../home/presentation/widgets/location_skeleton_loader.dart';
import '../widgets/confirm_remove_modal.dart';
import 'package:dio/dio.dart';
import '../../../../app.dart';
import '../../../../core/network/websocket_service.dart';
import 'order_tracking_page.dart';
import '../../data/active_order_state.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/user_model.dart';
import '../../../home/data/models/shop_dto.dart' show ShopPaymentTypeDto;
import '../../../auth/data/models/user_location_model.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../home/presentation/widgets/location_selection_modal.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';

import '../../../home/data/shop_storage.dart';

class OrderSummaryPage extends StatefulWidget {
  final CartStore store;

  const OrderSummaryPage({super.key, required this.store});

  @override
  State<OrderSummaryPage> createState() => _OrderSummaryPageState();
}

class _OrderSummaryPageState extends State<OrderSummaryPage> {
  bool _isDelivery = true;
  bool _isPriorityDelivery = true;
  String _selectedPaymentMethodCode = 'PROMPTPAY';
  Restaurant? _restaurant;

  bool _isPlacingOrder = false;
  UserLocationModel? _primaryLocation;
  bool _isLoadingLocation = true;
  List<ShopPaymentTypeDto>? _paymentTypes;

  @override
  void initState() {
    super.initState();
    _loadPrimaryLocation();
    if (widget.store.items.isNotEmpty) {
      final restaurantIdString = widget.store.items.first.restaurantId;
      final restaurantId = int.tryParse(restaurantIdString);
      if (restaurantId != null) {
        // 1. Try to load from cache immediately for instant UI
        ShopStorage.getPaymentTypes(restaurantId).then((cachedPaymentTypes) {
          if (mounted && cachedPaymentTypes != null && cachedPaymentTypes.isNotEmpty) {
            setState(() {
              _paymentTypes = cachedPaymentTypes;
              final firstActive = cachedPaymentTypes.where((t) => t.isActive).firstOrNull;
              if (firstActive != null) {
                _selectedPaymentMethodCode = firstActive.paymentMethodCode;
              }
            });
          }
        });

        // 2. Fetch from API to ensure data is fresh
        RestaurantRepository.instance.getShopById(restaurantId).then((shop) {
          if (mounted) {
            setState(() {
              _restaurant = shop;
              _paymentTypes = shop.paymentTypes;
              if (shop.paymentTypes.isNotEmpty) {
                // Only override if the currently selected one is not in the new list or we haven't selected anything yet
                final firstActive = shop.paymentTypes.where((t) => t.isActive).firstOrNull;
                if (firstActive != null) {
                  // If the currently selected code is NOT in the fresh list, or it's just the default, update it
                  final currentStillExists = shop.paymentTypes.any((t) => t.paymentMethodCode == _selectedPaymentMethodCode && t.isActive);
                  if (!currentStillExists) {
                    _selectedPaymentMethodCode = firstActive.paymentMethodCode;
                  }
                }
              }
            });
            _preFetchRoute(); // Start pre-fetching route
          }
        });
      }
    }
  }

  Future<void> _loadPrimaryLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final loc = await UserLocationRepository.instance.getPrimaryLocation(forceRefresh: true);
      if (mounted) {
        setState(() {
          _primaryLocation = loc;
          _isLoadingLocation = false;
        });
        _preFetchRoute(); // Start pre-fetching route
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _preFetchRoute() async {
    if (_restaurant == null || _primaryLocation == null) return;
    if (_primaryLocation!.latitude == null || _primaryLocation!.longitude == null) return;
    if (_restaurant!.latitude == null || _restaurant!.longitude == null) return;
    
    final start = LatLng(_primaryLocation!.latitude!, _primaryLocation!.longitude!);
    final dest = LatLng(_restaurant!.latitude!, _restaurant!.longitude!);
    
    // Only pre-fetch if we don't have route data yet
    if (ActiveOrderState.instance.routePoints.isNotEmpty) return;

    try {
      final dio = Dio();
      final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${dest.longitude},${dest.latitude}?geometries=geojson';
      final response = await dio.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200 && response.data['routes'] != null && (response.data['routes'] as List).isNotEmpty) {
        final route = response.data['routes'][0];
        final List coords = route['geometry']['coordinates'];
        final double distanceM = (route['distance'] as num).toDouble();
        final double durationS = (route['duration'] as num).toDouble();

        final List<LatLng> points = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
        double km = distanceM / 1000;
        final mins = (durationS / 60).ceil();
        
        // --- MOCK SAFEGUARD: Clamp distance to realistic values for demo purposes ---
        if (km > 15.0) km = (km % 10.0) + 2.0; // Randomize between 2km and 12km if wildly off

        ActiveOrderState.instance.updateRouteData(
          points: [start, ...points, dest],
          distanceKm: km,
          durationMins: mins,
          fee: 30.0, // Force mock delivery fee to strictly 30.0
        );
      } else {
        // Fallback to straight line even in pre-fetch if OSRM is up but returns no route
        _setFallbackRoute(start, dest);
      }
    } catch (_) {
      // Fallback to straight line on error/timeout
      _setFallbackRoute(start, dest);
    }
  }

  void _setFallbackRoute(LatLng start, LatLng dest) {
    if (ActiveOrderState.instance.routePoints.isNotEmpty) return;
    
    final distanceM = Geolocator.distanceBetween(
      start.latitude, start.longitude, dest.latitude, dest.longitude);
    double km = distanceM / 1000;
    
    // --- MOCK SAFEGUARD ---
    if (km > 15.0) km = (km % 10.0) + 2.0;
    
    ActiveOrderState.instance.updateRouteData(
      points: [start, dest],
      distanceKm: km,
      durationMins: (km * 2).ceil(),
      fee: 30.0, // Force mock delivery fee to strictly 30.0
    );
  }

  void _showLocationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationSelectionModal(
        onLocationSelected: (place) {
          _loadPrimaryLocation();
        },
      ),
    );
  }


  bool _isProcessing = false;
  bool _hasShownEmptyToast = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, _) {
        // Find store in current state to ensure reactivity
        final currentStoreIdx = CartManager.instance.stores.indexWhere((s) => s.name == widget.store.name);
        
        // Show empty state if store not found or items empty (unless we are performing an action)
        if ((currentStoreIdx == -1 || CartManager.instance.stores[currentStoreIdx].items.isEmpty) && !_isProcessing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && !_hasShownEmptyToast) {
              _hasShownEmptyToast = true;
              App.scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text('Your cart is empty now!', style: GoogleFonts.poppins()),
                  backgroundColor: const Color(0xFFED3973),
                  duration: const Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop();
            }
          });
          return const Scaffold(backgroundColor: Colors.white);
        }
        // Use safe access for the current store. If not found in manager (e.g. just removed), 
        // fallback to the snapshot in widget.store to avoid crashes during transitions.
        final currentStore = (currentStoreIdx != -1) 
            ? CartManager.instance.stores[currentStoreIdx] 
            : widget.store;

        final totalStorePrice = (currentStoreIdx != -1)
            ? CartManager.instance.getStoreTotal(currentStore.name)
            : widget.store.items.fold<double>(0, (sum, item) => sum + (item.price * item.quantity)).toInt();

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                color: Colors.black.withValues(alpha: 0.05),
                height: 1,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              'Order Summary',
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store Header inside a Card-like container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              children: [
                                _buildStoreLogo(currentStore.items.first.restaurantId),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    currentStore.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RestaurantDetailPage(
                                          id: currentStore.items.first.restaurantId,
                                          name: currentStore.name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Add Items',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFF59E0B),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 16),
                            
                            // Items List
                            ...currentStore.items.map((item) => _buildSummaryItem(currentStore.name, item)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Deliver Information Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Image.asset('assets/images/delivery_bike.png', width: 28, height: 28),
                                const SizedBox(width: 8),
                                Text(
                                  'Deliver Information',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Delivery / Pickup Toggle
                            Row(
                              children: [
                                Expanded(
                                  child: Material(
                                    color: _isDelivery ? const Color(0xFFED3973) : const Color(0xFFCBD5E1),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: () => setState(() => _isDelivery = true),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 50,
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Delivery',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Material(
                                    color: !_isDelivery ? const Color(0xFFED3973) : const Color(0xFFCBD5E1),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: () => setState(() => _isDelivery = false),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 50,
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Pickup',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Divider before location
                            if (_isDelivery) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 20),
                              
                              // Address Box
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9), // Light grayish blue
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(PhosphorIconsRegular.mapPin, color: Color(0xFFED3973), size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _isLoadingLocation
                                          ? const LocationSkeletonLoader()
                                          : Text(
                                              _primaryLocation?.address ?? 'No address set',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black87,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _showLocationModal,
                                child: Text(
                                  'Edit Location',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFED3973),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 20),
                              
                              // Delivery Options
                              _buildDeliveryOption(
                                title: 'Priority',
                                isPriority: true,
                                fee: 20,
                                time: '25 mins',
                                hasPromo: true,
                              ),
                              const SizedBox(height: 24),
                              _buildDeliveryOption(
                                title: 'Standard',
                                isPriority: false,
                                fee: 20,
                                time: '28 mins',
                                hasPromo: false,
                              ),
                            ] else ...[
                              // Pickup Information
                              _buildPickupInformation(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Payment Option Section
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Options',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                             // Dynamic Payment Options from Cache/API
                             Builder(
                               builder: (context) {
                                 if (_paymentTypes == null) {
                                   return const Center(child: Padding(
                                     padding: EdgeInsets.all(20.0),
                                     child: CustomLoadingIndicator(size: 30),
                                   ));
                                 }
                                 
                                 final allActive = _paymentTypes!.where((t) => t.isActive).toList();
                                 
                                 // Strictly filter for Prompt Pay and True Money as requested
                                 final paymentTypes = allActive.where((t) => 
                                   t.paymentMethodCode == 'PROMPTPAY' || t.paymentMethodCode == 'TRUEMONEY'
                                 ).toList();

                                 // Fallback: If simulation doesn't have them, inject them for completeness
                                 if (paymentTypes.isEmpty) {
                                   paymentTypes.add(ShopPaymentTypeDto(
                                     paymentMethodId: 1, 
                                     paymentMethodCode: 'PROMPTPAY', 
                                     paymentMethodName: 'Prompt Pay', 
                                     isActive: true
                                   ));
                                   paymentTypes.add(ShopPaymentTypeDto(
                                     paymentMethodId: 2, 
                                     paymentMethodCode: 'TRUEMONEY', 
                                     paymentMethodName: 'True Money', 
                                     isActive: true
                                   ));
                                 }
                                 
                                 return ListView.separated(
                                   shrinkWrap: true,
                                   padding: EdgeInsets.zero,
                                   physics: const NeverScrollableScrollPhysics(),
                                   itemCount: paymentTypes.length,
                                   separatorBuilder: (_, __) => const SizedBox(height: 12),
                                   itemBuilder: (context, index) {
                                     final type = paymentTypes[index];
                                     final bool isPromptPay = type.paymentMethodCode == 'PROMPTPAY';
                                     
                                     return _buildPaymentOptionTile(
                                       type.paymentMethodCode,
                                       isPromptPay ? 'Prompt Pay' : 'True Money Wallet',
                                       Container(
                                         width: 40,
                                         height: 40,
                                         decoration: BoxDecoration(
                                           color: isPromptPay ? const Color(0xFFE0F2FE) : const Color(0xFFFFEDD5),
                                           borderRadius: BorderRadius.circular(12),
                                         ),
                                         child: Icon(
                                           isPromptPay ? PhosphorIconsRegular.qrCode : PhosphorIconsRegular.wallet,
                                           color: isPromptPay ? const Color(0xFF0369A1) : const Color(0xFFD97706),
                                           size: 20,
                                         ),
                                       ),
                                     );
                                   },
                                 );
                               },
                             ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom Checkout Bar
              Container(
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Delivery fee note
                      if (_isDelivery)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          color: const Color(0xFFFEF3C7), // Yellowish orange background
                          child: Text(
                            'Delivery fee is calculated based on distance.',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFD97706), // Orange text
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 28, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF64748B),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  totalStorePrice.toFormattedPrice(),
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFED3973),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_isDelivery)
                                  Text(
                                    ' + Delivery Fee',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFED3973),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 64,
                                child: ElevatedButton(
                                  onPressed: (_isPlacingOrder || _isProcessing) ? null : () async {
                                    setState(() => _isProcessing = true);
                                    final nav = Navigator.of(context);
                                    
                                    final foodTotal = CartManager.instance.getStoreTotal(widget.store.name);
                                    final storeItems = CartManager.instance.stores
                                        .firstWhere((s) => s.name == widget.store.name, orElse: () => widget.store)
                                        .items;

                                    try {
                                      // Instant order placement in mock state
                                      // Generate a mock order ID
                                    String? orderId = "LOCAL-${DateTime.now().millisecondsSinceEpoch}";
                                    int? responseUserId = AuthService().currentUser?.id;

                                    // 1. Register active order in global state
                                    ActiveOrderState.instance.setActiveOrder(
                                      storeName: widget.store.name,
                                      restaurantName: _restaurant?.name ?? widget.store.name,
                                      logoPath: _restaurant?.logoPath,
                                      estimatedTime: _restaurant?.deliveryTime ?? '~30 mins',
                                      orderId: orderId,
                                      restaurantId: _restaurant?.id ?? (widget.store.items.isNotEmpty ? widget.store.items.first.restaurantId : "0"),
                                      shopImageUrl: _restaurant?.imagePath,
                                    );
                                    // Store real location data for Delivery Information display
                                    ActiveOrderState.instance.restaurantAddress =
                                        _restaurant?.address ?? _restaurant?.addressEn ?? _restaurant?.addressTh;
                                    ActiveOrderState.instance.userLocationName =
                                        _primaryLocation?.locationName ?? _primaryLocation?.locationType;
                                    ActiveOrderState.instance.deliveryAddress =
                                        _primaryLocation?.address ?? _primaryLocation?.addressTh;
                                    
                                    // --- MOCK QR CODE FOR AWAITING PAYMENT PAGE ---
                                    ActiveOrderState.instance.getOrder(orderId)?.shopPaymentQrUrl = 
                                        "https://www.octopus.com.hk/en/consumer/customer-service/faq/promptpay/images/promptpay_qr_screen.png";

                                    ActiveOrderState.instance.saveToPrefs(); // persist new fields immediately

                                    // Update User ID in session if it was missing or different
                                    if (responseUserId != null && responseUserId != 0 && AuthService().currentUser?.id != responseUserId) {
                                      final current = AuthService().currentUser;
                                      if (current != null) {
                                        final updatedUser = UserModel(
                                          id: responseUserId,
                                          username: current.username,
                                          email: current.email,
                                          fullName: current.fullName,
                                          role: current.role,
                                        );
                                        AuthService().saveSession(
                                          accessToken: AuthService().accessToken ?? '',
                                          refreshToken: AuthService().refreshToken ?? '',
                                          user: updatedUser,
                                          userLocations: AuthService().userLocations,
                                        );
                                      }
                                    }

                                    // 2. Snapshot order items BEFORE cart is cleared
                                    ActiveOrderState.instance.setOrderDetails(
                                      totalAmount: foodTotal.toDouble() + 30.0,
                                      paymentMethod: _selectedPaymentMethodCode,
                                      items: List.from(storeItems),
                                    );

                                    // 4. Clear cart for this store (And persist to cache)
                                    CartManager.instance.removeStore(widget.store.name);

                                    // Start WebSocket tracking immediately upon successful order creation
                                    WebSocketService().connect();

                                    // 5. Navigate to tracking page (do NOT reset _isProcessing here, as it must stay true to bypass Empty Cart check)
                                    nav.pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => OrderTrackingPage(
                                          store: widget.store,
                                          restaurant: _restaurant,
                                          foodTotal: foodTotal,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    // Only reset loading states on failure so the user can try again
                                    if (mounted) {
                                      setState(() {
                                        _isProcessing = false;
                                        _isPlacingOrder = false;
                                      });
                                    }
                                  }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFED3973),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                'Place Order',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
        );
      },
    );
  }

  int _resolvePaymentMethodId(List<ShopPaymentTypeDto>? paymentTypes, String selectedCode) {
    if (paymentTypes == null || paymentTypes.isEmpty) {
      return 1;
    }
    
    try {
      final match = paymentTypes.firstWhere(
        (type) => type.paymentMethodCode == selectedCode && type.isActive,
      );
      return match.paymentMethodId;
    } catch (_) {
      try {
        return paymentTypes.firstWhere((type) => type.isActive).paymentMethodId;
      } catch (_) {
        return 1;
      }
    }
  }

  Widget _buildPaymentOptionTile(String code, String title, Widget iconWidget) {
    final isSelected = _selectedPaymentMethodCode == code;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethodCode = code),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFED3973) : const Color(0xFF94A3B8),
                  width: 1.5,
                ),
              ),
              child: isSelected ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFED3973),
                    shape: BoxShape.circle,
                  ),
                ),
              ) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6), // Light yellow backgroud
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/pickup_bag.png', width: 60, height: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This is a pickup',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remember to collect your food at the restaurant when it is ready!',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOption({
    required String title,
    required bool isPriority,
    required int fee,
    required String time,
    required bool hasPromo,
  }) {
    final isSelected = _isPriorityDelivery == isPriority;
    return InkWell(
      onTap: () => setState(() => _isPriorityDelivery = isPriority),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFFED3973) : const Color(0xFF94A3B8),
                width: 1.5,
              ),
            ),
            child: isSelected ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFED3973),
                  shape: BoxShape.circle,
                ),
              ),
            ) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (hasPromo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFED3A72), Color(0xFFF97316)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(PhosphorIconsRegular.percent, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Promotion',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(PhosphorIconsRegular.money, color: Color(0xFF94A3B8), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Estimated Delivery Fee  •  ',
                      style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 13),
                    ),
                    Text(
                      fee.toFormattedPrice(),
                      style: GoogleFonts.poppins(color: const Color(0xFFED3973), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(PhosphorIconsRegular.clock, color: Color(0xFF94A3B8), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Estimated Time  •  ',
                      style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 13),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.poppins(color: const Color(0xFFED3973), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreLogo(String restaurantId) {
    final logoPath = _restaurant?.logoPath ?? 'https://mytogether.app/api/restaurant/logo/default.png';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: ClipOval(
        child: (logoPath == null || logoPath.isEmpty || logoPath.contains('default.png'))
          ? Icon(PhosphorIconsRegular.storefront, size: 22, color: Colors.grey[400])
          : CachedNetworkImage(
              imageUrl: logoPath,
              fit: BoxFit.cover,
              placeholder: (context, url) => const ImageSkeletonLoader(),
              errorWidget: (context, url, error) => Icon(PhosphorIconsRegular.storefront, size: 22, color: Colors.grey[400]),
            ),
      ),
    );
  }

  Widget _buildPillQtyBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String storeName, CartItem item) {
    final itemTotalPrice = item.priceValue * item.quantity;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF1F5F9),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: item.imagePath,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                placeholder: (context, url) => const ImageSkeletonLoader(width: 70, height: 70),
                errorWidget: (context, url, error) => Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey[100],
                  child: Center(
                    child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Item Details & Controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Remove Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 0), // Align text baseline/top with image
                        child: Text(
                          item.title.trim().isNotEmpty ? item.title : (item.nameMm ?? ''),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        GlobalModal.show(
                          context: context,
                          child: ConfirmRemoveModal(
                            title: 'Remove Item',
                            message: 'Are you sure you want to remove ${item.title} from your order?',
                            onConfirm: () async {
                                await CartManager.instance.updateItemQuantity(
                                  storeName, 
                                  item.id, 
                                  0,
                                  options: item.options,
                                  optionIds: item.optionIds,
                                  specialInstructions: item.specialInstructions,
                                  variantId: item.variantId,
                                );
                            },
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.only(top: 2), // Visual adjustment to match text cap height
                        color: Colors.transparent,
                        child: Icon(
                          PhosphorIcons.x(),
                          size: 18, // Slightly smaller icon for better alignment with text
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Dynamic Add-ons / Description
                if ((item.variantName?.isNotEmpty ?? false) || (item.variantNameMm?.isNotEmpty ?? false) || (item.options?.isNotEmpty ?? false))
                  Text(
                    '${item.variantName ?? item.variantNameMm ?? ''}${((item.variantName != null || item.variantNameMm != null) && item.options != null && item.options!.isNotEmpty) ? '\n' : ''}${item.options ?? ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                
                if (item.specialInstructions?.isNotEmpty ?? false) ...[
                  if ((item.variantName?.isNotEmpty ?? false) || (item.options?.isNotEmpty ?? false))
                    const SizedBox(height: 4),
                  Text(
                    item.specialInstructions!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFFED3973), // Use brand color for visibility
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
                
                // Price & Quantity Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Prices
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.price.toStringAsFixed(0),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'x${item.quantity}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MenuDetailPage(
                                    id: item.menuItemId.toString(),
                                    restaurantId: item.restaurantId,
                                    title: item.title,
                                    price: item.price,
                                    imagePath: item.imagePath,
                                    restaurantName: storeName,
                                    initialVariantId: item.variantId,
                                    initialOptionIds: item.optionIds,
                                    initialInstructions: item.specialInstructions,
                                    cartItemId: item.id,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                'Edit',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Total + Controls
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          itemTotalPrice.toFormattedPrice(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFED3973),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Quantity Editor
                        Container(
                          height: 38,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9), // Light blue-ish gray
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPillQtyBtn(PhosphorIcons.minus(), () async {
                                if (item.quantity == 1) {
                                  GlobalModal.show(
                                    context: context,
                                    child: ConfirmRemoveModal(
                                      title: 'Remove Item',
                                      message: 'Are you sure you want to remove ${item.title} from your order?',
                                      onConfirm: () async {
                                        await CartManager.instance.updateItemQuantity(
                                          storeName, 
                                          item.id, 
                                          0,
                                          options: item.options,
                                          optionIds: item.optionIds,
                                          specialInstructions: item.specialInstructions,
                                          variantId: item.variantId,
                                        );
                                      },
                                    ),
                                  );
                                } else {
                                    await CartManager.instance.updateItemQuantity(
                                      storeName, 
                                      item.id, 
                                      item.quantity - 1,
                                      options: item.options,
                                      optionIds: item.optionIds,
                                      specialInstructions: item.specialInstructions,
                                      variantId: item.variantId,
                                    );
                                }
                              }),
                              Container(
                                constraints: const BoxConstraints(minWidth: 40),
                                alignment: Alignment.center,
                                child: Text(
                                  '${item.quantity}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              _buildPillQtyBtn(PhosphorIcons.plus(), () async {
                                await CartManager.instance.updateItemQuantity(
                                  storeName, 
                                  item.id, 
                                  item.quantity + 1,
                                  options: item.options,
                                  optionIds: item.optionIds,
                                  specialInstructions: item.specialInstructions,
                                  variantId: item.variantId,
                                );
                              }),
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
        ],
      ),
    );
  }


}
