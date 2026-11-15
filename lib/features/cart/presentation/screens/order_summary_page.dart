import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/utils/firebase_error_handler.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../data/cart_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../home/data/repositories/restaurant_repository.dart';
import '../../../home/data/restaurant_data.dart';
import '../../../home/data/restaurant_order_availability.dart';
import '../../../home/presentation/widgets/order_unavailability_ui.dart';
import '../../../home/presentation/widgets/my_together_verified_badge.dart';
import '../../../home/presentation/screens/restaurant_detail_page.dart';
import '../../../home/presentation/screens/menu_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/order_tax.dart';
import '../../../../core/utils/delivery_fee_estimate.dart';
import '../../../home/data/new_user_free_delivery.dart';
import '../../../../core/presentation/widgets/global_modal.dart';
import '../../../../core/presentation/widgets/animated_dots_text.dart';
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
import '../../../../core/network/dio_error_message.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/user_model.dart';
import '../../../home/data/models/shop_dto.dart' show ShopPaymentTypeDto;
import '../../../auth/data/delivery_address_prefs.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../auth/data/session_location_store.dart';
import '../../../home/presentation/screens/location_picker_page.dart';
import '../../../home/presentation/widgets/location_selection_modal.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/location/geo_distance.dart';
import '../../../../core/location/location_search_service.dart';
import '../../../../core/presentation/widgets/menu_image_placeholder.dart';
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
  String _selectedDirectChannel = 'PROMPTPAY';
  Restaurant? _restaurant;

  bool _isPlacingOrder = false;
  bool _isVerifyingOrderEligibility = false;
  UserLocationModel? _primaryLocation;
  bool _isLoadingLocation = true;
  List<ShopPaymentTypeDto>? _paymentTypes;
  String? _trueMoneyApiIconUrl =
      'https://late-shape-f160.mytogetherteam.workers.dev/payment-methods/1781846864991-images.jpg';

  // Shop coupon catalog (browse). Cart-specific ฿-off / free-item amounts come
  // from POST /user/coupons/preview — the app must not invent them locally.
  List<CouponModel> _shopCoupons = const [];
  List<CouponModel> _previewCoupons = const [];
  String? _previewCartSignature;
  CouponModel? _selectedCoupon;
  bool _forcedAddressFlowOpen = false;
  double _draftDistanceKm = 0.0;
  double _draftDeliveryFee = 0.0;
  double? _exactQuotedFee;
  bool _isFetchingQuotation = false;
  /// Fallback until GET /delivery-range returns. 30 km and farther is blocked.
  bool _deliveryLimitEnabled = false;
  double _maxDeliveryKm = 30;
  double _farWarningKm = GeoDistance.distanceConfirmThresholdKm;
  /// Grab-style free delivery — set from cache ASAP, then confirmed by shop API.
  bool _freeDeliveryActive = false;
  bool _isAppBarScrolled = false;

  @override
  void initState() {
    super.initState();
    _loadPrimaryLocation();
    _loadDeliveryRange();
    _loadTrueMoneyIconFromApi();
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
    NewUserFreeDeliveryOffer.instance.addListener(_onNewUserOfferChanged);
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

        // 2. Shop details — cache first so FREE shows immediately (Grab-style),
        //    then refresh from API.
        _loadShopForCheckout(restaurantId);
        NewUserFreeDeliveryOffer.instance.refresh();

        // 3. Fetch the authoritative payment methods for this shop from the
        //    dedicated endpoint: GET /api/user/shops/:shopId/payment-methods.
        _loadShopPaymentMethods(restaurantId);

        // 4. Pre-load this shop's coupons so the "Apply Coupon" row can show
        //    immediately on this page.
        _loadShopCoupons(restaurantId);
      }
    }
  }

  Future<void> _loadShopForCheckout(int restaurantId) async {
    // Cache first — FREE must show before the network round-trip (Grab-style).
    final cached = await ShopStorage.getShop(restaurantId);
    if (cached != null && mounted) {
      final cachedFree = cached['freeDeliveryActive'] == true ||
          DeliveryFeeEstimate.isFreeLabel(
            cached['displayDeliveryFee']?.toString(),
          );
      if (cachedFree) {
        setState(() => _freeDeliveryActive = true);
      }
    }

    try {
      final shop =
          await RestaurantRepository.instance.getShopById(restaurantId);
      if (!mounted) return;
      setState(() {
        _restaurant = shop;
        // Replace the cached flag. A newer shop response must be able to turn Free off.
        _freeDeliveryActive = shop.shopPromoFreeDelivery;
      });
      _preFetchRoute();
      _fetchDeliveryQuotation();
    } catch (_) {
      // A saved Free flag is not safe once the shop response failed.
      if (!mounted) return;
      setState(() => _freeDeliveryActive = false);
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedCoupon == null) {
          _openCouponSheet(currentStore.items);
        }
      });
    }
  }

  List<CouponCartLine> _couponCartLines(List<CartItem> items) => items
      .map(
        (i) => (
          menuItemId: i.menuItemId,
          quantity: i.quantity,
          price: i.price,
        ),
      )
      .toList();

  int? get _shopIdForCoupons {
    final fromRestaurant = int.tryParse(_restaurant?.id ?? '');
    if (fromRestaurant != null) return fromRestaurant;
    return int.tryParse(widget.store.items.first.restaurantId);
  }

  /// Coupons that qualify for the current cart — amounts come from the server
  /// (`POST /user/coupons/preview`), not local Buy 1 Get 1 / discount math.
  Future<List<CouponModel>> _loadPreviewCoupons(List<CartItem> items) async {
    final shopId = _shopIdForCoupons;
    if (shopId == null || items.isEmpty) return const [];
    return CouponService.instance.previewForCart(
      shopId: shopId,
      items: _couponCartLines(items),
    );
  }

  String _cartPreviewSignature(List<CartItem> items) => items
      .map((i) => '${i.menuItemId}:${i.quantity}:${i.price}')
      .join('|');

  /// Refreshes server preview when cart lines change.
  Future<void> _refreshCouponPreview(List<CartItem> items) async {
    final coupons = await _loadPreviewCoupons(items);
    if (!mounted) return;
    setState(() {
      _previewCoupons = coupons;
      _previewCartSignature = _cartPreviewSignature(items);
      final selectedId = _selectedCoupon?.id;
      if (selectedId != null) {
        CouponModel? updated;
        for (final c in coupons) {
          if (c.id == selectedId) {
            updated = c;
            break;
          }
        }
        _selectedCoupon = updated;
      }
    });
  }

  void _maybeRefreshCouponPreview(List<CartItem> items) {
    final sig = _cartPreviewSignature(items);
    if (sig == _previewCartSignature) return;
    _refreshCouponPreview(items);
  }

  double _discountForSelected() => _selectedCoupon?.discountPreview ?? 0;

  bool _selectedCouponApplies() {
    final c = _selectedCoupon;
    if (c == null) return false;
    if (c.isFreeItem) {
      return c.previewFreeItems.isNotEmpty || c.isBogoAllItems;
    }
    return c.discountPreview > 0;
  }

  Future<void> _openCouponSheet(List<CartItem> items) async {
    final applicable = await _loadPreviewCoupons(items);
    if (!mounted) return;
    setState(() => _previewCoupons = applicable);
    if (applicable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('coupon.none'),
            style: AppFonts.poppins(),
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

  bool _usableDeliveryCoord(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    if (lat == 0 || lon == 0) return false;
    return lat.abs() <= 90 && lon.abs() <= 180;
  }

  /// Straight-line kilometers. This is the same ruler as the admin limits.
  double? get _straightLineDeliveryKm {
    if (!_isDelivery) return null;
    final userLat = _primaryLocation?.latitude;
    final userLon = _primaryLocation?.longitude;
    final shopLat = _restaurant?.latitude;
    final shopLon = _restaurant?.longitude;
    if (!_usableDeliveryCoord(userLat, userLon) ||
        !_usableDeliveryCoord(shopLat, shopLon)) {
      return null;
    }
    return GeoDistance.haversineKm(userLat!, userLon!, shopLat!, shopLon!);
  }

  bool get _isOutOfDeliveryRange {
    if (!_deliveryLimitEnabled) return false;
    final km = _straightLineDeliveryKm;
    return km != null && km >= _maxDeliveryKm;
  }

  String _formatKm(double km) {
    final rounded = (km * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
    return rounded.toStringAsFixed(1);
  }

  String _formatEstimatedDuration(double km) {
    if (km <= 0) return '20-30 min';
    final minMins = ((15 + km * 2.0) / 5).round() * 5;
    final maxMins = minMins + 10;
    final unitMin = context.trArgs('time.duration_m', {'m': ''}).trim();
    if (maxMins < 60) {
      return '$minMins-$maxMins $unitMin';
    }
    final minDuration = LocaleController.instance.countdown(Duration(minutes: minMins));
    final maxDuration = LocaleController.instance.countdown(Duration(minutes: maxMins));
    return '$minDuration - $maxDuration';
  }

  Future<void> _loadDeliveryRange() async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/delivery-range',
      );
      final body = response.data;
      final data = body is Map && body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : (body is Map ? Map<String, dynamic>.from(body) : null);
      final maxKm = (data?['maxDeliveryKm'] as num?)?.toDouble();
      final warnKm = (data?['farWarningKm'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        _deliveryLimitEnabled = data?['enabled'] == true;
        if (maxKm != null && maxKm > 0) _maxDeliveryKm = maxKm;
        if (warnKm != null && warnKm > 0 && warnKm < _maxDeliveryKm) {
          _farWarningKm = warnKm;
        }
      });
    } catch (_) {
      // Blocking stays off when the setting cannot be loaded.
    }
  }

  /// Warns when delivery is farther than the admin warning distance.
  /// The customer can continue until the maximum range.
  Future<bool> _confirmFarDeliveryIfNeeded() async {
    if (!_isDelivery) return true;
    if (_isOutOfDeliveryRange) return false;
    final km = _straightLineDeliveryKm;
    if (km == null || km <= _farWarningKm) return true;

    if (!mounted) return false;
    final distanceStr = km.toStringAsFixed(1);
    final durationStr = _formatEstimatedDuration(km);
    final result = await GlobalModal.show<bool>(
      context: context,
      child: _FarDeliveryModal(
        distanceStr: distanceStr,
        limitStr: _formatKm(_farWarningKm),
        durationStr: durationStr,
      ),
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

  Future<void> _loadTrueMoneyIconFromApi() async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/payment-methods',
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data is Map
            ? response.data['data'] as List<dynamic>? ?? <dynamic>[]
            : response.data as List<dynamic>? ?? <dynamic>[];
        for (final item in list) {
          if (item is Map) {
            final name = item['name']?.toString().toLowerCase() ?? '';
            final icon = item['iconUrl']?.toString();
            if (name.contains('true') && icon != null && icon.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _trueMoneyApiIconUrl = icon;
                });
              }
              break;
            }
          }
        }
      }
    } catch (_) {}
  }



  /// Stores the payment list and keeps the current selection valid, defaulting
  /// to the first active method when nothing valid is selected yet.
  void _applyPaymentTypes(List<ShopPaymentTypeDto> methods) {
    _paymentTypes = methods;
    final tmMethod = methods.where((t) =>
      (t.paymentMethodName?.toLowerCase().contains('true') ?? false) ||
      t.paymentMethodCode.contains('TRUE')
    ).firstOrNull;
    if (tmMethod?.iconUrl != null && tmMethod!.iconUrl!.isNotEmpty) {
      _trueMoneyApiIconUrl = tmMethod.iconUrl;
    }

    final active = methods.where((t) => t.isActive).toList();
    final isVerifiedShop = _restaurant?.isVerified ?? widget.store.isVerified;
    if (isVerifiedShop) {
      if (_selectedDirectChannel == 'COD') {
        final cod = active.where((t) => t.isCashOnDelivery).firstOrNull;
        if (cod != null) {
          _selectedPaymentMethodId = cod.paymentMethodId;
          return;
        }
      }
      final online = active.where((t) => !t.isCashOnDelivery).firstOrNull;
      if (online != null) {
        _selectedPaymentMethodId = online.paymentMethodId;
        return;
      }
    }
    final nonCodActive = active.where((t) => !t.isCashOnDelivery).toList();
    final stillValid =
        nonCodActive.any((t) => t.paymentMethodId == _selectedPaymentMethodId);
    if (!stillValid) {
      _selectedPaymentMethodId = nonCodActive.isNotEmpty
          ? nonCodActive.first.paymentMethodId
          : (active.isNotEmpty ? active.first.paymentMethodId : null);
    }
  }

  void _onNewUserOfferChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    UserLocationRepository.instance.removeListener(_onLocationRepositoryChanged);
    NewUserFreeDeliveryOffer.instance.removeListener(_onNewUserOfferChanged);
    super.dispose();
  }

  void _onLocationRepositoryChanged() {
    _loadPrimaryLocation(forceRefresh: true);
  }

  /// Returns true when a delivery location with coordinates and address is selected.
  /// Allows ordering with current location (id: -1) or a picked location without
  /// requiring it to be pre-saved to the user's 3-address profile (id > 0).
  bool _hasValidDeliveryAddress() {
    final loc = _primaryLocation;
    if (loc == null) return false;
    final hasCoords = loc.latitude != null &&
        loc.longitude != null &&
        loc.latitude != 0 &&
        loc.longitude != 0;
    final hasAddress = (loc.streetAddress?.trim().isNotEmpty ?? false);
    return hasCoords && hasAddress;
  }

  Future<void> _ensureDeliveryAddressIfNeeded() async {
    if (!_isDelivery || GuestAuthGuard.isGuest || !mounted) return;
    if (_hasValidDeliveryAddress()) return;
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

  Future<bool> _ensureValidDeliveryAddressForOrder() async {
    if (!_isDelivery) return true;
    if (_hasValidDeliveryAddress()) {
      await DeliveryAddressPrefs.setCompletedSetup(true);
      return true;
    }
    if (await DeliveryAddressPrefs.requiresForcedSetup()) {
      await _openForcedAddressSetup();
    }
    if (!mounted) return false;
    return _hasValidDeliveryAddress();
  }

  Future<void> _loadPrimaryLocation({bool forceRefresh = false}) async {
    try {
      var loc = UserLocationRepository.instance.activeLocation;
      loc ??= await UserLocationRepository.instance
          .getPrimaryLocation(forceRefresh: forceRefresh);

      // If user has no saved locations, fall back to current device GPS location
      if (loc == null) {
        await UserLocationRepository.instance
            .ensureSessionCurrentLocationFromDevice(
          requestPermissionIfDenied: false,
        );
        loc = UserLocationRepository.instance.activeLocation;
      }

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
        } else {
          final resolved = await LocationSearchService.instance.reverseGeocode(
            loc.latitude!,
            loc.longitude!,
          );
          if (resolved?.displayName.trim().isNotEmpty ?? false) {
            loc = loc.copyWith(address: resolved!.displayName.trim());
          }
        }
      }

      if (mounted) {
        setState(() {
          _primaryLocation = loc;
          _isLoadingLocation = false;
          _exactQuotedFee = null;
        });
        _preFetchRoute(); // Start pre-fetching route
        _fetchDeliveryQuotation();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _fetchDeliveryQuotation() async {
    final isVerified = _restaurant?.isVerified ?? widget.store.isVerified;
    if (!isVerified || !_isDelivery) return;
    final loc = _primaryLocation;
    if (loc == null || loc.latitude == null || loc.longitude == null) return;
    if (loc.latitude == 0 && loc.longitude == 0) return;

    final rawShopId = _restaurant?.id ??
        (widget.store.items.isNotEmpty
            ? widget.store.items.first.restaurantId
            : null);
    final shopId = int.tryParse(rawShopId?.toString() ?? '');
    if (shopId == null || shopId <= 0) return;

    if (_isFetchingQuotation) return;
    _isFetchingQuotation = true;

    try {
      final response = await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/user/orders/delivery-quotation',
        data: {
          'shopId': shopId,
          'lat': loc.latitude,
          'lon': loc.longitude,
          if (_primaryLocationAddressText() != null)
            'address': _primaryLocationAddressText(),
        },
      );
      final body = response.data;
      final data = body is Map && body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : (body is Map ? Map<String, dynamic>.from(body) : null);
      final fee = (data?['deliveryFee'] as num?)?.toDouble() ??
          (data?['originalFee'] as num?)?.toDouble();
      if (fee != null && fee >= 0 && mounted) {
        setState(() {
          _exactQuotedFee = fee;
          _draftDeliveryFee = fee;
          if (data?['distanceKm'] != null) {
            _draftDistanceKm = (data!['distanceKm'] as num).toDouble();
          }
          if (data?['isFreeDelivery'] == true) {
            _freeDeliveryActive = true;
          }
        });
      }
    } catch (_) {
      // Silently fall back to OSRM estimated fee
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingQuotation = false;
        });
      } else {
        _isFetchingQuotation = false;
      }
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
        final double distanceM = (route['distance'] as num).toDouble();
        final km = distanceM / 1000;

        final baseFee = DeliveryFeeEstimate.minFee(km);
        if (mounted) {
          setState(() {
            _draftDistanceKm = km;
            _draftDeliveryFee = baseFee;
          });
        }
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

    final baseFee = DeliveryFeeEstimate.minFee(km);
    if (mounted) {
      setState(() {
        _draftDistanceKm = km;
        _draftDeliveryFee = baseFee;
      });
    }
  }

  bool get _newUserFreeForLoadedShop {
    if (!_isDelivery || !NewUserFreeDeliveryOffer.instance.applies) return false;
    final shop = _restaurant;
    if (shop == null) return false;
    return !shop.freeDeliveryOptOutOfGlobal;
  }

  bool get _isWaitingForDeliveryFee {
    if (!_isDelivery) return false;
    if (_isFreeDelivery) return false;
    final isVerified = _restaurant?.isVerified ?? widget.store.isVerified;
    if (isVerified) {
      return _exactQuotedFee == null;
    }
    return _draftDeliveryFee == 0.0;
  }

  bool get _isFreeDelivery {
    if (_newUserFreeForLoadedShop) return true;
    final shop = _restaurant;
    if (shop != null) return shop.shopPromoFreeDelivery;
    return _freeDeliveryActive;
  }

  Widget _newUserFreeDeliveryNote() {
    if (!_newUserFreeForLoadedShop) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        context.tr('delivery.first_order_free'),
        style: AppFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF067647),
        ),
      ),
    );
  }

  String _getEstimatedDeliveryFeeText() {
    if (_isFreeDelivery) return 'FREE';
    final isVerified = _restaurant?.isVerified ?? widget.store.isVerified;
    if (isVerified && _exactQuotedFee != null) {
      return '฿ ${_exactQuotedFee!.toStringAsFixed(0)}';
    }
    final km = _draftDistanceKm;
    if (km == 0.0) {
      return _isFetchingQuotation ? '...' : '฿ 0.00';
    }
    return DeliveryFeeEstimate.rangeLabel(km);
  }

  String _getTotalWithDeliveryRange(double payableTotal) {
    // Grab-style: FREE promo → pay food + tax only (no fee range).
    if (_isFreeDelivery) {
      return payableTotal.toFormattedPrice();
    }
    final isVerified = _restaurant?.isVerified ?? widget.store.isVerified;
    if (isVerified && _exactQuotedFee != null) {
      final total = payableTotal + _exactQuotedFee!;
      return '฿ ${total.toStringAsFixed(0)}';
    }
    if (_draftDistanceKm == 0.0) {
      return payableTotal.toFormattedPrice();
    }
    final double baseFee = DeliveryFeeEstimate.minFee(_draftDistanceKm);
    final double maxFee = DeliveryFeeEstimate.maxFee(_draftDistanceKm);

    final lo = baseFee < maxFee ? baseFee : maxFee;
    final hi = baseFee > maxFee ? baseFee : maxFee;

    final minTotal = payableTotal + lo;
    final maxTotal = payableTotal + (lo == hi ? lo + 15 : hi);

    return '฿ ${minTotal.toStringAsFixed(0)} - ฿ ${maxTotal.toStringAsFixed(0)}';
  }

  Widget _buildAddressText() {
    final loc = _primaryLocation;
    final address = loc?.streetAddress;
    final subtitle = loc?.detailSubtitle;

    if (loc == null || address == null || address.isEmpty) {
      return Text(
        context.tr('cart.no_address'),
        style: AppFonts.poppins(
          fontSize: 14,
          color: Colors.black87,
          height: 1.5,
        ),
      );
    }

    String? cleanSubtitle = subtitle?.trim();
    if (cleanSubtitle != null) {
      final normSub = cleanSubtitle.toLowerCase();
      final normAddr = address.trim().toLowerCase();
      if (normSub == normAddr || normAddr.contains(normSub)) {
        cleanSubtitle = null;
      } else if (normSub.startsWith(normAddr)) {
        final remainder = cleanSubtitle
            .substring(address.trim().length)
            .replaceAll(RegExp(r'^[·\s,\-]+'), '')
            .trim();
        cleanSubtitle = remainder.isNotEmpty ? remainder : null;
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 75),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              address,
              style: AppFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            if (cleanSubtitle != null && cleanSubtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                cleanSubtitle,
                style: AppFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
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

  Future<String?> _promptForPhoneBottomSheet() async {
    return await GlobalModal.show<String>(
      context: context,
      barrierDismissible: true,
      child: const _CodPhonePromptModal(),
    );
  }

  bool _isProcessing = false;
  bool _hasShownEmptyToast = false;
  /// Set after a successful place-order navigation so the empty-cart auto-pop
  /// does not pop [OrderTrackingPage] off the stack in the same frame.
  bool _navigatedAfterPlaceOrder = false;

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
        content: Text(message, style: AppFonts.poppins()),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _onPlaceOrderPressed() async {
    if (_isProcessing || _isPlacingOrder) return;

    if (GuestAuthGuard.isGuest) {
      await GuestAuthGuard.requireAccount(context);
      return;
    }

    if (_isOutOfDeliveryRange) return;

    if (_isShopClosed || _orderAvailability?.isBlocked == true) {
      if (mounted) {
        final blockMsg = _orderAvailability?.statusStripText(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (blockMsg != null && blockMsg.isNotEmpty)
                  ? blockMsg
                  : context.tr('cart.closed_now'),
              style: AppFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _isPlacingOrder = true;
    });

    try {
      if (_isDelivery) {
        final hasAddress = await _ensureValidDeliveryAddressForOrder();
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

      if (_selectedDirectChannel == 'COD') {
        final rawPhone = AuthService().currentUser?.phone?.trim() ?? '';
        final hasRealPhone = rawPhone.length >= 6 && !rawPhone.startsWith('g_');
        if (!hasRealPhone) {
          final savedPhone = await _promptForPhoneBottomSheet();
          if (savedPhone == null || savedPhone.length < 6) {
            return;
          }
        }

        final foodSubtotal = CartManager.instance.getStoreTotal(widget.store.nameKey).toDouble();
        final tax = (_restaurant?.taxEnable ?? true) ? (foodSubtotal * 0.07) : 0.0;
        final delivery = (_isDelivery && !_isFreeDelivery)
            ? (_exactQuotedFee ?? _draftDeliveryFee)
            : 0.0;
        final couponDiscount = _discountForSelected();
        final estGrandTotal = (foodSubtotal + tax + delivery - couponDiscount).clamp(0, double.infinity);

        if (estGrandTotal < 100) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr('payment.cod_min_limit'),
                  style: AppFonts.poppins(),
                ),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
          return;
        }
        if (estGrandTotal > 1500) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr('payment.cod_max_limit'),
                  style: AppFonts.poppins(),
                ),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
          return;
        }
      }

      // Lock checkout only after preflight passes — beginOrderPlacement() sets
      // [_orderPlacementInFlight], which must not run before ensureCanPlaceNewOrder().
      ActiveOrderState.instance.beginOrderPlacement();

      if (!mounted) return;
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
          if (_isDelivery && (_exactQuotedFee != null || _draftDeliveryFee > 0))
            "deliveryFee": _exactQuotedFee ?? _draftDeliveryFee,
          "paymentMethodId": _resolvePaymentMethodId(
            _paymentTypes,
            _selectedPaymentMethodId,
          ),
          if (_selectedDirectChannel == 'COD')
            "paymentChannel": "COD",
          "items": storeItems
              .map(
                (item) => {
                  "menuItemId": item.menuItemId,
                  "quantity": item.quantity,
                  if (item.variantId != null && item.variantId! > 0)
                    "variantId": item.variantId,
                  if (item.additionalVariantIds.isNotEmpty)
                    "additionalVariantIds": item.additionalVariantIds,
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

      final isVerified = _restaurant?.isVerified ?? widget.store.isVerified;
      final serverPaymentChannel = responseData?['paymentChannel']?.toString() ??
          responseData?['payment_channel']?.toString();
      final effectivePaymentChannel = serverPaymentChannel ??
          (_selectedDirectChannel == 'COD' ? 'COD' : (isVerified ? 'OMISE' : null));
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
        isFreeDelivery: _isDelivery && _isFreeDelivery,
        isVerified: isVerified,
        paymentChannel: effectivePaymentChannel,
        preferredOmiseMethod: isVerified ? _selectedDirectChannel : null,
      );
      if (_isDelivery) {
        NewUserFreeDeliveryOffer.instance.refresh();
      }
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
      final selectedMethod = _resolveSelectedPaymentMethod(
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
      final effectiveDeliveryFee = _isDelivery
          ? (_isFreeDelivery
              ? 0.0
              : (_exactQuotedFee ??
                  (responseData?['deliveryFee'] as num?)?.toDouble() ??
                  _draftDeliveryFee))
          : 0.0;

      ActiveOrderState.instance.setOrderDetails(
        totalAmount: backendTotalAmount,
        itemPrice: backendItemPrice,
        taxAmount: backendTaxAmount,
        displayTaxAmount: backendDisplayTax,
        deliveryFee: effectiveDeliveryFee,
        taxEnable: orderTaxEnable,
        paymentMethod: isVerified
            ? (_selectedDirectChannel == 'TRUEMONEY'
                ? context.tr('payment.truemoney_title')
                : _selectedDirectChannel == 'COD'
                    ? context.tr('payment.cod_title')
                    : context.tr('payment.promptpay_title'))
            : (_selectedPaymentType?.displayName ?? (mounted ? context.tr('cart.payment') : 'Payment')),
        paymentMethodId: selectedMethodId,
        paymentMethodImageUrl: selectedMethodImage,
        paymentChannel: effectivePaymentChannel,
        items: List.from(storeItems),
        orderId: orderId,
      );
      if (selectedMethod != null) {
        ActiveOrderState.instance.updatePaymentMethodDetails(
          accountNumber: selectedMethod.accountNumber,
          accountName: selectedMethod.accountName,
          orderId: orderId,
        );
      }

      if (responseData != null && orderId != null) {
        ActiveOrderState.instance.updateFromSocket({
          ...responseData,
          'orderId': orderId,
        });
      }

      WebSocketService().connect();

      // Clear purchased items from cart immediately
      await CartManager.instance.removeStore(widget.store.nameKey);

      // Apply coupon if selected so order total reflects discount
      await _applySelectedCoupon(
        orderId,
        foodTotal.toDouble(),
        storeItems,
      );

      // Unlock placement lock before navigating away
      ActiveOrderState.instance.endOrderPlacement();


      if (!context.mounted) return;
      _navigatedAfterPlaceOrder = true;
      await nav.pushReplacement(
        MaterialPageRoute(
          builder: (context) => OrderTrackingPage(
            store: widget.store,
            restaurant: _restaurant,
            foodTotal: backendItemPrice.round(),
            deliveryFee: effectiveDeliveryFee,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        final errorMsg = userFacingError(
          e,
          fallback: LocaleController.instance.tr('cart.unknown_error'),
        );
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
      if (mounted && !_navigatedAfterPlaceOrder) {
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
            !_isProcessing &&
            !_isPlacingOrder &&
            !_navigatedAfterPlaceOrder) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && !_hasShownEmptyToast) {
              _hasShownEmptyToast = true;
              App.scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                    context.tr('cart.empty_now'),
                    style: AppFonts.poppins(),
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
        final couponDiscount = _discountForSelected();
        final payableTotal =
            (checkoutTotal - couponDiscount).clamp(0, double.infinity).toDouble();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeRefreshCouponPreview(currentStore.items);
        });

        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F7),
          extendBodyBehindAppBar: _isDelivery && _isFreeDelivery,
          appBar: AppBar(
            systemOverlayStyle: (_isDelivery && _isFreeDelivery && !_isAppBarScrolled)
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            backgroundColor: (_isDelivery && _isFreeDelivery)
                ? (_isAppBarScrolled ? Colors.white : Colors.transparent)
                : Colors.white,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            bottom: (_isDelivery && _isFreeDelivery && !_isAppBarScrolled)
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.05),
                      height: 1,
                    ),
                  ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: (_isDelivery && _isFreeDelivery && !_isAppBarScrolled)
                    ? Colors.white
                    : Colors.black,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: false,
            titleSpacing: 0,
            title: (_isDelivery && _isFreeDelivery && !_isAppBarScrolled)
                ? null
                : Text(
                    context.tr('cart.order_summary'),
                    style: AppFonts.poppins(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          body: Column(
            children: [
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis == Axis.vertical) {
                      final scrolled = notification.metrics.pixels > 80;
                      if (scrolled != _isAppBarScrolled) {
                        setState(() => _isAppBarScrolled = scrolled);
                      }
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
         // Free Delivery Banner — Visa-style hero
                      if (_isDelivery && _isFreeDelivery)
                        Builder(builder: (ctx) {
                          final top = MediaQuery.of(ctx).padding.top;
                          final isIOS = Theme.of(ctx).platform == TargetPlatform.iOS;
                          final bannerHeight = (isIOS ? 155.0 : 145.0) + top;
                          return SizedBox(
                            width: double.infinity,
                            height: bannerHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Background image
                                Image.asset(
                                  'assets/images/free_delivery_banner.webp',
                                  width: double.infinity,
                                  height: bannerHeight,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                ),
                                // Top dark scrim for AppBar readability
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: const [0.0, 0.5, 1.0],
                                      colors: [
                                        Colors.black.withValues(alpha: 0.28),
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // Bottom fade-to-background
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: 60,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        stops: const [0.0, 0.55, 1.0],
                                        colors: [
                                          Colors.white.withValues(alpha: 0.0),
                                          const Color(0xFFF7F7F7).withValues(alpha: 0.78),
                                          const Color(0xFFF7F7F7),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Order Summary title on bottom-left with text shadow (positioned above overlay card)
                                Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: 46,
                                  child: Text(
                                    context.tr('cart.order_summary'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 19.5,
                                      fontWeight: FontWeight.w800,
                                    ).copyWith(
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(0, 2),
                                          blurRadius: 8,
                                          color: Colors.black.withValues(alpha: 0.55),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      // Padded content section with card overlay on banner
                      Transform.translate(
                        offset: Offset(0, (_isDelivery && _isFreeDelivery) ? -32.0 : 0.0),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            (_isDelivery && _isFreeDelivery) ? 0 : 16,
                            16,
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                                  style: AppFonts.poppins(
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
                                        final isVerified = _restaurant?.isVerified ?? widget.store.isVerified;
                                        if (isVerified && _exactQuotedFee == null) {
                                          _fetchDeliveryQuotation();
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 50,
                                        alignment: Alignment.center,
                                        child: Text(
                                          context.tr('cart.delivery'),
                                          style: AppFonts.poppins(
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
                                      onTap: () => setState(() {
                                        _isDelivery = false;
                                        if (_selectedDirectChannel == 'COD') {
                                          _selectedDirectChannel = 'PROMPTPAY';
                                          final online = _paymentTypes
                                              ?.where((t) =>
                                                  t.isActive &&
                                                  !t.isCashOnDelivery)
                                              .firstOrNull;
                                          if (online != null) {
                                            _selectedPaymentMethodId =
                                                online.paymentMethodId;
                                          }
                                        }
                                      }),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 50,
                                        alignment: Alignment.center,
                                        child: Text(
                                          context.tr('cart.pickup'),
                                          style: AppFonts.poppins(
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
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: _showLocationModal,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          context.tr('cart.edit_location'),
                                          style: AppFonts.poppins(
                                            color: AppColors.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),


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
                      const SizedBox(height: 12),
                      // Store Header inside a Card-like container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
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
                                    child: Row(
                                      children: [
                                        _buildStoreLogo(
                                          currentStore.items.first.restaurantId,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: VerifiedRestaurantNameRow(
                                            name: currentStore.name,
                                            isVerified: _restaurant?.isVerified ?? currentStore.isVerified,
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
                                    style: AppFonts.poppins(
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
                      const SizedBox(height: 12),
                      // Apply Coupon entry (opens the movie-ticket sheet).
                      _buildCouponSection(foodSubtotal, currentStore.items),
                      // Payment Option Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('cart.payment_options'),
                              style: AppFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),

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

                                final isVerifiedShop =
                                    _restaurant?.isVerified ??
                                    widget.store.isVerified;

                                if (isVerifiedShop) {
                                  return _buildVerifiedShopPaymentSection(allPaymentTypes);
                                }

                                final paymentTypes = allPaymentTypes
                                    .where((t) => !t.isCashOnDelivery)
                                    .toList();

                                if (paymentTypes.isEmpty) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      context.tr('cart.no_payment_methods'),
                                      style: AppFonts.poppins(
                                        color: const Color(0xFF64748B),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (int i = 0; i < paymentTypes.length; i++) ...[
                                      if (i > 0) const SizedBox(height: 12),
                                      _buildNonVerifiedPaymentTile(paymentTypes[i]),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child:                       Padding(
                        padding: EdgeInsets.zero,
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
                            if (couponDiscount > 0 ||
                                (_selectedCoupon?.isFreeItem == true &&
                                    _selectedCouponApplies())) ...[
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedCoupon?.name.isNotEmpty ==
                                                  true
                                              ? _selectedCoupon!.name
                                              : context.tr(
                                                  'order_status.discount',
                                                ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppFonts.poppins(
                                            color: AppColors.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (_selectedCoupon?.isFreeItem ==
                                            true) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            couponBogoGiftSummary(
                                              context,
                                              _selectedCoupon!,
                                            ),
                                            style: AppFonts.poppins(
                                              color: const Color(0xFF94A3B8),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    couponDiscount > 0
                                        ? '- ${couponDiscount.toFormattedPrice()}'
                                        : context.tr('coupon.free'),
                                    style: AppFonts.poppins(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_isDelivery) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        PhosphorIconsRegular.motorcycle,
                                        size: 16,
                                        color: _isFreeDelivery
                                            ? AppColors.primary
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        context.tr('cart.est_delivery_fee'),
                                        style: AppFonts.poppins(
                                          color: _isFreeDelivery
                                              ? AppColors.primary
                                              : const Color(0xFF64748B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  _isFreeDelivery
                                      ? Text(
                                          'FREE',
                                          style: AppFonts.poppins(
                                            color: AppColors.primary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        )
                                      : (_isWaitingForDeliveryFee
                                          ? AnimatedDotsText(
                                              baseText: '฿ ',
                                              style: AppFonts.poppins(
                                                color: const Color(0xFF64748B),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            )
                                          : Text(
                                              _draftDeliveryFee > 0
                                                  ? _getEstimatedDeliveryFeeText()
                                                  : '—',
                                              style: AppFonts.poppins(
                                                color: const Color(0xFF64748B),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            )),
                                ],
                              ),
                              _newUserFreeDeliveryNote(),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _isDelivery
                                      ? context.tr('cart.total_pay_now')
                                      : context.tr('cart.total'),
                                  style: AppFonts.poppins(
                                    color: const Color(0xFF1E293B),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                _isWaitingForDeliveryFee
                                    ? AnimatedDotsText(
                                        baseText: '฿ ',
                                        style: AppFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : GradientText(
                                        _isDelivery ? _getTotalWithDeliveryRange(payableTotal) : payableTotal.toFormattedPrice(),
                                        style: AppFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
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
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
                ),
              ),

              // Bottom Checkout Bar
              Container(
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      const SizedBox(height: 16),
                      if (hasOngoingOrder && !_isPlacingOrder) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  PhosphorIconsRegular.info,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr('cart.ongoing_order_wait'),
                                    style: AppFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (isShopClosed && orderAvailability != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: RestaurantOrderStatusStrip(
                            message: orderAvailability.statusStripText(context),
                            reason: OrderBlockReason.closed,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (_isOutOfDeliveryRange) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  PhosphorIconsFill.warning,
                                  color: Color(0xFFB91C1C),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.trArgs(
                                      'order.out_of_delivery_range',
                                      {
                                        'distance': _formatKm(
                                          _straightLineDeliveryKm!,
                                        ),
                                        'limit': _formatKm(_maxDeliveryKm),
                                        'duration': _formatEstimatedDuration(
                                          _straightLineDeliveryKm!,
                                        ),
                                      },
                                    ),
                                    style: AppFonts.poppins(
                                      color: const Color(0xFFB91C1C),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Notice to check before order and delivery fee estimate
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                PhosphorIconsFill.info,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isDelivery
                                      ? (_isFreeDelivery
                                          ? '${context.tr('cart.check_order_notice')} ${context.tr('cart.free_delivery_applied')}'
                                          : '${context.tr('cart.check_order_notice')} ${context.tr('cart.delivery_fee_estimate_notice')}')
                                      : context.tr('cart.check_order_notice'),
                                  style: AppFonts.poppins(
                                    color: const Color(0xFF334155),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('cart.total'),
                                    style: AppFonts.poppins(
                                      color: const Color(0xFF64748B),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  _isWaitingForDeliveryFee
                                      ? AnimatedDotsText(
                                          baseText: '฿ ',
                                          style: AppFonts.poppins(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : GradientText(
                                          _isDelivery ? _getTotalWithDeliveryRange(payableTotal) : payableTotal.toFormattedPrice(),
                                          style: AppFonts.poppins(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: PrimaryGradientButton(
                                onPressed: (_isPlacingOrder ||
                                        _isProcessing ||
                                        _isVerifyingOrderEligibility ||
                                        _isWaitingForDeliveryFee ||
                                        hasOngoingOrder ||
                                        isShopClosed ||
                                        _isOutOfDeliveryRange)
                                    ? null
                                    : _onPlaceOrderPressed,
                                isLoading: _isPlacingOrder,
                                child: Text(
                                  isShopClosed
                                      ? context.tr('cart.closed_now')
                                      : context.tr('cart.place_order'),
                                  style: AppFonts.poppins(
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

    // Skip if server preview says the coupon no longer applies to this cart.
    if (!_selectedCouponApplies()) return;

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
          content: Text(message, style: AppFonts.poppins()),
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
      return gift.isNotEmpty ? '${coupon.name}  •  $gift' : coupon.name;
    }
    return '${coupon.name}  •  - ${discount.toFormattedPrice()}';
  }

  /// The "Apply Coupon" card shown on the summary page. Hidden when the shop has
  /// no coupons that apply to the current cart (and none is selected).
  Widget _buildCouponSection(double subtotal, List<CartItem> items) {
    final applicable = _previewCoupons;
    final discount = _discountForSelected();
    final hasSelection = _selectedCoupon != null;
    final hasCoupons = _shopCoupons.isNotEmpty;
    final isHighlighted = hasSelection || hasCoupons;

    if (!hasSelection && applicable.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isHighlighted 
              ? AppColors.primary.withValues(alpha: 0.04) 
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isHighlighted)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
          border: isHighlighted
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1.5,
                )
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openCouponSheet(items),
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
                        style: AppFonts.poppins(
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
                        style: AppFonts.poppins(
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
                    onTap: () => _openCouponSheet(items),
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
    final isVerified = _restaurant?.isVerified ?? widget.store.isVerified;
    if (isVerified) {
      if (_selectedDirectChannel == 'COD') {
        final cod = active.where((t) => t.isCashOnDelivery).firstOrNull;
        if (cod != null) return cod.paymentMethodId;
      } else {
        final online = active.where((t) => !t.isCashOnDelivery).firstOrNull;
        if (online != null) return online.paymentMethodId;
      }
    }
    final nonCodActive = active.where((t) => !t.isCashOnDelivery).toList();
    final match = nonCodActive
        .where((t) => t.paymentMethodId == selectedId)
        .firstOrNull;
    if (match != null) return match.paymentMethodId;
    if (nonCodActive.isNotEmpty) return nonCodActive.first.paymentMethodId;
    if (active.isNotEmpty) return active.first.paymentMethodId;
    return selectedId ?? 1;
  }

  String? _resolvePaymentMethodImageUrl(
    List<ShopPaymentTypeDto>? paymentTypes,
    int? selectedId,
  ) {
    final match = _resolveSelectedPaymentMethod(paymentTypes, selectedId);
    if (match == null) return null;
    return _normalizeImageUrl(match.qrImageUrl);
  }

  ShopPaymentTypeDto? _resolveSelectedPaymentMethod(
    List<ShopPaymentTypeDto>? paymentTypes,
    int? selectedId,
  ) {
    if (paymentTypes == null || paymentTypes.isEmpty) return null;
    final active = paymentTypes.where((t) => t.isActive).toList();
    return active.where((t) => t.paymentMethodId == selectedId).firstOrNull ??
        (active.isNotEmpty ? active.first : null);
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

  Widget _buildNonVerifiedPaymentTile(ShopPaymentTypeDto type) {
    final isPromptPay = (type.paymentMethodName?.toLowerCase().contains('prompt') ?? false) ||
        type.paymentMethodCode.contains('PROMPT') ||
        (!type.isCashOnDelivery && !(type.paymentMethodName?.toLowerCase().contains('true') ?? false));
    final isTrueMoney = (type.paymentMethodName?.toLowerCase().contains('true') ?? false) ||
        type.paymentMethodCode.contains('TRUE');

    final String title;
    final String subtitle;
    final String badgeText;
    final Color badgeColor;

    if (isPromptPay) {
      title = context.tr('payment.promptpay_title');
      subtitle = context.tr('payment.promptpay_subtitle');
      badgeText = context.tr('payment.promptpay_badge');
      badgeColor = const Color(0xFF003D6B);
    } else if (isTrueMoney) {
      title = context.tr('payment.truemoney_title');
      subtitle = context.tr('payment.truemoney_subtitle');
      badgeText = context.tr('payment.truemoney_badge');
      badgeColor = const Color(0xFFFF8200);
    } else {
      title = type.displayName;
      subtitle = type.isCashOnDelivery
          ? context.tr('payment.cod_subtitle')
          : (type.qrImageUrl != null && type.qrImageUrl!.isNotEmpty
              ? 'Thai QR Code'
              : 'Direct payment');
      badgeText = type.paymentMethodCode.isNotEmpty ? type.paymentMethodCode : 'DIRECT';
      badgeColor = const Color(0xFF64748B);
    }

    final isSelected = _selectedPaymentMethodId == type.paymentMethodId;
    final iconUrl = _normalizeImageUrl(type.iconUrl);

    final iconWidget = Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: iconUrl != null
          ? CachedNetworkImage(
              memCacheWidth: 108,
              imageUrl: iconUrl,
              fit: BoxFit.contain,
              errorWidget: (_, url, error) => Icon(
                isPromptPay
                    ? PhosphorIconsFill.qrCode
                    : PhosphorIconsRegular.creditCard,
                color: isPromptPay ? const Color(0xFF003D6B) : const Color(0xFF64748B),
                size: 22,
              ),
            )
          : Icon(
              isPromptPay
                  ? PhosphorIconsFill.qrCode
                  : PhosphorIconsRegular.creditCard,
              color: isPromptPay ? const Color(0xFF003D6B) : const Color(0xFF64748B),
              size: 22,
            ),
    );

    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethodId = type.paymentMethodId),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : Colors.white,
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.all(isSelected ? 1.8 : 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isSelected ? 12.2 : 14),
          ),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: AppFonts.poppins(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected ? AppColors.primaryGradient : null,
                  border: isSelected
                      ? null
                      : Border.all(
                          color: const Color(0xFF94A3B8),
                          width: 1.5,
                        ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 17.6,
                          height: 17.6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Center(
                            child: Container(
                              width: 10.5,
                              height: 10.5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.primaryGradient,
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // VERIFIED SHOP PAYMENT OPTIONS (GRAB & FOODPANDA STANDARD)
  // ─────────────────────────────────────────────────────────────
  Widget _buildVerifiedShopPaymentSection(List<ShopPaymentTypeDto> paymentTypes) {
    final hasCod = _isDelivery;

    final promptPayType = paymentTypes.where((t) =>
      (t.paymentMethodName?.toLowerCase().contains('prompt') ?? false) ||
      t.paymentMethodCode.contains('PROMPT') ||
      (!t.isCashOnDelivery && !(t.paymentMethodName?.toLowerCase().contains('true') ?? false))
    ).firstOrNull;
    final promptPayIconUrl = promptPayType != null ? _normalizeImageUrl(promptPayType.iconUrl) : null;

    final trueMoneyType = paymentTypes.where((t) =>
      (t.paymentMethodName?.toLowerCase().contains('true') ?? false) ||
      t.paymentMethodCode.contains('TRUE')
    ).firstOrNull;
    final trueMoneyIconUrl = _normalizeImageUrl(trueMoneyType?.iconUrl ?? _trueMoneyApiIconUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. PromptPay Thai QR
        _buildDirectMethodTile(
          channelKey: 'PROMPTPAY',
          title: context.tr('payment.promptpay_title'),
          subtitle: context.tr('payment.promptpay_subtitle'),
          badgeText: context.tr('payment.promptpay_badge'),
          badgeColor: const Color(0xFF003D6B),
          iconWidget: Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: promptPayIconUrl != null
                ? CachedNetworkImage(
                    memCacheWidth: 108,
                    imageUrl: promptPayIconUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, url, error) => const Icon(
                      PhosphorIconsFill.qrCode,
                      color: Color(0xFF003D6B),
                      size: 22,
                    ),
                  )
                : const Icon(
                    PhosphorIconsFill.qrCode,
                    color: Color(0xFF003D6B),
                    size: 22,
                  ),
          ),
          paymentTypes: paymentTypes,
        ),
        const SizedBox(height: 12),

        // 2. TrueMoney Wallet (Moved to 2nd place, clean white icon without black corners)
        _buildDirectMethodTile(
          channelKey: 'TRUEMONEY',
          title: context.tr('payment.truemoney_title'),
          subtitle: context.tr('payment.truemoney_subtitle'),
          badgeText: context.tr('payment.truemoney_badge'),
          badgeColor: const Color(0xFFFF8200),
          iconWidget: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: trueMoneyIconUrl != null
                  ? Transform.scale(
                      scale: 1.15,
                      child: CachedNetworkImage(
                        memCacheWidth: 108,
                        imageUrl: trueMoneyIconUrl,
                        fit: BoxFit.contain,
                        errorWidget: (_, url, error) => const Icon(
                          PhosphorIconsFill.wallet,
                          color: Color(0xFFFF8200),
                          size: 22,
                        ),
                      ),
                    )
                  : const Icon(
                      PhosphorIconsFill.wallet,
                      color: Color(0xFFFF8200),
                      size: 22,
                    ),
            ),
          ),
          paymentTypes: paymentTypes,
        ),


        // 4. Cash on Delivery (if enabled for pickup or allowed delivery)
        if (hasCod) ...[
          const SizedBox(height: 12),
          _buildDirectMethodTile(
            channelKey: 'COD',
            title: context.tr('payment.cod_title'),
            subtitle: context.tr('payment.cod_subtitle'),
            badgeText: context.tr('payment.cod_badge'),
            badgeGradient: AppColors.primaryGradient,
            iconWidget: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: const Icon(
                    PhosphorIconsFill.money,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            bottomNotice: _selectedDirectChannel == 'COD'
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1.5),
                          child: ShaderMask(
                            shaderCallback: (bounds) =>
                                AppColors.primaryGradient.createShader(bounds),
                            blendMode: BlendMode.srcIn,
                            child: const Icon(
                              PhosphorIconsFill.info,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            context.tr('payment.cod_rule_notice'),
                            style: AppFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            paymentTypes: paymentTypes,
          ),
        ],
      ],
    );
  }

  Widget _buildDirectMethodTile({
    required String channelKey,
    required String title,
    required String subtitle,
    required String badgeText,
    Color? badgeColor,
    Gradient? badgeGradient,
    Widget? bottomNotice,
    required Widget iconWidget,
    required List<ShopPaymentTypeDto> paymentTypes,
  }) {
    final isSelected = _selectedDirectChannel == channelKey;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDirectChannel = channelKey;
          if (channelKey == 'COD') {
            final cod = paymentTypes.where((t) => t.isCashOnDelivery).firstOrNull;
            if (cod != null) {
              _selectedPaymentMethodId = cod.paymentMethodId;
            }
          } else {
            final online = paymentTypes.where((t) => !t.isCashOnDelivery).firstOrNull;
            if (online != null) {
              _selectedPaymentMethodId = online.paymentMethodId;
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : Colors.white,
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.all(isSelected ? 1.8 : 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isSelected ? 12.2 : 14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: AppFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeGradient == null ? badgeColor : null,
                                gradient: badgeGradient,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: AppFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: AppFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected ? AppColors.primaryGradient : null,
                      border: isSelected
                          ? null
                          : Border.all(
                              color: const Color(0xFF94A3B8),
                              width: 1.5,
                            ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 17.6,
                              height: 17.6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: Center(
                                child: Container(
                                  width: 10.5,
                                  height: 10.5,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppColors.primaryGradient,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              if (bottomNotice != null) ...[
                const SizedBox(height: 10),
                bottomNotice,
              ],
            ],
          ),
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
                      style: AppFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('cart.pickup_note_body'),
                      style: AppFonts.poppins(
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
                      style: AppFonts.poppins(
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
                              style: AppFonts.poppins(
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
                      style: AppFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                    GradientText(
                      fee.toFormattedPrice(),
                      style: AppFonts.poppins(
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
                      style: AppFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                    GradientText(
                      time,
                      style: AppFonts.poppins(
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
            : CachedNetworkImage(memCacheWidth: 144, 
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
          style: AppFonts.poppins(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: AppFonts.poppins(
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
              child: CachedNetworkImage(memCacheWidth: 210, 
                imageUrl: item.imagePath,
                fit: BoxFit.cover,
                width: 70,
                height: 70,
                placeholder: (context, url) => const MenuImagePlaceholder(),
                errorWidget: (context, url, error) => const MenuImagePlaceholder(),
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
                          style: AppFonts.poppins(
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
                    style: AppFonts.poppins(
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
                    style: AppFonts.poppins(
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
                              style: AppFonts.poppins(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'x${item.quantity}',
                              style: AppFonts.poppins(
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
                                    initialAdditionalVariantIds:
                                        item.additionalVariantIds.isEmpty
                                            ? null
                                            : item.additionalVariantIds,
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
                                style: AppFonts.poppins(
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
                          style: AppFonts.poppins(
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
                                  style: AppFonts.poppins(
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

class _CodPhonePromptModal extends StatefulWidget {
  const _CodPhonePromptModal();

  @override
  State<_CodPhonePromptModal> createState() => _CodPhonePromptModalState();
}

class _CodPhonePromptModalState extends State<_CodPhonePromptModal> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _showOtpView = false;
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;
  int _resendCountdown = 60;
  Timer? _resendTimer;
  String? _errorMessage;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatPhoneStr() {
    var cleanPhone = _phoneController.text.trim().replaceAll(' ', '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    return '+66$cleanPhone';
  }

  Future<void> _handleSendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phoneStr = _formatPhoneStr();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneStr,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _onVerificationSuccess(phoneStr, credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          final msg = FirebaseErrorHandler.getMessage(context, e);
          setState(() {
            _isLoading = false;
            _errorMessage = msg;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
            _resendToken = resendToken;
            _showOtpView = true;
          });
          _startResendTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final smsCode = _otpController.text.trim();
    if (_verificationId == null || smsCode.length < 6) {
      setState(() {
          _errorMessage = context.tr('payment.cod_otp_full');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      final phoneStr = _formatPhoneStr();
      await _onVerificationSuccess(phoneStr, credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = FirebaseErrorHandler.getMessage(context, e);
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  Future<void> _onVerificationSuccess(
    String phoneStr,
    PhoneAuthCredential credential,
  ) async {
    try {
      final currentFirebaseUser = FirebaseAuth.instance.currentUser;
      if (currentFirebaseUser != null) {
        try {
          await currentFirebaseUser.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code != 'provider-already-linked' &&
              e.code != 'credential-already-in-use') {
            await FirebaseAuth.instance.signInWithCredential(credential);
          }
        }
      } else {
        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      await AuthRepository.instance.updateProfile(phone: phoneStr);
      if (mounted) {
        Navigator.of(context).pop(phoneStr);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showOtpView) {
      return _buildOtpView();
    }
    return _buildPhoneView();
  }

  Widget _buildPhoneView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('payment.cod_verify_phone'),
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('payment.cod_otp_desc'),
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            autofocus: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: AppFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
              letterSpacing: 1.1,
            ),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phone_android_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+66',
                      style: AppFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
                  ],
                ),
              ),
              hintText: context.tr('payment.cod_phone_hint'),
              hintStyle: AppFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              final val = value?.trim() ?? '';
              if (val.isEmpty) {
                return context.tr('payment.cod_phone_empty');
              }
              var clean = val.replaceAll(' ', '');
              if (clean.startsWith('0')) clean = clean.substring(1);
              if (!RegExp(r'^[689]\d{8}$').hasMatch(clean)) {
                return context.tr('payment.cod_invalid_phone');
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 12,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryGradientButton(
            onPressed: _isLoading ? null : _handleSendOtp,
            isLoading: _isLoading,
            height: 52,
            borderRadius: BorderRadius.circular(14),
            child: Text(
              context.tr('payment.cod_send_otp'),
              style: AppFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context, null),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.tr('payment.cod_cancel'),
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpView() {
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 52,
      textStyle: AppFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1E293B),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primary, width: 1.8),
      ),
    );

    final phoneFormatted = _formatPhoneStr();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('payment.cod_otp_enter'),
          textAlign: TextAlign.center,
          style: AppFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.trArgs('payment.cod_otp_sent', {'phone': phoneFormatted}),
          textAlign: TextAlign.center,
          style: AppFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Pinput(
            length: 6,
            controller: _otpController,
            autofocus: true,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            keyboardType: TextInputType.number,
            showCursor: true,
            onCompleted: (_) {
              if (!_isLoading) {
                _handleVerifyOtp();
              }
            },
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFEF4444),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_resendCountdown > 0)
              Text(
                context.trArgs('payment.cod_resend_countdown', {'seconds': '$_resendCountdown'}),
                style: AppFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _handleSendOtp,
                child: Text(
                  context.tr('payment.cod_resend_otp'),
                  style: AppFonts.poppins(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: AppFonts.poppins(color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      _resendTimer?.cancel();
                      setState(() {
                        _showOtpView = false;
                        _errorMessage = null;
                        _otpController.clear();
                      });
                    },
              child: Text(
                context.tr('payment.cod_change_phone'),
                style: AppFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryGradientButton(
          onPressed: _isLoading ? null : _handleVerifyOtp,
          isLoading: _isLoading,
          height: 52,
          borderRadius: BorderRadius.circular(14),
          child: Text(
            context.tr('payment.cod_confirm_order'),
            style: AppFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context, null),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              context.tr('payment.cod_cancel'),
              style: AppFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FarDeliveryModal extends StatelessWidget {
  final String distanceStr;
  final String limitStr;
  final String durationStr;

  const _FarDeliveryModal({
    required this.distanceStr,
    required this.limitStr,
    required this.durationStr,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/far_delivery_baby.png',
          height: 140,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 140,
              width: 140,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.image, color: Colors.grey, size: 40),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('order.far_delivery_title'),
          textAlign: TextAlign.center,
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.trArgs('order.far_delivery_message', {
            'distance': distanceStr,
            'limit': limitStr,
            'duration': durationStr,
          }),
          textAlign: TextAlign.center,
          style: AppFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF475569),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        PrimaryGradientButton(
          onPressed: () => Navigator.pop(context, true),
          height: 54,
          borderRadius: BorderRadius.circular(16),
          child: Text(
            context.tr('order.far_delivery_continue'),
            style: AppFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              context.tr('common.cancel'),
              style: AppFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


