import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../data/cart_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../home/data/repositories/restaurant_repository.dart';
import '../../../home/data/restaurant_data.dart';
import '../../../home/data/restaurant_order_availability.dart';
import '../../../home/presentation/widgets/order_unavailability_ui.dart';
import '../../../home/presentation/screens/restaurant_detail_page.dart';
import '../../../home/presentation/screens/menu_detail_page.dart';
import '../../../home/presentation/widgets/image_skeleton_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/order_tax.dart';
import '../../../../core/presentation/widgets/global_modal.dart';
import '../../../home/presentation/widgets/location_skeleton_loader.dart';
import '../widgets/confirm_remove_modal.dart';
import 'package:dio/dio.dart';
import '../../../../app.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../../core/network/websocket_service.dart';
import 'order_tracking_page.dart';
import '../../data/active_order_state.dart';
import '../../data/coupon_service.dart';
import '../widgets/coupon_ticket_sheet.dart';
import '../../../coupons/presentation/widgets/coupon_display.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/user_model.dart';
import '../../../home/data/models/shop_dto.dart' show ShopPaymentTypeDto;
import '../../../auth/data/delivery_address_prefs.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../auth/data/session_location_store.dart';
import '../../../home/presentation/screens/location_picker_page.dart';
import '../../../home/presentation/widgets/location_selection_modal.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/location/geo_distance.dart';

import '../../../home/data/shop_storage.dart';

class OrderSummaryPage extends StatefulWidget {
  final CartStore store;

  const OrderSummaryPage({super.key, required this.store});

  @override
  State<OrderSummaryPage> createState() => _OrderSummaryPageState();
}

class _OrderSummaryPageState extends State<OrderSummaryPage> {
  bool _isDelivery = true;
  // bool _isPriorityDelivery = true; // TODO: re-enable with delivery options UI
  int? _selectedPaymentMethodId;
  Restaurant? _restaurant;

  bool _isPlacingOrder = false;
  bool _isVerifyingOrderEligibility = false;
  UserLocationModel? _primaryLocation;
  bool _isLoadingLocation = true;
  List<ShopPaymentTypeDto>? _paymentTypes;

  // Coupons eligible for this shop (raw); the precise discount per coupon is
  // previewed client-side against the current cart. _selectedCoupon is the one
  // the user picked on this page; it's applied to the order at place-order time.
  List<CouponModel> _shopCoupons = const [];
  CouponModel? _selectedCoupon;
  bool _forcedAddressFlowOpen = false;

  @override
  void initState() {
    super.initState();
    _loadPrimaryLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDeliveryAddressIfNeeded();
      if (!GuestAuthGuard.isGuest) {
        setState(() => _isVerifyingOrderEligibility = true);
        ActiveOrderState.instance.hydrateActiveOrdersFromApi().whenComplete(() {
          if (mounted) {
            setState(() => _isVerifyingOrderEligibility = false);
          }
        });
      }
    });
    // Stay in sync with primary-location changes made from any selection path
    // (the modal, or the full search page that may close without a callback).
    UserLocationRepository.instance.addListener(_onLocationRepositoryChanged);
    if (widget.store.items.isNotEmpty) {
      final restaurantIdString = widget.store.items.first.restaurantId;
      final restaurantId = int.tryParse(restaurantIdString);
      if (restaurantId != null) {
        // 1. Try to load from cache immediately for instant UI
        ShopStorage.getPaymentTypes(restaurantId).then((cachedPaymentTypes) {
          if (mounted &&
              cachedPaymentTypes != null &&
              cachedPaymentTypes.isNotEmpty) {
            setState(() {
              _applyPaymentTypes(cachedPaymentTypes);
            });
          }
        });

        // 2. Fetch shop details (restaurant info + route pre-fetch).
        RestaurantRepository.instance.getShopById(restaurantId).then((shop) {
          if (mounted) {
            setState(() => _restaurant = shop);
            _preFetchRoute(); // Start pre-fetching route
          }
        });

        // 3. Fetch the authoritative payment methods for this shop from the
        //    dedicated endpoint: GET /api/user/shops/:shopId/payment-methods.
        _loadShopPaymentMethods(restaurantId);

        // 4. Pre-load this shop's coupons so the "Apply Coupon" row can show
        //    immediately on this page.
        _loadShopCoupons(restaurantId);
      }
    }
  }

  Future<void> _loadShopCoupons(int shopId) async {
    final coupons = await CouponService.instance.fetchByShop(shopId);
    if (!mounted || coupons.isEmpty) return;
    setState(() => _shopCoupons = coupons);

    // Auto-open coupon sheet if none is selected
    if (_selectedCoupon == null) {
      final currentStoreIdx = CartManager.instance.stores.indexWhere(
        (s) => s.nameKey == widget.store.nameKey,
      );
      final currentStore = (currentStoreIdx != -1)
          ? CartManager.instance.stores[currentStoreIdx]
          : widget.store;
      final totalStorePrice = (currentStoreIdx != -1)
          ? CartManager.instance.getStoreTotal(currentStore.nameKey)
          : widget.store.items.fold<double>(0, (sum, item) => sum + (item.price * item.quantity)).toInt();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedCoupon == null) {
          _openCouponSheet(totalStorePrice.toDouble(), currentStore.items);
        }
      });
    }
  }

  /// Coupons that actually apply to the current cart, each with a live,
  /// client-computed discount preview (mirrors the backend).
  List<CouponModel> _applicableCoupons(double subtotal, List<CartItem> items) {
    if (_shopCoupons.isEmpty) return const [];
    final lines = items
        .map<CouponCartLine>(
          (i) => (menuItemId: i.menuItemId, quantity: i.quantity, price: i.price),
        )
        .toList();
    final out = <CouponModel>[];
    for (final c in _shopCoupons) {
      final discount = CouponService.computePreview(
        coupon: c,
        subtotal: subtotal,
        items: lines,
      );
      out.add(c.copyWith(discountPreview: discount));
    }
    return out;
  }

  double _discountForSelected(double subtotal, List<CartItem> items) {
    final coupon = _selectedCoupon;
    if (coupon == null) return 0;
    final lines = items
        .map<CouponCartLine>(
          (i) => (menuItemId: i.menuItemId, quantity: i.quantity, price: i.price),
        )
        .toList();
    return CouponService.computePreview(
      coupon: coupon,
      subtotal: subtotal,
      items: lines,
    );
  }

  Future<void> _openCouponSheet(
    double subtotal,
    List<CartItem> items,
  ) async {
    final applicable = _applicableCoupons(subtotal, items);
    if (applicable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('coupon.none'),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }
    final chosen = await showCouponTicketSheet(
      context: context,
      coupons: applicable,
      selectedId: _selectedCoupon?.id,
    );
    if (!mounted) return;
    setState(() => _selectedCoupon = chosen);
  }

  /// Warns when delivery is farther than [GeoDistance.distanceConfirmThresholdKm].
  /// Shop may still accept — user can continue after confirming.
  Future<bool> _confirmFarDeliveryIfNeeded() async {
    if (!_isDelivery) return true;
    final loc = _primaryLocation;
    final shop = _restaurant;
    final userLat = loc?.latitude;
    final userLon = loc?.longitude;
    final shopLat = shop?.latitude;
    final shopLon = shop?.longitude;
    if (userLat == null ||
        userLon == null ||
        shopLat == null ||
        shopLon == null) {
      return true;
    }
    final km = GeoDistance.haversineKm(userLat, userLon, shopLat, shopLon);
    if (km <= GeoDistance.distanceConfirmThresholdKm) return true;

    if (!mounted) return false;
    final distanceStr = km.toStringAsFixed(1);
    final result = await AppDialog.show<bool>(
      context: context,
      title: context.tr('order.far_delivery_title'),
      content: context.trArgs('order.far_delivery_message', {
        'distance': distanceStr,
        'limit': GeoDistance.distanceConfirmThresholdKm.toStringAsFixed(0),
      }),
      buttonText: context.tr('order.far_delivery_continue'),
      secondaryButtonText: context.tr('common.cancel'),
      onButtonPressed: () => Navigator.pop(context, true),
      onSecondaryPressed: () => Navigator.pop(context, false),
      showCloseIcon: false,
    );
    return result == true;
  }

  Future<void> _loadShopPaymentMethods(int shopId) async {
    try {
      final methods = await RestaurantRepository.instance
          .getShopPaymentMethods(shopId);
      if (!mounted || methods.isEmpty) return;
      setState(() => _applyPaymentTypes(methods));
    } catch (_) {
      // Keep cached / shop-profile payment types as a fallback on failure.
    }
  }

  /// Stores the payment list and keeps the current selection valid, defaulting
  /// to the first active method when nothing valid is selected yet.
  void _applyPaymentTypes(List<ShopPaymentTypeDto> methods) {
    _paymentTypes = methods;
    final active = methods.where((t) => t.isActive).toList();
    final stillValid =
        active.any((t) => t.paymentMethodId == _selectedPaymentMethodId);
    if (!stillValid) {
      _selectedPaymentMethodId = active.isNotEmpty
          ? active.first.paymentMethodId
          : null;
    }
  }

  @override
  void dispose() {
    UserLocationRepository.instance.removeListener(_onLocationRepositoryChanged);
    super.dispose();
  }

  void _onLocationRepositoryChanged() {
    _loadPrimaryLocation(forceRefresh: true);
  }

  bool _hasSavedDeliveryAddress() {
    final loc = _primaryLocation;
    return loc != null &&
        loc.id > 0 &&
        (loc.streetAddress?.trim().isNotEmpty ?? false);
  }

  Future<void> _ensureDeliveryAddressIfNeeded() async {
    if (!_isDelivery || GuestAuthGuard.isGuest || !mounted) return;
    if (_forcedAddressFlowOpen) return;
    if (!await DeliveryAddressPrefs.requiresForcedSetup()) return;
    await _openForcedAddressSetup();
  }

  Future<void> _openForcedAddressSetup() async {
    if (_forcedAddressFlowOpen || !mounted) return;
    _forcedAddressFlowOpen = true;
    try {
      final saved = await Navigator.of(context).push<UserLocationModel>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const LocationPickerPage(forcedSetup: true),
        ),
      );
      if (saved != null && mounted) {
        await _loadPrimaryLocation(forceRefresh: true);
      }
    } finally {
      _forcedAddressFlowOpen = false;
    }
  }

  Future<bool> _ensureSavedDeliveryAddressForOrder() async {
    if (!_isDelivery) return true;
    if (_hasSavedDeliveryAddress()) {
      if (await DeliveryAddressPrefs.requiresForcedSetup()) {
        await DeliveryAddressPrefs.setCompletedSetup(true);
      }
      return true;
    }
    if (await DeliveryAddressPrefs.requiresForcedSetup()) {
      await _openForcedAddressSetup();
    }
    if (!mounted) return false;
    return _hasSavedDeliveryAddress();
  }

  Future<void> _loadPrimaryLocation({bool forceRefresh = false}) async {
    try {
      var loc = UserLocationRepository.instance.activeLocation;
      loc ??= await UserLocationRepository.instance
          .getPrimaryLocation(forceRefresh: forceRefresh);

      if (loc != null &&
          loc.streetAddress == null &&
          loc.latitude != null &&
          loc.longitude != null) {
        final stored = await SessionLocationStore.addressNear(
          loc.latitude!,
          loc.longitude!,
        );
        if (stored != null) {
          loc = loc.copyWith(address: stored);
        }
      }

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
    if (_primaryLocation!.latitude == null ||
        _primaryLocation!.longitude == null) {
      return;
    }
    if (_restaurant!.latitude == null || _restaurant!.longitude == null) return;

    final start = LatLng(
      _primaryLocation!.latitude!,
      _primaryLocation!.longitude!,
    );
    final dest = LatLng(_restaurant!.latitude!, _restaurant!.longitude!);

    // Only pre-fetch if we don't have route data yet
    if (ActiveOrderState.instance.routePoints.isNotEmpty) return;

    try {
      final dio = Dio();
      final url =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${dest.longitude},${dest.latitude}?geometries=geojson';
      final response = await dio.get(url).timeout(const Duration(seconds: 5));

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

        ActiveOrderState.instance.updateRouteData(
          points: [start, ...points, dest],
          distanceKm: km,
          durationMins: mins,
          fee: (30.0 + (km * 15.0)).roundToDouble(),
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
      start.latitude,
      start.longitude,
      dest.latitude,
      dest.longitude,
    );
    final km = distanceM / 1000;

    ActiveOrderState.instance.updateRouteData(
      points: [start, dest],
      distanceKm: km,
      durationMins: (km * 2).ceil(),
      fee: (30.0 + (km * 15.0)).roundToDouble(),
    );
  }

  Widget _buildAddressText() {
    final loc = _primaryLocation;
    final address = loc?.streetAddress;
    final subtitle = loc?.detailSubtitle;

    if (loc == null || address == null || address.isEmpty) {
      return Text(
        context.tr('cart.no_address'),
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.black87,
          height: 1.5,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
      ],
    );
  }

  /// Street address sent on order creation.
  String? _primaryLocationAddressText() {
    return _primaryLocation?.streetAddress;
  }

  /// Address fields accepted by `CreateUserOrderDto` on the backend.
  Map<String, dynamic> _orderLocationPayload() {
    final loc = _primaryLocation;
    if (loc == null) return {};

    final payload = <String, dynamic>{};
    final address = _primaryLocationAddressText();
    if (address != null) payload['address'] = address;

    final addressMm = loc.addressMm?.trim();
    if (addressMm != null && addressMm.isNotEmpty) {
      payload['addressMm'] = addressMm;
    }

    final buildingName = loc.buildingName?.trim();
    if (buildingName != null && buildingName.isNotEmpty) {
      payload['buildingName'] = buildingName;
    }

    final floor = loc.floor?.trim();
    if (floor != null && floor.isNotEmpty) payload['floor'] = floor;

    final note = loc.note?.trim();
    if (note != null && note.isNotEmpty) payload['note'] = note;

    return payload;
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

  RestaurantOrderAvailability? get _orderAvailability {
    final restaurant = _restaurant;
    if (restaurant == null) return null;
    return RestaurantOrderAvailability.of(restaurant);
  }

  bool get _isShopClosed =>
      _orderAvailability?.reason == OrderBlockReason.closed;

  void _showPlacementBlockedSnackBar(CanPlaceOrderResult result) {
    if (!mounted) return;
    final message = switch (result) {
      CanPlaceOrderResult.checkFailed =>
        context.tr('cart.order_status_check_failed'),
      CanPlaceOrderResult.hasOngoingOrder ||
      CanPlaceOrderResult.allowed =>
        context.tr('cart.ongoing_order_wait'),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  Future<void> _onPlaceOrderPressed() async {
    if (_isProcessing || _isPlacingOrder) return;

    if (GuestAuthGuard.isGuest) {
      await GuestAuthGuard.requireAccount(context);
      return;
    }

    setState(() {
      _isProcessing = true;
      _isPlacingOrder = true;
    });
    ActiveOrderState.instance.beginOrderPlacement();

    try {
      if (_isDelivery) {
        final hasAddress = await _ensureSavedDeliveryAddressForOrder();
        if (!hasAddress) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr('location.forced_setup_required'),
                ),
                backgroundColor: AppColors.primary,
              ),
            );
          }
          return;
        }
      }

      final eligibility =
          await ActiveOrderState.instance.ensureCanPlaceNewOrder();
      if (eligibility != CanPlaceOrderResult.allowed) {
        _showPlacementBlockedSnackBar(eligibility);
        return;
      }

      if (!await _confirmFarDeliveryIfNeeded()) {
        return;
      }

      final nav = Navigator.of(context);
      final foodTotal =
          CartManager.instance.getStoreTotal(widget.store.nameKey);
      final storeItems = CartManager.instance.stores
          .firstWhere(
            (s) => s.nameKey == widget.store.nameKey,
            orElse: () => widget.store,
          )
          .items;

      final response = await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/user/orders',
        data: {
          "shopId":
              int.tryParse(
                _restaurant?.id ??
                    widget.store.items.first.restaurantId,
              ) ??
              0,
          "orderType": _isDelivery ? "DELIVERY" : "PICK_UP",
          if (_primaryLocation?.latitude != null)
            "lat": _primaryLocation!.latitude,
          if (_primaryLocation?.longitude != null)
            "lon": _primaryLocation!.longitude,
          ..._orderLocationPayload(),
          "paymentMethodId": _resolvePaymentMethodId(
            _paymentTypes,
            _selectedPaymentMethodId,
          ),
          "items": storeItems
              .map(
                (item) => {
                  "menuItemId": item.menuItemId,
                  "quantity": item.quantity,
                  if (item.variantId != null && item.variantId! > 0)
                    "variantId": item.variantId,
                  if ((item.specialInstructions ?? "").isNotEmpty)
                    "specialInstructions": item.specialInstructions,
                  if ((item.optionIds ?? []).isNotEmpty)
                    "menuItemOptionId": item.optionIds,
                },
              )
              .toList(),
        },
      );

      final d = response.data;

      String? orderId;
      String? lastOrderNo;
      int? responseUserId;
      Map<String, dynamic>? responseData;

      if (d['data'] is Map) {
        responseData = d['data'] as Map<String, dynamic>;
        orderId = (responseData['id'] ??
                responseData['orderId'] ??
                responseData['order_id'])
            ?.toString();
        lastOrderNo = responseData['lastOrderNo']?.toString();
        responseUserId =
            (responseData['userId'] ?? responseData['user_id']) as int?;
      } else if (d['data'] != null) {
        orderId = d['data'].toString();
      }

      orderId ??= (d['id'] ?? d['orderId'])?.toString();
      responseUserId ??= (d['userId'] ?? d['user_id']) as int?;

      ActiveOrderState.instance.setActiveOrder(
        storeName: widget.store.name,
        restaurantName: _restaurant?.name ?? widget.store.name,
        logoPath: _restaurant?.logoPath,
        estimatedTime: _restaurant?.deliveryTime ?? '~30 mins',
        orderId: orderId,
        restaurantId:
            _restaurant?.id ?? widget.store.items.first.restaurantId,
        orderType: _isDelivery ? 'DELIVERY' : 'PICK_UP',
        lastOrderNo: lastOrderNo,
      );
      ActiveOrderState.instance.restaurantAddress =
          _restaurant?.address ??
          _restaurant?.addressEn ??
          _restaurant?.addressTh;
      ActiveOrderState.instance.userLocationName = null;
      ActiveOrderState.instance.deliveryAddress =
          _primaryLocationAddressText();
      ActiveOrderState.instance.saveToPrefs();

      if (responseUserId != null &&
          responseUserId != 0 &&
          AuthService().currentUser?.id != responseUserId) {
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

      final selectedMethodId = _resolvePaymentMethodId(
        _paymentTypes,
        _selectedPaymentMethodId,
      );
      final selectedMethodImage = _resolvePaymentMethodImageUrl(
        _paymentTypes,
        _selectedPaymentMethodId,
      );
      if (!context.mounted) return;

      final backendItemPrice =
          (responseData?['itemPrice'] as num?)?.toDouble() ??
          foodTotal.toDouble();
      final orderTaxEnable = _restaurant?.taxEnable ?? true;
      final backendTaxAmount =
          (responseData?['taxAmount'] as num?)?.toDouble() ??
          OrderTax.resolveTaxAmount(backendItemPrice, orderTaxEnable);
      final backendTotalAmount =
          (responseData?['totalAmount'] as num?)?.toDouble() ??
          OrderTax.calculateTotal(
            itemSubtotal: backendItemPrice,
            taxEnable: orderTaxEnable,
          );
      final backendDisplayTax =
          responseData?['displayTaxAmount']?.toString();

      ActiveOrderState.instance.setOrderDetails(
        totalAmount: backendTotalAmount,
        itemPrice: backendItemPrice,
        taxAmount: backendTaxAmount,
        displayTaxAmount: backendDisplayTax,
        taxEnable: orderTaxEnable,
        paymentMethod:
            _selectedPaymentType?.displayName ?? context.tr('cart.payment'),
        paymentMethodId: selectedMethodId,
        paymentMethodImageUrl: selectedMethodImage,
        items: List.from(storeItems),
        orderId: orderId,
      );

      if (responseData != null && orderId != null) {
        ActiveOrderState.instance.updateFromSocket({
          ...responseData,
          'orderId': orderId,
        });
      }

      await CartManager.instance.removeStore(widget.store.nameKey);

      WebSocketService().connect();

      await _applySelectedCoupon(
        orderId,
        foodTotal.toDouble(),
        storeItems,
      );

      if (!context.mounted) return;
      nav.pushReplacement(
        MaterialPageRoute(
          builder: (context) => OrderTrackingPage(
            store: widget.store,
            restaurant: _restaurant,
            foodTotal: backendItemPrice.round(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is DioException) {
          errorMsg = e.response?.data?.toString() ??
              e.message ??
              LocaleController.instance.tr('cart.unknown_error');
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocaleController.instance.trArgs(
                'cart.place_order_failed',
                {'error': errorMsg},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ActiveOrderState.instance.endOrderPlacement();
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        CartManager.instance,
        ActiveOrderState.instance,
      ]),
      builder: (context, _) {
        final hasOngoingOrder = ActiveOrderState.instance.hasActiveOrder;
        final orderAvailability = _orderAvailability;
        final isShopClosed = _isShopClosed;
        // Find store in current state to ensure reactivity
        final currentStoreIdx = CartManager.instance.stores.indexWhere(
          (s) => s.nameKey == widget.store.nameKey,
        );

        // Show empty state if store not found or items empty (unless we are performing an action)
        if ((currentStoreIdx == -1 ||
                CartManager.instance.stores[currentStoreIdx].items.isEmpty) &&
            !_isProcessing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && !_hasShownEmptyToast) {
              _hasShownEmptyToast = true;
              App.scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                    context.tr('cart.empty_now'),
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppColors.primary,
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
            ? CartManager.instance.getStoreTotal(currentStore.nameKey)
            : widget.store.items
                  .fold<double>(
                    0,
                    (sum, item) => sum + (item.price * item.quantity),
                  )
                  .toInt();

        final foodSubtotal = totalStorePrice.toDouble();
        final taxEnable = _restaurant?.taxEnable ?? true;
        final taxAmount =
            OrderTax.resolveTaxAmount(foodSubtotal, taxEnable);
        final checkoutTotal = OrderTax.calculateTotal(
          itemSubtotal: foodSubtotal,
          taxEnable: taxEnable,
        );
        final couponDiscount =
            _discountForSelected(foodSubtotal, currentStore.items);
        final payableTotal =
            (checkoutTotal - couponDiscount).clamp(0, double.infinity).toDouble();

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
              context.tr('cart.order_summary'),
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
                      // Notice to check before order
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              PhosphorIconsFill.info,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.tr('cart.check_order_notice'),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF991B1B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Store Header inside a Card-like container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              children: [
                                _buildStoreLogo(
                                  currentStore.items.first.restaurantId,
                                ),
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
                                        builder: (context) =>
                                            RestaurantDetailPage(
                                              id: currentStore
                                                  .items
                                                  .first
                                                  .restaurantId,
                                              name: currentStore.name,
                                            ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    context.tr('cart.add_items'),
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
                            ...currentStore.items.map(
                              (item) =>
                                  _buildSummaryItem(currentStore.name, item),
                            ),
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
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'assets/images/delivery_bike.png',
                                  width: 28,
                                  height: 28,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.tr('cart.delivery_info'),
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
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: _isDelivery
                                          ? AppColors.primaryGradient
                                          : null,
                                      color: _isDelivery
                                          ? null
                                          : const Color(0xFFCBD5E1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () async {
                                        setState(() => _isDelivery = true);
                                        await _ensureDeliveryAddressIfNeeded();
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 50,
                                        alignment: Alignment.center,
                                        child: Text(
                                          context.tr('cart.delivery'),
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
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: !_isDelivery
                                          ? AppColors.primaryGradient
                                          : null,
                                      color: !_isDelivery
                                          ? null
                                          : const Color(0xFFCBD5E1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _isDelivery = false),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 50,
                                        alignment: Alignment.center,
                                        child: Text(
                                          context.tr('cart.pickup'),
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
                              const Divider(
                                height: 1,
                                color: Color(0xFFE2E8F0),
                              ),
                              const SizedBox(height: 20),

                              // Address Box
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF1F5F9,
                                  ), // Light grayish blue
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      PhosphorIconsRegular.mapPin,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _isLoadingLocation
                                          ? const LocationSkeletonLoader()
                                          : _buildAddressText(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _showLocationModal,
                                child: Text(
                                  context.tr('cart.edit_location'),
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (ActiveOrderState.instance.deliveryFee !=
                                      null &&
                                  ActiveOrderState.instance.deliveryFee! >
                                      0) ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Icon(
                                      PhosphorIconsRegular.money,
                                      color: Color(0xFF94A3B8),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      context.tr('cart.est_delivery_fee'),
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 13,
                                      ),
                                    ),
                                    GradientText(
                                      ActiveOrderState
                                          .instance.deliveryFee!
                                          .toFormattedPrice(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Delivery fee estimate appears after shop confirms.
                              /*
                              const SizedBox(height: 20),
                              const Divider(
                                height: 1,
                                color: Color(0xFFE2E8F0),
                              ),
                              const SizedBox(height: 20),

                              // Delivery Options
                              _buildDeliveryOption(
                                title: context.tr('cart.priority'),
                                isPriority: true,
                                fee: 20,
                                time: '25 mins',
                                hasPromo: true,
                              ),
                              const SizedBox(height: 24),
                              _buildDeliveryOption(
                                title: context.tr('cart.standard'),
                                isPriority: false,
                                fee: 20,
                                time: '28 mins',
                                hasPromo: false,
                              ),
                              */
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
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('cart.payment_options'),
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
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.0),
                                      child: CustomLoadingIndicator(size: 30),
                                    ),
                                  );
                                }

                                final allPaymentTypes = _paymentTypes!
                                    .where((t) => t.isActive)
                                    .toList();

                                // Filter based on delivery/pickup status
                                final paymentTypes = allPaymentTypes.where((
                                  type,
                                ) {
                                  if (type.isCashOnDelivery && _isDelivery) {
                                    return false;
                                  }
                                  return true;
                                }).toList();

                                if (paymentTypes.isEmpty) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      context.tr('cart.no_payment_methods'),
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF64748B),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: paymentTypes.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final type = paymentTypes[index];

                                    return _buildPaymentOptionTile(
                                      type.paymentMethodId,
                                      type.displayName,
                                      _buildPaymentIcon(type),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Apply Coupon entry (opens the movie-ticket sheet).
                      _buildCouponSection(foodSubtotal, currentStore.items),
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
                    top: BorderSide(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 28, 4),
                        child: Column(
                          children: [
                            _buildCheckoutPriceRow(
                              context.tr('order_status.food_total'),
                              foodSubtotal.toFormattedPrice(),
                            ),
                            if (taxEnable) ...[
                              const SizedBox(height: 6),
                              _buildCheckoutPriceRow(
                                context.tr('order_status.tax'),
                                taxAmount.toFormattedPrice(),
                              ),
                            ],
                            if (couponDiscount > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _selectedCoupon?.name.isNotEmpty == true
                                          ? _selectedCoupon!.name
                                          : context.tr('order_status.discount'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '- ${couponDiscount.toFormattedPrice()}',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _isDelivery
                                      ? context.tr('cart.total_pay_now')
                                      : context.tr('cart.total'),
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF64748B),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                GradientText(
                                  payableTotal.toFormattedPrice(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (hasOngoingOrder)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      PhosphorIconsRegular.info,
                                      size: 18,
                                      color: Color(0xFFDC2626),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        context.tr('cart.ongoing_order_wait'),
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFDC2626),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (isShopClosed && orderAvailability != null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: RestaurantOrderStatusStrip(
                            message: orderAvailability.statusStripText(context),
                            reason: OrderBlockReason.closed,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: PrimaryGradientButton(
                          onPressed: (_isPlacingOrder ||
                                  _isProcessing ||
                                  _isVerifyingOrderEligibility ||
                                  hasOngoingOrder ||
                                  isShopClosed)
                              ? null
                              : _onPlaceOrderPressed,
                          isLoading: _isPlacingOrder,
                          child: Text(
                            isShopClosed
                                ? context.tr('cart.closed_now')
                                : context.tr('cart.place_order'),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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

  /// Applies the coupon the user selected on the summary page to the
  /// just-created PENDING order, then stores the authoritative totals. Any
  /// failure is surfaced as a toast but never blocks reaching the tracking page.
  Future<void> _applySelectedCoupon(
    String? orderId,
    double subtotal,
    List<CartItem> items,
  ) async {
    final coupon = _selectedCoupon;
    if (coupon == null) return;
    final couponOrderId = int.tryParse((orderId ?? '').replaceAll('#', ''));
    if (couponOrderId == null) return;

    // Skip if the selection no longer applies to the final cart.
    if (_discountForSelected(subtotal, items) <= 0) return;

    try {
      final result = await CouponService.instance.apply(
        orderId: couponOrderId,
        couponId: coupon.id,
      );
      ActiveOrderState.instance.applyCoupon(
        discountAmount: result.discountAmount,
        itemPrice: result.itemPrice,
        taxAmount: result.taxAmount,
        totalAmount: result.totalAmount,
        couponName: result.couponName,
        couponCode: result.couponCode,
        orderId: orderId,
      );
    } catch (e) {
      if (!mounted) return;
      final message =
          e is CouponApplyException ? e.message : context.tr('coupon.apply_failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  /// Subtitle under "Apply Coupon" when a coupon is selected.
  String _couponSelectionSubtitle(
    BuildContext context,
    CouponModel coupon,
    double discount,
  ) {
    if (coupon.isFreeItem) {
      final gift = couponBogoGiftSummary(context, coupon);
      if (discount > 0) {
        return '${coupon.name}  •  $gift  •  - ${discount.toFormattedPrice()}';
      }
      return '${coupon.name}  •  $gift';
    }
    return '${coupon.name}  •  - ${discount.toFormattedPrice()}';
  }

  /// The "Apply Coupon" card shown on the summary page. Hidden when the shop has
  /// no coupons that apply to the current cart (and none is selected).
  Widget _buildCouponSection(double subtotal, List<CartItem> items) {
    final applicable = _applicableCoupons(subtotal, items);
    final discount = _discountForSelected(subtotal, items);
    final hasSelection = _selectedCoupon != null;
    final hasCoupons = _shopCoupons.isNotEmpty;
    final isHighlighted = hasSelection || hasCoupons;

    if (!hasSelection && applicable.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        decoration: BoxDecoration(
          color: isHighlighted 
              ? AppColors.primary.withValues(alpha: 0.04) 
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted
                ? AppColors.primary.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openCouponSheet(subtotal, items),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    PhosphorIconsFill.ticket,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('coupon.apply_title'),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isHighlighted ? AppColors.primary : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSelection
                            ? _couponSelectionSubtitle(
                                context,
                                _selectedCoupon!,
                                discount,
                              )
                            : (hasCoupons
                                ? '✨ ${context.tr('coupon.apply_hint')}'
                                : context.tr('coupon.apply_hint')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight:
                              isHighlighted ? FontWeight.w600 : FontWeight.w400,
                          color: isHighlighted
                              ? AppColors.primary
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (hasSelection) ...[
                  _CouponRowIconButton(
                    icon: PhosphorIconsRegular.arrowsLeftRight,
                    tooltip: context.tr('coupon.change'),
                    color: AppColors.primary,
                    onTap: () => _openCouponSheet(subtotal, items),
                  ),
                  const SizedBox(width: 4),
                  _CouponRowIconButton(
                    icon: PhosphorIconsRegular.x,
                    tooltip: context.tr('coupon.remove'),
                    color: Colors.grey.shade600,
                    onTap: () => setState(() => _selectedCoupon = null),
                  ),
                ] else
                  Container(
                    padding: EdgeInsets.all(isHighlighted ? 4 : 0),
                    decoration: isHighlighted ? BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ) : null,
                    child: Icon(
                      PhosphorIconsRegular.caretRight,
                      size: isHighlighted ? 14 : 18,
                      color: isHighlighted ? Colors.white : Colors.grey[400],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The currently selected payment method, or the first active one.
  ShopPaymentTypeDto? get _selectedPaymentType {
    final types = _paymentTypes;
    if (types == null || types.isEmpty) return null;
    final active = types.where((t) => t.isActive).toList();
    if (active.isEmpty) return null;
    return active.firstWhere(
      (t) => t.paymentMethodId == _selectedPaymentMethodId,
      orElse: () => active.first,
    );
  }

  int _resolvePaymentMethodId(
    List<ShopPaymentTypeDto>? paymentTypes,
    int? selectedId,
  ) {
    if (paymentTypes == null || paymentTypes.isEmpty) {
      return selectedId ?? 1;
    }
    final active = paymentTypes.where((t) => t.isActive).toList();
    final match = active
        .where((t) => t.paymentMethodId == selectedId)
        .firstOrNull;
    if (match != null) return match.paymentMethodId;
    if (active.isNotEmpty) return active.first.paymentMethodId;
    return selectedId ?? 1;
  }

  String? _resolvePaymentMethodImageUrl(
    List<ShopPaymentTypeDto>? paymentTypes,
    int? selectedId,
  ) {
    if (paymentTypes == null || paymentTypes.isEmpty) return null;
    final active = paymentTypes.where((t) => t.isActive).toList();
    final match =
        active.where((t) => t.paymentMethodId == selectedId).firstOrNull;
    if (match == null) return null;
    return _normalizeImageUrl(match.qrImageUrl);
  }

  /// Rewrites a stored image path/URL to an absolute, reachable URL.
  String? _normalizeImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var imageUrl = raw.replaceAll('\\', '/');
    if (imageUrl.startsWith('http://localhost') ||
        imageUrl.startsWith('http://10.0.2.2')) {
      imageUrl = imageUrl.replaceAll(
        RegExp(r'http://(localhost|10\.0\.2\.2)(:\d+)?'),
        ApiClient.baseUrl,
      );
    } else if (!imageUrl.startsWith('http')) {
      imageUrl = imageUrl.startsWith('/')
          ? '${ApiClient.baseUrl}$imageUrl'
          : '${ApiClient.baseUrl}/$imageUrl';
    }
    return imageUrl;
  }

  /// Renders the payment-method avatar: the backend icon when available,
  /// otherwise a sensible Phosphor fallback based on the method type.
  Widget _buildPaymentIcon(ShopPaymentTypeDto type) {
    final iconUrl = _normalizeImageUrl(type.iconUrl);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: iconUrl != null
          ? CachedNetworkImage(
              imageUrl: iconUrl,
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorWidget: (context, url, error) =>
                  _fallbackPaymentIcon(type),
            )
          : _fallbackPaymentIcon(type),
    );
  }

  Widget _fallbackPaymentIcon(ShopPaymentTypeDto type) {
    return Center(
      child: Icon(
        type.isCashOnDelivery
            ? PhosphorIconsRegular.money
            : type.qrImageUrl != null && type.qrImageUrl!.isNotEmpty
            ? PhosphorIconsRegular.qrCode
            : PhosphorIconsRegular.creditCard,
        color: const Color(0xFF64748B),
        size: 20,
      ),
    );
  }

  Widget _buildPaymentOptionTile(int id, String title, Widget iconWidget) {
    final isSelected = _selectedPaymentMethodId == id;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethodId = id),
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
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFF94A3B8),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
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
              Image.asset(
                'assets/images/pickup_bag.png',
                width: 60,
                height: 60,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('cart.pickup_note_title'),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('cart.pickup_note_body'),
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

  // TODO: re-enable with priority / standard delivery selection UI above
  /*
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
                color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
                width: 1.5,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              PhosphorIconsRegular.percent,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('cart.promotion'),
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
                    const Icon(
                      PhosphorIconsRegular.money,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('cart.est_delivery_fee'),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                    GradientText(
                      fee.toFormattedPrice(),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.clock,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('cart.est_time'),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                    GradientText(
                      time,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
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
  */

  Widget _buildStoreLogo(String restaurantId) {
    final logoPath =
        _restaurant?.logoPath ??
        'https://mytogether.app/api/restaurant/logo/default.png';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: ClipOval(
        child: logoPath.isEmpty
            ? Icon(PhosphorIcons.storefront, size: 24, color: Colors.grey)
            : CachedNetworkImage(
                imageUrl: logoPath,
                fit: BoxFit.cover,
                width: 48,
                height: 48,
                errorWidget: (context, url, error) => Icon(
                  PhosphorIcons.storefront,
                  size: 24,
                  color: Colors.grey,
                ),
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

  Widget _buildCheckoutPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: const Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
                fit: BoxFit.cover,
                width: 70,
                height: 70,
                placeholder: (context, url) => const ImageSkeletonLoader(width: 70, height: 70),
                errorWidget: (context, url, error) => Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey[100],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                    ],
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
                        padding: const EdgeInsets.only(
                          top: 0,
                        ), // Align text baseline/top with image
                        child: Text(
                          item.title,
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
                            title: context.tr('cart.remove_item'),
                            message: context.trArgs('cart.remove_item_confirm',
                                {'name': item.title}),
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
                        padding: const EdgeInsets.only(
                          top: 2,
                        ), // Visual adjustment to match text cap height
                        color: Colors.transparent,
                        child: Icon(
                          PhosphorIcons.x,
                          size:
                              18, // Slightly smaller icon for better alignment with text
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Dynamic Add-ons / Description
                if ((item.variantName?.isNotEmpty ?? false) ||
                    (item.variantNameMm?.isNotEmpty ?? false) ||
                    (item.options?.isNotEmpty ?? false))
                  Text(
                    '${item.variantName ?? item.variantNameMm ?? ''}${((item.variantName != null || item.variantNameMm != null) && item.options != null && item.options!.isNotEmpty) ? '\n' : ''}${item.options ?? ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),

                if (item.specialInstructions?.isNotEmpty ?? false) ...[
                  if ((item.variantName?.isNotEmpty ?? false) ||
                      (item.options?.isNotEmpty ?? false))
                    const SizedBox(height: 4),
                  Text(
                    item.specialInstructions!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color:
                          AppColors.primary, // Use brand color for visibility
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
                                    initialInstructions:
                                        item.specialInstructions,
                                    cartItemId: item.id,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Text(
                                context.tr('common.edit'),
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
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Quantity Editor
                        Container(
                          height: 38,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF1F5F9,
                            ), // Light blue-ish gray
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPillQtyBtn(PhosphorIcons.minus, () async {
                                if (item.quantity == 1) {
                                  GlobalModal.show(
                                    context: context,
                                    child: ConfirmRemoveModal(
                                      title: context.tr('cart.remove_item'),
                                      message: context.trArgs(
                                          'cart.remove_item_confirm',
                                          {'name': item.title}),
                                      onConfirm: () async {
                                        await CartManager.instance
                                            .updateItemQuantity(
                                              storeName,
                                              item.id,
                                              0,
                                              options: item.options,
                                              optionIds: item.optionIds,
                                              specialInstructions:
                                                  item.specialInstructions,
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
                                    specialInstructions:
                                        item.specialInstructions,
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
                              _buildPillQtyBtn(PhosphorIcons.plus, () async {
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

class _CouponRowIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _CouponRowIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
