import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_manager.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'dart:convert';
import '../../../core/localization/locale_controller.dart';
import '../../../core/utils/file_url_util.dart';
import '../../../core/utils/image_utils.dart';
import '../../order/data/repositories/order_repository.dart';
import '../presentation/utils/revise_reason_parser.dart';
import '../../../core/utils/order_tax.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/order_ownership.dart';

/// Normalizes `deliveryAddress` from API/WebSocket payloads. The backend
/// returns a nested object (`address`, `addressMm`, `buildingName`, …) while
/// older payloads may still be a plain string.
String? parseDeliveryAddressValue(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    for (final key in ['address', 'addressMm', 'addressTh']) {
      final candidate = map[key]?.toString().trim();
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    final building = map['buildingName']?.toString().trim();
    final floor = map['floor']?.toString().trim();
    if (building != null && building.isNotEmpty) {
      if (floor != null && floor.isNotEmpty) return '$building, $floor';
      return building;
    }
    final note = map['note']?.toString().trim();
    if (note != null && note.isNotEmpty) return note;
  }
  final fallback = value.toString().trim();
  return fallback.isEmpty ? null : fallback;
}

class ActiveOrderItem {
  final String orderId;
  String? storeName;
  String? restaurantName;
  String? logoPath;
  String? estimatedTime;
  String? restaurantId;
  String? statusLabel;
  String? statusLabelMm;
  String? statusLabelTh;
  int orderStatus; // 0: Awaiting Confirmation, etc.
  double? itemPrice;
  double? taxAmount;
  double? totalAmount;
  String? paymentMethod;
  String? cancelReason;
  // Set when the shop sends the order back for revision (status REVISED).
  bool isRevised;
  String? reviseReason;
  List<String> unavailableItemNames;
  String? unavailableItemReason;
  List<CartItem> orderItems;
  bool showUploadSection;
  bool isPaymentChecking;

  // Refined shop details from WS
  String? shopId;
  String? shopName;
  String? shopNameEn;
  String? shopNameMm;
  String? shopNameTh;
  String? shopLogo;
  String? shopImageUrl;
  String? shopPhone;

  // Tracking data
  List<LatLng> routePoints;
  double? routeDistanceKm;
  int? routeDurationMins;
  double? deliveryFee;
  String? riderName;
  String? riderPhone;
  String? deliveryTrackingUrl;
  String? shopPaymentQrUrl;
  int? paymentMethodId;
  String? paymentMethodImageUrl;
  bool? taxEnable;
  // Photo the shop attaches when marking the order Delivered — shown to the
  // customer as proof the food was successfully delivered.
  String? proofPhotoUrl;

  // Missing fields for backward compatibility
  String? deliveryAddress;
  String? restaurantAddress;
  String? userLocationName;
  LatLng? restaurantLatLng;
  LatLng? userLocation;
  String? displayFoodPrice;
  String? displayTaxAmount;
  String? displayDeliveryFee;
  String? displayTotalAmount;
  double? idleSolidProgress;
  bool hasNotifiedSlipRequest;
  bool isSlipRequested;
  String? deliveryType;
  String? orderDeliveryType;
  String? orderType;
  String? backendStatus;
  String? lastOrderNo;
  String? riderVehicleNumber;

  bool get isPickupFulfillment {
    final type = (orderType ?? '').toUpperCase();
    return type == 'PICK_UP' || type == 'PICKUP';
  }

  bool get isReadyForPickup =>
      (backendStatus ?? '').toUpperCase() == 'READY_FOR_PICKUP';

  /// Flexible delivery: food (+ tax) is paid in-app; delivery fee is estimated
  /// and paid to the rider on arrival. FAST delivery includes fee in-app total.
  bool get isFlexibleDelivery {
    if (isPickupFulfillment) return false;
    final type = (orderDeliveryType ?? '').toUpperCase();
    if (type == 'FAST' || type == 'PREPAID') return false;
    if (type == 'FLEXIBLE' || type == 'NORMAL') return true;
    // Tier is chosen by the shop on confirm; until then treat as flexible.
    return type.isEmpty;
  }

  bool get resolvedTaxEnable => taxEnable ?? true;

  /// Food subtotal before tax and delivery — prefers backend `itemPrice`.
  double get resolvedItemSubtotal {
    if (itemPrice != null && itemPrice! > 0) return itemPrice!;
    if (orderItems.isNotEmpty) {
      return orderItems.fold<double>(0, (sum, item) => sum + item.total);
    }
    final total = totalAmount ?? 0;
    final delivery = deliveryFee ?? 0;
    final tax =
        taxAmount ??
        OrderTax.resolveTaxAmount(
          (total - delivery).clamp(0, double.infinity),
          resolvedTaxEnable,
        );
    final fromTotal = total - delivery - tax;
    if (fromTotal > 0) return fromTotal;
    return (total - delivery).clamp(0, double.infinity).toDouble();
  }

  double get resolvedTaxAmount {
    if (taxAmount != null) return taxAmount!;
    return OrderTax.resolveTaxAmount(resolvedItemSubtotal, resolvedTaxEnable);
  }

  double resolvedGrandTotal({double fallbackDeliveryFee = 0}) {
    if (totalAmount != null && totalAmount! > 0) return totalAmount!;
    final delivery = isPickupFulfillment
        ? 0.0
        : (deliveryFee ?? fallbackDeliveryFee);
    return OrderTax.calculateTotal(
      itemSubtotal: resolvedItemSubtotal,
      deliveryFee: delivery,
      taxEnable: resolvedTaxEnable,
    );
  }

  /// Amount the customer pays in-app. Flexible delivery excludes delivery fee.
  double resolvedPayNowTotal({double fallbackDeliveryFee = 0}) {
    if (isPickupFulfillment || !isFlexibleDelivery) {
      return resolvedGrandTotal(fallbackDeliveryFee: fallbackDeliveryFee);
    }
    return resolvedItemSubtotal + resolvedTaxAmount;
  }

  bool get hasDeliveryFeeEstimate {
    final fee = deliveryFee;
    return fee != null && fee > 0;
  }

  bool get hasPrepTimeEstimate {
    final time = estimatedTime?.trim();
    if (time == null || time.isEmpty) return false;
    final normalized = time.toLowerCase();
    return normalized != '0' &&
        normalized != '0 mins' &&
        normalized != '0 min';
  }

  ActiveOrderItem({
    required this.orderId,
    this.storeName,
    this.restaurantName,
    this.logoPath,
    this.estimatedTime,
    this.restaurantId,
    this.statusLabel,
    this.statusLabelMm,
    this.statusLabelTh,
    this.orderStatus = 0,
    this.itemPrice,
    this.taxAmount,
    this.totalAmount,
    this.paymentMethod,
    this.cancelReason,
    this.isRevised = false,
    this.reviseReason,
    this.unavailableItemNames = const [],
    this.unavailableItemReason,
    this.orderItems = const [],
    this.showUploadSection = false,
    this.isPaymentChecking = false,
    this.routePoints = const [],
    this.routeDistanceKm,
    this.routeDurationMins,
    this.deliveryFee,
    this.riderName,
    this.riderPhone,
    this.deliveryTrackingUrl,
    this.shopPaymentQrUrl,
    this.deliveryAddress,
    this.restaurantAddress,
    this.userLocationName,
    this.restaurantLatLng,
    this.userLocation,
    this.displayFoodPrice,
    this.displayTaxAmount,
    this.displayDeliveryFee,
    this.displayTotalAmount,
    this.idleSolidProgress,
    this.hasNotifiedSlipRequest = false,
    this.isSlipRequested = false,
    this.deliveryType,
    this.orderDeliveryType,
    this.orderType,
    this.backendStatus,
    this.lastOrderNo,
    this.riderVehicleNumber,
    this.shopId,
    this.shopName,
    this.shopNameEn,
    this.shopNameMm,
    this.shopNameTh,
    this.shopLogo,
    this.shopImageUrl,
    this.shopPhone,
    this.paymentMethodId,
    this.paymentMethodImageUrl,
    this.taxEnable,
    this.proofPhotoUrl,
  });

  String get displayShopName {
    final value = LocaleController.instance.localized(
      en: shopNameEn ?? shopName ?? storeName ?? restaurantName,
      mm: shopNameMm,
      th: shopNameTh,
    );
    return value.isEmpty
        ? (storeName ?? restaurantName ?? shopName ?? '')
        : value;
  }

  /// Unavailable item names + shop reason, preferring structured `reviseItems`
  /// from the API and falling back to the combined `reviseReason` string.
  ({List<String> items, String reason}) get resolvedReviseInfo =>
      ReviseReasonParser.resolve(
        reviseReason: reviseReason,
        structuredItemNames: unavailableItemNames.isNotEmpty
            ? unavailableItemNames
            : null,
        structuredItemReason: unavailableItemReason,
      );

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'storeName': storeName,
    'restaurantName': restaurantName,
    'logoPath': logoPath,
    'estimatedTime': estimatedTime,
    'restaurantId': restaurantId,
    'statusLabel': statusLabel,
    'statusLabelMm': statusLabelMm,
    'statusLabelTh': statusLabelTh,
    'orderStatus': orderStatus,
    'itemPrice': itemPrice,
    'taxAmount': taxAmount,
    'totalAmount': totalAmount,
    'paymentMethod': paymentMethod,
    'cancelReason': cancelReason,
    'isRevised': isRevised,
    'reviseReason': reviseReason,
    'unavailableItemNames': unavailableItemNames,
    'unavailableItemReason': unavailableItemReason,
    'showUploadSection': showUploadSection,
    'isPaymentChecking': isPaymentChecking,
    'routeDistanceKm': routeDistanceKm,
    'routeDurationMins': routeDurationMins,
    'deliveryFee': deliveryFee,
    'riderName': riderName,
    'riderPhone': riderPhone,
    'deliveryTrackingUrl': deliveryTrackingUrl,
    'shopPaymentQrUrl': shopPaymentQrUrl,
    'deliveryAddress': deliveryAddress,
    'restaurantAddress': restaurantAddress,
    'userLocationName': userLocationName,
    'restaurantLat': restaurantLatLng?.latitude,
    'restaurantLng': restaurantLatLng?.longitude,
    'userLat': userLocation?.latitude,
    'userLng': userLocation?.longitude,
    'displayFoodPrice': displayFoodPrice,
    'displayTaxAmount': displayTaxAmount,
    'displayDeliveryFee': displayDeliveryFee,
    'displayTotalAmount': displayTotalAmount,
    'idleSolidProgress': idleSolidProgress,
    'shopId': shopId,
    'shopName': shopName,
    'shopNameEn': shopNameEn,
    'shopNameMm': shopNameMm,
    'shopNameTh': shopNameTh,
    'shopLogo': shopLogo,
    'shopImageUrl': shopImageUrl,
    'shopPhone': shopPhone,
    'paymentMethodId': paymentMethodId,
    'paymentMethodImageUrl': paymentMethodImageUrl,
    'taxEnable': taxEnable,
    'proofPhotoUrl': proofPhotoUrl,
    'deliveryType': deliveryType,
    'orderDeliveryType': orderDeliveryType,
    'orderType': orderType,
    'backendStatus': backendStatus,
    'lastOrderNo': lastOrderNo,
  };

  factory ActiveOrderItem.fromJson(Map<String, dynamic> json) =>
      ActiveOrderItem(
        orderId: json['orderId'],
        storeName: json['storeName'],
        restaurantName: json['restaurantName'],
        logoPath: json['logoPath'],
        estimatedTime: json['estimatedTime'],
        restaurantId: json['restaurantId'],
        statusLabel: json['statusLabel'],
        statusLabelMm: json['statusLabelMm'],
        statusLabelTh: json['statusLabelTh'],
        orderStatus: json['orderStatus'] ?? 0,
        itemPrice: json['itemPrice'],
        taxAmount: json['taxAmount'],
        totalAmount: json['totalAmount'],
        paymentMethod: json['paymentMethod'],
        cancelReason: json['cancelReason'],
        isRevised: json['isRevised'] ?? false,
        reviseReason: json['reviseReason'],
        unavailableItemNames:
            (json['unavailableItemNames'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        unavailableItemReason: json['unavailableItemReason']?.toString(),
        showUploadSection: json['showUploadSection'] ?? false,
        isPaymentChecking: json['isPaymentChecking'] ?? false,
        routeDistanceKm: json['routeDistanceKm'],
        routeDurationMins: json['routeDurationMins'],
        deliveryFee: json['deliveryFee'],
        riderName: json['riderName'],
        riderPhone: json['riderPhone'],
        deliveryTrackingUrl: json['deliveryTrackingUrl'] ?? json['trackingUrl'],
        shopPaymentQrUrl: json['shopPaymentQrUrl'],
        deliveryAddress: parseDeliveryAddressValue(json['deliveryAddress']),
        restaurantAddress: json['restaurantAddress'],
        userLocationName: json['userLocationName'],
        restaurantLatLng:
            (json['restaurantLat'] != null && json['restaurantLng'] != null)
            ? LatLng(json['restaurantLat'], json['restaurantLng'])
            : null,
        userLocation: (json['userLat'] != null && json['userLng'] != null)
            ? LatLng(json['userLat'], json['userLng'])
            : null,
        displayFoodPrice: json['displayFoodPrice'],
        displayTaxAmount: json['displayTaxAmount'],
        displayDeliveryFee: json['displayDeliveryFee'],
        displayTotalAmount: json['displayTotalAmount'],
        idleSolidProgress: json['idleSolidProgress'],
        shopId: json['shopId'],
        shopName: json['shopName'],
        shopNameEn: json['shopNameEn'],
        shopNameMm: json['shopNameMm'],
        shopNameTh: json['shopNameTh'],
        shopLogo: json['shopLogo'],
        shopImageUrl: json['shopImageUrl'],
        shopPhone: json['shopPhone'],
        paymentMethodId: json['paymentMethodId'],
        paymentMethodImageUrl: json['paymentMethodImageUrl'],
        taxEnable: json['taxEnable'] as bool?,
        proofPhotoUrl: json['proofPhotoUrl'],
        deliveryType: json['deliveryType'] as String?,
        orderDeliveryType: json['orderDeliveryType'] as String?,
        orderType: json['orderType'],
        backendStatus: json['backendStatus'],
        lastOrderNo: json['lastOrderNo'],
      );
}

class ActiveOrderState extends ChangeNotifier {
  static final ActiveOrderState instance = ActiveOrderState._();
  ActiveOrderState._();

  int? _currentShopId;
  int? get currentShopId => _currentShopId;

  void setCurrentShopId(int? id) {
    if (_currentShopId != id) {
      _currentShopId = id;
      notifyListeners();
    }
  }

  final Map<String, ActiveOrderItem> _orders = {};

  /// The order the UI should treat as "current" (tracking, payment, complete).
  String? _primaryOrderId;
  final Set<String> _cancellingOrders = {};
  // Orders the user cancelled themselves. The backend emits the same CANCELED
  // WebSocket frame regardless of who cancelled, so we record user-initiated
  // cancellations here to keep the shop-cancellation page from popping up for
  // them (the user instead sees a dedicated apology page).
  final Set<String> _userCancelledOrderIds = {};

  /// True when [orderId] was cancelled by the user via [cancelActiveOrder]
  /// (as opposed to being cancelled by the restaurant).
  bool wasCancelledByUser(String? orderId) {
    if (orderId == null) return false;
    return _userCancelledOrderIds.contains(orderId.replaceAll('#', ''));
  }

  // Returns only non-terminal orders (not COMPLETED or CANCELLED)
  List<ActiveOrderItem> get activeOrdersList => _orders.values
      .where((o) => o.orderStatus != 4 && o.orderStatus != -1)
      .toList();

  // Returns everything currently tracked
  List<ActiveOrderItem> get allOrdersList => _orders.values.toList();

  ActiveOrderItem? get _primary {
    if (_primaryOrderId != null) {
      return _orders[_primaryOrderId];
    }
    final active = activeOrdersList;
    return active.isNotEmpty ? active.last : null;
  }

  void _purgeTerminalOrders() {
    _orders.removeWhere((_, o) => o.orderStatus == 4 || o.orderStatus == -1);
    if (_primaryOrderId != null && !_orders.containsKey(_primaryOrderId)) {
      _primaryOrderId = activeOrdersList.isNotEmpty
          ? activeOrdersList.last.orderId
          : null;
    }
  }

  void _reassignPrimaryOrderId() {
    if (_primaryOrderId != null && _orders.containsKey(_primaryOrderId)) {
      return;
    }
    final active = activeOrdersList;
    _primaryOrderId = active.isNotEmpty ? active.last.orderId : null;
  }

  // --- Properties & Backward Compatibility ---
  bool get hasActiveOrder => activeOrdersList.isNotEmpty;
  set hasActiveOrder(bool val) {
    /* Legacy compatibility setter */
  }

  /// Whether the user is allowed to start a brand-new checkout.
  bool get canPlaceNewOrder => !hasActiveOrder;

  // Helper to get a specific order (tolerates # prefix / numeric id mismatches).
  ActiveOrderItem? getOrder(String? id) {
    if (id != null) {
      final found = _findTrackedOrder(id);
      if (found != null) return found;
    }
    return _primary;
  }

  String? get orderId => _primaryOrderId ?? _primary?.orderId;
  set orderId(String? val) {
    if (val == null) return;
    if (!_orders.containsKey(val)) {
      _orders[val] = ActiveOrderItem(orderId: val);
      _primaryOrderId ??= val;
      notifyListeners();
    }
  }

  /// Clears in-memory orders when the signed-in user changes. Does not touch
  /// persisted prefs (those are keyed per user id).
  void resetForUserSession() {
    _orders.clear();
    _primaryOrderId = null;
    _userCancelledOrderIds.clear();
    notifyListeners();
  }

  static String _prefsKeyForUser(int? userId) {
    if (userId == null) return 'active_orders_v3_guest';
    return 'active_orders_v3_$userId';
  }

  static String _primaryPrefsKeyForUser(int? userId) {
    if (userId == null) return 'primary_order_id_guest';
    return 'primary_order_id_$userId';
  }

  void setShowUploadSection(bool val, {String? orderId}) {
    final id = orderId ?? this.orderId;
    if (id != null && _orders.containsKey(id)) {
      _orders[id]!.showUploadSection = val;
      saveToPrefs();
      notifyListeners();
    }
  }

  void setPaymentChecking(bool val, {String? orderId}) {
    final id = orderId ?? this.orderId;
    if (id != null && _orders.containsKey(id)) {
      _orders[id]!.isPaymentChecking = val;
      saveToPrefs();
      notifyListeners();
    }
  }

  void setNotifiedSlipRequest(bool val, {String? orderId}) {
    final id = orderId ?? this.orderId;
    if (id != null && _orders.containsKey(id)) {
      _orders[id]!.hasNotifiedSlipRequest = val;
      saveToPrefs();
      notifyListeners();
    }
  }

  String? get storeName => _primary?.storeName;
  String? get restaurantName => _primary?.restaurantName;
  String? get logoPath => _primary?.logoPath;
  String? get estimatedTime => _primary?.estimatedTime;
  String? get restaurantId => _primary?.restaurantId;
  String? get statusLabel => _primary?.statusLabel;
  String? get statusLabelMm => _primary?.statusLabelMm;
  int get orderStatus => _primary?.orderStatus ?? 0;
  bool get isPickupFulfillment => _primary?.isPickupFulfillment ?? false;
  bool get isFlexibleDelivery => _primary?.isFlexibleDelivery ?? false;
  bool get hasDeliveryFeeEstimate =>
      _primary?.hasDeliveryFeeEstimate ?? false;
  bool get hasPrepTimeEstimate => _primary?.hasPrepTimeEstimate ?? false;
  bool get isReadyForPickup => _primary?.isReadyForPickup ?? false;
  String? get backendStatus => _primary?.backendStatus;
  String? get orderType => _primary?.orderType;
  String? get lastOrderNo => _primary?.lastOrderNo;
  double? get itemPrice => _primary?.itemPrice;
  double? get taxAmount => _primary?.taxAmount;
  double? get totalAmount => _primary?.totalAmount;
  double get resolvedTaxAmount => _primary?.resolvedTaxAmount ?? 0;
  double resolvedGrandTotal({double fallbackDeliveryFee = 0}) =>
      _primary?.resolvedGrandTotal(fallbackDeliveryFee: fallbackDeliveryFee) ??
      0;
  double resolvedPayNowTotal({double fallbackDeliveryFee = 0}) =>
      _primary?.resolvedPayNowTotal(fallbackDeliveryFee: fallbackDeliveryFee) ??
      0;
  String? get paymentMethod => _primary?.paymentMethod;
  List<CartItem> get orderItems => _primary?.orderItems ?? [];
  bool get showUploadSection => _primary?.showUploadSection ?? false;
  bool get isPaymentChecking => _primary?.isPaymentChecking ?? false;
  bool get isSlipRequested => _primary?.isSlipRequested ?? false;
  bool get hasNotifiedSlipRequest => _primary?.hasNotifiedSlipRequest ?? false;
  double? get deliveryFee => _primary?.deliveryFee;
  List<LatLng> get routePoints => _primary?.routePoints ?? [];
  double? get routeDistanceKm => _primary?.routeDistanceKm;
  int? get routeDurationMins => _primary?.routeDurationMins;
  String? get riderName => _primary?.riderName;
  String? get riderPhone => _primary?.riderPhone;
  String? get deliveryTrackingUrl => _primary?.deliveryTrackingUrl;
  String? get shopPaymentQrUrl => _primary?.shopPaymentQrUrl;
  String? get proofPhotoUrl => _primary?.proofPhotoUrl;
  int? get paymentMethodId => _primary?.paymentMethodId;
  String? get paymentMethodImageUrl => _primary?.paymentMethodImageUrl;
  bool get taxEnable => _primary?.resolvedTaxEnable ?? true;
  String? get cancelReason => _primary?.cancelReason;
  set cancelReason(String? val) {
    if (_primary != null) _primary!.cancelReason = val;
  }

  // Refined shop details getters
  String? get shopId => _primary?.shopId;
  String? get shopName => _primary?.shopName;
  String? get shopNameEn => _primary?.shopNameEn;
  String? get shopNameMm => _primary?.shopNameMm;
  String? get shopNameTh => _primary?.shopNameTh;
  String get displayShopName => _primary?.displayShopName ?? '';
  String? get shopLogo => _primary?.shopLogo;
  String? get shopImageUrl => _primary?.shopImageUrl;
  String? get shopPhone => _primary?.shopPhone;

  // More restored getters/setters for legacy UI
  String? get deliveryAddress => _primary?.deliveryAddress;
  set deliveryAddress(String? val) {
    if (_primary != null) _primary!.deliveryAddress = val;
  }

  String? get restaurantAddress => _primary?.restaurantAddress;
  set restaurantAddress(String? val) {
    if (_primary != null) _primary!.restaurantAddress = val;
  }

  String? get userLocationName => _primary?.userLocationName;
  set userLocationName(String? val) {
    if (_primary != null) _primary!.userLocationName = val;
  }

  LatLng? get restaurantLatLng => _primary?.restaurantLatLng;
  set restaurantLatLng(LatLng? val) {
    if (_primary != null) _primary!.restaurantLatLng = val;
  }

  LatLng? get userLocation => _primary?.userLocation;
  set userLocation(LatLng? val) {
    if (_primary != null) _primary!.userLocation = val;
  }

  String? get displayFoodPrice => _primary?.displayFoodPrice;
  set displayFoodPrice(String? val) {
    if (_primary != null) _primary!.displayFoodPrice = val;
  }

  String? get displayTaxAmount => _primary?.displayTaxAmount;
  set displayTaxAmount(String? val) {
    if (_primary != null) _primary!.displayTaxAmount = val;
  }

  String? get displayDeliveryFee => _primary?.displayDeliveryFee;
  set displayDeliveryFee(String? val) {
    if (_primary != null) _primary!.displayDeliveryFee = val;
  }

  String? get displayTotalAmount => _primary?.displayTotalAmount;
  set displayTotalAmount(String? val) {
    if (_primary != null) _primary!.displayTotalAmount = val;
  }

  double? get idleSolidProgress => _primary?.idleSolidProgress;
  set idleSolidProgress(double? val) {
    if (_primary != null) _primary!.idleSolidProgress = val;
  }

  void setActiveOrder({
    required String storeName,
    required String restaurantName,
    String? logoPath,
    String? estimatedTime,
    String? orderId,
    String? restaurantId,
    String? deliveryAddress,
    String? restaurantAddress,
    String? userLocationName,
    LatLng? restaurantLatLng,
    LatLng? userLocation,
    String? orderType,
    String? lastOrderNo,
  }) {
    // Drop completed/cancelled orders so they cannot hijack the next checkout.
    _purgeTerminalOrders();

    final id =
        orderId ??
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final hasDifferentActiveOrder = activeOrdersList.any(
      (o) => o.orderId != id,
    );
    if (hasDifferentActiveOrder) return;

    _primaryOrderId = id;
    _orders[id] = ActiveOrderItem(
      orderId: id,
      storeName: storeName,
      restaurantName: restaurantName,
      logoPath: logoPath,
      estimatedTime: estimatedTime,
      restaurantId: restaurantId,
      deliveryAddress: deliveryAddress,
      restaurantAddress: restaurantAddress,
      userLocationName: userLocationName,
      restaurantLatLng: restaurantLatLng,
      userLocation: userLocation,
      orderType: orderType,
      lastOrderNo: lastOrderNo,
    );
    saveToPrefs();
    notifyListeners();
  }

  void setOrderDetails({
    required double totalAmount,
    required String paymentMethod,
    required List<CartItem> items,
    double? itemPrice,
    double? taxAmount,
    String? displayTaxAmount,
    bool? taxEnable,
    int? paymentMethodId,
    String? paymentMethodImageUrl,
    String? orderId,
  }) {
    final targetId = orderId ?? this.orderId;
    if (targetId == null || !_orders.containsKey(targetId)) return;

    final item = _orders[targetId]!;
    item.totalAmount = totalAmount;
    if (itemPrice != null) item.itemPrice = itemPrice;
    if (taxAmount != null) item.taxAmount = taxAmount;
    if (displayTaxAmount != null) item.displayTaxAmount = displayTaxAmount;
    if (taxEnable != null) item.taxEnable = taxEnable;
    item.paymentMethod = paymentMethod;
    item.paymentMethodId = paymentMethodId;
    item.paymentMethodImageUrl = paymentMethodImageUrl;
    item.orderItems = List.from(items);

    saveToPrefs();
    notifyListeners();
  }

  void setOrderStatus(int status, {String? orderId}) {
    final targetId = orderId ?? this.orderId;
    if (targetId == null || !_orders.containsKey(targetId)) return;

    final item = _orders[targetId]!;
    item.orderStatus = status;

    // NOTE: The WebSocket is a shared, app-wide channel — it also carries
    // global admin broadcasts/announcements that must pop "wherever the user
    // is". Its lifecycle is owned by app foreground/background (LifecycleObserver)
    // and auth, NOT by order state. Do not disconnect it here, or broadcasts
    // stop arriving once a user has no active order.

    saveToPrefs();
    notifyListeners();
  }

  Future<void> syncActiveOrder({String? orderId}) async {
    final targetId = orderId ?? _primaryOrderId ?? this.orderId;
    if (targetId == null) return;
    if (!_orders.containsKey(targetId)) return;

    try {
      final sanitizedOrderId = targetId.replaceAll('#', '');
      // Backend: GET /api/user/orders/:id (UserOrdersController.findAwaitingPaymentInfo).
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/orders/$sanitizedOrderId',
        options: Options(
          extra: {
            '@dio_cache_interceptor@': CacheOptions(
              store: MemCacheStore(),
              policy: CachePolicy.refresh,
            ),
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> data = response.data as Map<String, dynamic>;
        // Unwrap success/data envelope if present
        if (data.containsKey('data') && data['data'] is Map) {
          data = Map<String, dynamic>.from(data['data'] as Map);
        }
        if (OrderOwnership.isForeignOrder(data)) {
          clearOrder(orderId: targetId);
          return;
        }
        data['orderId'] = targetId;
        updateFromSocket(data);
        return;
      }
      clearOrder(orderId: targetId);
    } catch (_) {
      clearOrder(orderId: targetId);
    }
  }

  /// Verifies ownership via the REST API before tracking an order from a push.
  Future<void> adoptOrderIfOwned(String orderId) async {
    final sanitized = orderId.replaceAll('#', '').trim();
    if (sanitized.isEmpty) return;

    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/orders/$sanitized',
        options: Options(
          extra: {
            '@dio_cache_interceptor@': CacheOptions(
              store: MemCacheStore(),
              policy: CachePolicy.refresh,
            ),
          },
        ),
      );
      if (response.statusCode != 200 || response.data == null) return;

      Map<String, dynamic> data = response.data as Map<String, dynamic>;
      if (data.containsKey('data') && data['data'] is Map) {
        data = Map<String, dynamic>.from(data['data'] as Map);
      }
      if (OrderOwnership.isForeignOrder(data)) return;

      final id = data['id']?.toString() ?? sanitized;
      if (!_orders.containsKey(id)) {
        _orders[id] = ActiveOrderItem(orderId: id);
        _primaryOrderId ??= id;
      }
      data['orderId'] = id;
      updateFromSocket(data);
      saveToPrefs();
    } catch (_) {
      // Not owned by this account or unreachable — do not track.
    }
  }

  void updateFromSocket(Map<String, dynamic> data) {
    // Handle the server wrapper: { "type": "ORDER_UPDATE", "order": { ... } }
    if (data.containsKey('order') && data['order'] is Map) {
      data = data['order'] as Map<String, dynamic>;
    } else if (data.containsKey('data') && data['data'] is Map) {
      data = data['data'] as Map<String, dynamic>;
    }

    // Skip any non-order WebSocket messages
    final String? msgType = _parseSafeString(data['type']);
    if (msgType != null && msgType != 'ORDER_UPDATE') return;

    // Identify the tracked order (tolerate `#` prefixes and numeric ids).
    final rawId =
        data['orderId']?.toString() ?? data['id']?.toString() ?? orderId;

    if (OrderOwnership.isForeignOrder(data)) {
      if (rawId != null) clearOrder(orderId: rawId);
      return;
    }

    final ownerId = OrderOwnership.parseUserId(data);
    var item = _findTrackedOrder(rawId);
    if (item == null) {
      // Never adopt a brand-new order from realtime unless ownership is explicit.
      if (ownerId == null || !OrderOwnership.isOwnedByCurrentUser(data)) return;
      final id = rawId;
      if (id == null || id.isEmpty) return;
      _orders[id] = ActiveOrderItem(orderId: id);
      _primaryOrderId ??= id;
      item = _orders[id];
    }
    if (item == null) return;

    if (data['deliveryFee'] != null) {
      final fee = _parseSafeDouble(data['deliveryFee']);
      if (fee != null) item.deliveryFee = fee;
    }
    if (data['itemPrice'] != null)
      item.itemPrice = _parseSafeDouble(data['itemPrice']);
    if (data['taxAmount'] != null)
      item.taxAmount = _parseSafeDouble(data['taxAmount']);
    if (data['totalAmount'] != null)
      item.totalAmount = _parseSafeDouble(data['totalAmount']);
    if (data['taxEnable'] != null) {
      item.taxEnable = data['taxEnable'] == true;
    } else if (data['shop'] is Map &&
        (data['shop'] as Map)['taxEnable'] != null) {
      item.taxEnable = (data['shop'] as Map)['taxEnable'] == true;
    }
    if (data['deliveryRiderName'] != null)
      item.riderName = _parseSafeString(data['deliveryRiderName']);
    if (data['deliveryPhoneNo'] != null)
      item.riderPhone = _parseSafeString(data['deliveryPhoneNo']);

    // Shop contact number. The backend exposes it under a few shapes depending
    // on the endpoint (flat field or nested `shop` object), so try each.
    final shopMapForPhone = data['shop'];
    final parsedShopPhone = _parseSafeString(
      data['shopPhone'] ??
          data['shopPhoneNo'] ??
          (shopMapForPhone is Map ? shopMapForPhone['phone'] : null),
    );
    if (parsedShopPhone != null && parsedShopPhone.isNotEmpty) {
      item.shopPhone = parsedShopPhone;
    }
    if (data['deliveryCycleNo'] != null)
      item.riderVehicleNumber = _parseSafeString(data['deliveryCycleNo']);
    final waitMins = data['waitingTimeMinutes'] != null
        ? _parseSafeInt(data['waitingTimeMinutes'])
        : null;
    if (waitMins != null && waitMins > 0) {
      item.estimatedTime = '$waitMins mins';
    }

    var trackingUrl = _parseSafeString(
      data['deliveryTrackingUrl'] ?? data['trackingUrl'],
    );
    if (trackingUrl != null && trackingUrl.isNotEmpty) {
      if (!trackingUrl.startsWith('http://') &&
          !trackingUrl.startsWith('https://')) {
        trackingUrl = 'https://$trackingUrl';
      }
      if (_isValidUrl(trackingUrl)) {
        item.deliveryTrackingUrl = trackingUrl;
      }
    }

    final qrUrl = _parseSafeString(data['shopPaymentQrUrl']);
    if (qrUrl != null && _isValidUrl(qrUrl)) item.shopPaymentQrUrl = qrUrl;

    // Delivery proof photo attached by the shop on the "Delivered" step.
    final proofUrl = _parseSafeString(data['proofPhotoUrl']);
    if (proofUrl != null && proofUrl.isNotEmpty) {
      item.proofPhotoUrl = _getFullUrl(proofUrl);
    }

    final logoUrl = _parseSafeString(data['logoPath'] ?? data['shopLogo']);
    if (logoUrl != null && logoUrl.isNotEmpty)
      item.logoPath = _getFullUrl(logoUrl);

    final parsedShopNameEn = _parseSafeString(
      data['shopNameEn'] ??
          data['shopName'] ??
          (data['shop'] is Map
              ? (data['shop'] as Map)['nameEn'] ?? (data['shop'] as Map)['name']
              : null),
    );
    if (parsedShopNameEn != null &&
        parsedShopNameEn.isNotEmpty &&
        parsedShopNameEn != 'Shop') {
      item.shopNameEn = parsedShopNameEn;
      item.shopName = parsedShopNameEn;
      item.restaurantName = parsedShopNameEn;
      item.storeName = parsedShopNameEn;
    }

    if (data['orderDeliveryType'] != null) {
      item.orderDeliveryType = _parseSafeString(data['orderDeliveryType']);
    }
    if (data['deliveryType'] != null) {
      item.deliveryType = _parseSafeString(data['deliveryType']);
    }
    if (data['orderType'] != null) {
      item.orderType = _parseSafeString(data['orderType']);
    }
    if (data['lastOrderNo'] != null) {
      item.lastOrderNo = _parseSafeString(data['lastOrderNo']);
    }

    if (data['statusLabel'] != null)
      item.statusLabel = _parseSafeString(data['statusLabel']);
    if (data['statusLabelMm'] != null)
      item.statusLabelMm = _parseSafeString(data['statusLabelMm']);
    if (data['statusLabelTh'] != null)
      item.statusLabelTh = _parseSafeString(data['statusLabelTh']);

    if (data['paymentMethod'] != null) {
      if (data['paymentMethod'] is String) {
        item.paymentMethod = data['paymentMethod'] as String;
      } else if (data['paymentMethod'] is Map) {
        item.paymentMethod = _parseSafeString(
          data['paymentMethod']['name'] ?? data['paymentMethod']['code'],
        );
      }
    }

    if (data['displayFoodPrice'] != null)
      item.displayFoodPrice = _parseSafeString(data['displayFoodPrice']);
    if (data['displayTaxAmount'] != null)
      item.displayTaxAmount = _parseSafeString(data['displayTaxAmount']);
    if (data['displayDeliveryFee'] != null) {
      final fee = item.deliveryFee ?? _parseSafeDouble(data['deliveryFee']);
      if (fee != null && fee > 0) {
        item.displayDeliveryFee = _parseSafeString(data['displayDeliveryFee']);
      }
    }
    if (data['displayTotalAmount'] != null)
      item.displayTotalAmount = _parseSafeString(data['displayTotalAmount']);
    if (item.displayFoodPrice == null && item.itemPrice != null) {
      item.displayFoodPrice = '฿${item.itemPrice}';
    }

    final parsedDeliveryAddress = parseDeliveryAddressValue(
      data['deliveryAddress'],
    );
    if (parsedDeliveryAddress != null) {
      item.deliveryAddress = parsedDeliveryAddress;
    }
    if (data['restaurantAddress'] != null)
      item.restaurantAddress = _parseSafeString(data['restaurantAddress']);
    if (data['userLocationName'] != null)
      item.userLocationName = _parseSafeString(data['userLocationName']);

    if (data['restaurantLatitude'] != null &&
        data['restaurantLongitude'] != null) {
      item.restaurantLatLng = LatLng(
        _parseSafeDouble(data['restaurantLatitude'])!,
        _parseSafeDouble(data['restaurantLongitude'])!,
      );
    }
    if (data['customerLatitude'] != null && data['customerLongitude'] != null) {
      item.userLocation = LatLng(
        _parseSafeDouble(data['customerLatitude'])!,
        _parseSafeDouble(data['customerLongitude'])!,
      );
    }

    if (data['cancelReason'] != null) {
      item.cancelReason = _parseSafeString(data['cancelReason']);
    }

    if (data['reviseItems'] != null) {
      final revisePayload = ReviseReasonParser.parseReviseItemsPayload(
        data['reviseItems'],
      );
      if (revisePayload.names.isNotEmpty) {
        item.unavailableItemNames = revisePayload.names;
      }
      if (revisePayload.reason != null && revisePayload.reason!.isNotEmpty) {
        item.unavailableItemReason = revisePayload.reason;
      }
    }

    // Rebuild the editable order items from the backend payload so the revise
    // flow has data even after a cold start (checkout state is gone by then).
    // Only overwrite when the payload actually carries items, to avoid wiping
    // a locally-populated list with an empty array.
    final parsedItems = _parseOrderItems(data['items'], item);
    if (parsedItems.isNotEmpty) {
      item.orderItems = parsedItems;
    }

    // Refined shop fields
    if (data['shopId'] != null) item.shopId = _parseSafeString(data['shopId']);
    if (data['shopNameEn'] != null) {
      final name = _parseSafeString(data['shopNameEn']);
      if (name != null && name.isNotEmpty && name != 'Shop') {
        item.shopNameEn = name;
      }
    } else if (data['shopName'] != null) {
      final name = _parseSafeString(data['shopName']);
      if (name != null && name.isNotEmpty && name != 'Shop') {
        item.shopNameEn = name;
      }
    } else if (data['shop'] is Map) {
      final shopMap = Map<String, dynamic>.from(data['shop'] as Map);
      final nestedName = _parseSafeString(shopMap['nameEn'] ?? shopMap['name']);
      if (nestedName != null && nestedName.isNotEmpty && nestedName != 'Shop') {
        item.shopNameEn = nestedName;
        item.shopName = nestedName;
        item.restaurantName = nestedName;
        item.storeName = nestedName;
      }
      final nestedMm = _parseSafeString(shopMap['nameMm']);
      if (nestedMm != null && nestedMm.isNotEmpty) item.shopNameMm = nestedMm;
      final nestedTh = _parseSafeString(shopMap['nameTh']);
      if (nestedTh != null && nestedTh.isNotEmpty) item.shopNameTh = nestedTh;
    }
    if (data['shopName'] != null) {
      final name = _parseSafeString(data['shopName']);
      if (name != null && name.isNotEmpty && name != 'Shop') {
        item.shopName = name;
      }
    }
    if (data['shopNameMM'] != null || data['shopNameMm'] != null) {
      item.shopNameMm = _parseSafeString(
        data['shopNameMM'] ?? data['shopNameMm'],
      );
    }
    if (data['shopNameTh'] != null || data['shopNameTH'] != null) {
      item.shopNameTh = _parseSafeString(
        data['shopNameTh'] ?? data['shopNameTH'],
      );
    }

    // Improved image mapping with fallbacks
    final rawLogo = data['shopLogo'] ?? data['logoPath'];
    if (rawLogo != null) {
      item.shopLogo = _getFullUrl(_parseSafeString(rawLogo));
      item.logoPath = item.shopLogo; // Sync legacy field
    }

    final shopMap = data['shop'];
    final rawImage =
        data['shopImageUrl'] ??
        data['shopLogo'] ??
        data['logoPath'] ??
        data['logoUrl'] ??
        data['coverUrl'] ??
        data['imageUrl'] ??
        (shopMap is Map<String, dynamic>
            ? ShopImageResolver.resolveShopAvatarFromJson(shopMap)
            : null);
    if (rawImage != null) {
      item.shopImageUrl = _getFullUrl(_parseSafeString(rawImage));
    }

    // Handle ongoing status
    if (data.containsKey('ongoing')) {
      final isOngoing = data['ongoing'] as bool?;
      if (isOngoing == false) {
        // We don't remove it immediately to allow UI to show completion,
        // but it will be filtered out next time or handled by UI
      }
    }

    final String? statusStr = _parseSafeString(
      data['statusName'] ?? data['status'],
    );
    if (statusStr != null) {
      applyStatusString(
        item,
        statusStr,
        reviseReason: _parseSafeString(data['reviseReason']),
      );
    } else if (data['orderStatus'] != null) {
      item.orderStatus = data['orderStatus'] as int;
    }

    // The shared WebSocket stays connected for the whole foreground session so
    // global broadcasts/announcements keep arriving even after orders finish.
    // (Connection lifecycle is managed by LifecycleObserver + auth.)

    saveToPrefs();
    notifyListeners();
  }

  double? _parseSafeDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  ActiveOrderItem? _findTrackedOrder(String? rawId) {
    if (rawId == null) return null;
    final id = rawId.toString();
    if (_orders.containsKey(id)) return _orders[id];
    final sanitized = id.replaceAll('#', '');
    if (_orders.containsKey(sanitized)) return _orders[sanitized];
    for (final entry in _orders.entries) {
      if (entry.key.replaceAll('#', '') == sanitized) return entry.value;
    }
    return null;
  }

  String? _parseSafeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      return value['name']?.toString() ??
          value['label']?.toString() ??
          value['status']?.toString();
    }
    return value.toString();
  }

  /// Maps a backend order `items[]` payload into [CartItem]s for the revise
  /// flow. Handles both the enriched shape (from `mapOrder`: `menuItemName`,
  /// `menuItemImageUrl`, `selectedOptions[]`) and the raw shape (from
  /// `findAwaitingPaymentInfo`: `menuItemId`, `quantity`, `price`, ...).
  List<CartItem> _parseOrderItems(dynamic raw, ActiveOrderItem order) {
    if (raw is! List || raw.isEmpty) return const [];

    final result = <CartItem>[];
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);

      final menuItemId = _parseSafeInt(map['menuItemId']);
      if (menuItemId == null) continue;

      final menuItem = map['menuItem'] is Map
          ? Map<String, dynamic>.from(map['menuItem'] as Map)
          : const <String, dynamic>{};

      final nameEn =
          _parseSafeString(
            map['menuItemName'] ?? menuItem['nameEn'] ?? menuItem['name'],
          ) ??
          'Item';
      final nameMm = _parseSafeString(
        map['menuItemNameMm'] ?? menuItem['nameMm'],
      );
      final nameTh = _parseSafeString(
        map['menuItemNameTh'] ?? menuItem['nameTh'],
      );
      final imageUrl = _getFullUrl(
        _parseSafeString(
          map['menuItemImageUrl'] ?? map['imageUrl'] ?? menuItem['imageUrl'],
        ),
      );
      final price = _parseSafeDouble(map['price']) ?? 0;
      final quantity = _parseSafeInt(map['quantity']) ?? 1;

      // selectedOptions[] → option ids used when re-submitting the order.
      final optionIds = <int>[];
      final selectedOptions = map['selectedOptions'];
      if (selectedOptions is List) {
        for (final opt in selectedOptions) {
          if (opt is Map) {
            final id = _parseSafeInt(opt['menuItemOptionId']);
            if (id != null) optionIds.add(id);
          }
        }
      }

      result.add(
        CartItem(
          id: _parseSafeString(map['id']) ?? '$menuItemId-$i',
          menuItemId: menuItemId,
          restaurantId: order.shopId ?? order.restaurantId ?? '',
          titleKey: nameEn,
          titleEn: nameEn,
          titleMm: nameMm,
          titleTh: nameTh,
          price: price,
          total: price * quantity,
          imagePath: imageUrl,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
          quantity: quantity,
          optionIds: optionIds.isEmpty ? null : optionIds,
          specialInstructions: _parseSafeString(map['specialInstructions']),
          variantId: _parseSafeInt(map['variantId']),
        ),
      );
    }
    return result;
  }

  int? _parseSafeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _getFullUrl(String? path) => FileUrlUtil.resolve(path);

  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  void updateRouteData({
    required List<LatLng> points,
    required double distanceKm,
    required int durationMins,
    required double fee,
    String? orderId,
  }) {
    final targetId = orderId ?? this.orderId;
    if (targetId == null || !_orders.containsKey(targetId)) return;

    final item = _orders[targetId]!;
    item.routePoints = points;
    item.routeDistanceKm = distanceKm;
    item.routeDurationMins = durationMins;
    item.deliveryFee = fee;

    notifyListeners();
  }

  void updatePaymentMethodImage(String url, {String? orderId}) {
    final targetId = orderId ?? this.orderId;
    if (targetId == null || !_orders.containsKey(targetId)) return;
    _orders[targetId]!.paymentMethodImageUrl = url;
    saveToPrefs();
    notifyListeners();
  }

  Timer? _idleProgressSaveTimer;

  void updateIdleProgress(double val, {String? orderId}) {
    final targetId = orderId ?? this.orderId;
    if (targetId == null || !_orders.containsKey(targetId)) return;
    // Update the in-memory value every frame (cheap), but throttle the disk
    // write. This is called from a 60fps animation listener, so calling
    // saveToPrefs() here directly meant ~60 JSON-encode + SharedPreferences
    // writes per second — a major jank source on the order tracking screen.
    // The value is only ever read once (to seed the animation on re-entry),
    // so persisting it at most once per second is more than enough.
    _orders[targetId]!.idleSolidProgress = val;
    // Don't notify listeners here to avoid rebuild loops during animation.
    if (_idleProgressSaveTimer?.isActive ?? false) return;
    _idleProgressSaveTimer = Timer(const Duration(seconds: 1), saveToPrefs);
  }

  Future<bool> cancelActiveOrder({String? reason, String? orderId}) async {
    final targetId = orderId ?? this.orderId;
    if (targetId == null || !_orders.containsKey(targetId)) return false;

    // Concurrency guard
    if (_cancellingOrders.contains(targetId)) return false;
    _cancellingOrders.add(targetId);

    final sanitizedOrderId = targetId.replaceAll('#', '');
    // Mark as user-cancelled up front (before the network round-trip) so that a
    // CANCELED WebSocket frame arriving mid-flight doesn't trigger the
    // restaurant-cancellation page.
    _userCancelledOrderIds.add(sanitizedOrderId);

    try {
      // Backend: PATCH /api/user/orders/:id/payment with status=CANCELED.
      // The endpoint is multipart (FileInterceptor('paymentImage')), but the
      // image is only required when status != CANCELED. Cancel-only requests
      // can send a plain JSON body with `status: 'CANCELED'`.
      final response = await ApiClient().dio.patch(
        '${ApiClient.apiPrefix}/user/orders/$sanitizedOrderId/payment',
        data: FormData.fromMap({
          'status': 'CANCELED',
          if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _cancellingOrders.remove(targetId);
        clearOrder(orderId: targetId);
        return true;
      }

      // Non-success HTTP — keep the active order in local state.
      _userCancelledOrderIds.remove(sanitizedOrderId);
      _cancellingOrders.remove(targetId);
      return false;
    } catch (e) {
      _userCancelledOrderIds.remove(sanitizedOrderId);
      _cancellingOrders.remove(targetId);
      return false;
    }
  }

  void clearOrder({String? orderId}) {
    if (orderId != null) {
      _orders.remove(orderId);
      if (_primaryOrderId == orderId) {
        _primaryOrderId = null;
      }
    } else {
      _orders.clear();
      _primaryOrderId = null;
    }

    _reassignPrimaryOrderId();

    // Keep the shared WebSocket open even with no orders so global
    // broadcasts/announcements still reach the user (lifecycle is owned by
    // LifecycleObserver + auth, not by the order list).

    saveToPrefs();
    notifyListeners();
  }

  /// Maps a backend order status string onto an [ActiveOrderItem]'s internal
  /// [ActiveOrderItem.orderStatus] (-1..4) and the payment/revise flags.
  ///
  /// Single source of truth shared by the WebSocket handler
  /// ([updateFromSocket]) and the API hydration path
  /// ([hydrateActiveOrdersFromApi]) so they can never drift apart.
  static void applyStatusString(
    ActiveOrderItem item,
    String statusStr, {
    String? reviseReason,
  }) {
    final upStatus = statusStr.toUpperCase();
    item.backendStatus = upStatus;
    switch (upStatus) {
      case 'REVISED':
        // Shop sent the order back for revision. Keep it on the awaiting
        // screen (status 0) but flag it so the revise banner shows.
        item.orderStatus = 0;
        item.showUploadSection = false;
        item.isPaymentChecking = false;
        item.isRevised = true;
        item.reviseReason = reviseReason ?? item.reviseReason;
        break;
      case 'PENDING':
        item.orderStatus = 0;
        item.showUploadSection = false;
        break;
      case 'AWAITING_APPROVAL':
        // Slip uploaded; shop is reviewing it. This is a forward step, not a
        // return to "awaiting shop confirmation" (status 0).
        item.orderStatus = 1;
        item.showUploadSection = false;
        item.isPaymentChecking = true;
        break;
      case 'CONFIRMED':
        item.orderStatus = 1;
        item.showUploadSection = false;
        item.isPaymentChecking = false;
        break;
      case 'PAYMENT_UPLOADED':
      case 'PAYMENT_CHECKING':
        item.orderStatus = 1;
        item.showUploadSection = false;
        item.isPaymentChecking = true;
        break;
      case 'PAYMENT_SLIP_REQUESTED':
        item.orderStatus = 1;
        item.isPaymentChecking = false;
        // PAYMENT_SLIP_REQUESTED covers two different moments:
        // 1) Shop confirmed the order → customer uploads a slip for the first time.
        // 2) Shop called requestSlip → customer must re-upload (reviseReason set).
        // Only (2) should surface the "new receipt requested" UI.
        final slipReuploadRequested =
            reviseReason != null && reviseReason.trim().isNotEmpty;
        item.isSlipRequested = slipReuploadRequested;
        item.showUploadSection = slipReuploadRequested;
        if (slipReuploadRequested) {
          item.reviseReason = reviseReason;
        } else {
          item.reviseReason = null;
        }
        break;
      case 'PAID':
      case 'PAYMENT_VERIFIED':
      case 'PREPARING':
      case 'COOKING':
        item.orderStatus = 2;
        item.showUploadSection = false;
        item.isPaymentChecking = false;
        break;
      case 'READY_FOR_PICKUP':
        item.orderStatus = 2;
        item.showUploadSection = false;
        item.isPaymentChecking = false;
        break;
      case 'ON_THE_WAY':
      case 'DELIVERING':
      case 'SHIPPED':
        item.orderStatus = 3;
        break;
      case 'COMPLETED':
      case 'DELIVERED':
      case 'PICKED_UP':
        item.orderStatus = 4;
        break;
      case 'CANCELED':
      case 'CANCELLED':
        item.orderStatus = -1;
        break;
    }

    // Reset notification flag if status is no longer REQUESTED
    if (upStatus != 'PAYMENT_SLIP_REQUESTED') {
      item.hasNotifiedSlipRequest = false;
      item.isSlipRequested = false;
    }

    // Clear the revise flag once the order moves past REVISED.
    if (upStatus != 'REVISED') {
      item.isRevised = false;
      item.unavailableItemNames = [];
      item.unavailableItemReason = null;
    }

    // The reason is shown on both the REVISED and the PAYMENT_SLIP_REQUESTED
    // screens, so only drop it once the order leaves both of those states.
    if (upStatus != 'REVISED' && upStatus != 'PAYMENT_SLIP_REQUESTED') {
      item.reviseReason = null;
    }
  }

  /// Seeds [_orders] from the backend so active orders survive cold starts,
  /// reinstalls, or cleared prefs (WebSocket/FCM alone can't hydrate an order
  /// the app has never heard of — see the guard in [updateFromSocket]).
  ///
  /// Fetches the user's orders, keeps the still-ongoing ones, registers any
  /// that aren't already tracked locally, then enriches each with full detail.
  Future<void> hydrateActiveOrdersFromApi() async {
    try {
      final all = await OrderRepository().getOrderHistory();
      final ongoing = all.where((o) => o.ongoing).toList();
      if (ongoing.isEmpty) return;

      var added = false;
      for (final o in ongoing) {
        if (_orders.containsKey(o.id)) continue;
        final item = ActiveOrderItem(
          orderId: o.id,
          storeName: o.shopName,
          restaurantName: o.shopName,
          shopId: o.shopId?.toString(),
          shopName: o.shopName,
          shopNameEn: o.shopNameEn,
          shopNameMm: o.shopNameMm,
          shopNameTh: o.shopNameTh,
          shopImageUrl: o.shopImageUrl,
          totalAmount: o.totalAmount,
          itemPrice: o.itemPrice,
          taxAmount: o.taxAmount,
          displayTaxAmount: o.displayTaxAmount,
          taxEnable: o.taxAmount == 0 && (o.itemPrice ?? 0) > 0 ? false : true,
          displayTotalAmount: o.displayTotalAmount,
          deliveryFee: (o.deliveryFee != null && o.deliveryFee! > 0)
              ? o.deliveryFee
              : null,
          displayDeliveryFee: (o.deliveryFee != null && o.deliveryFee! > 0)
              ? o.displayDeliveryFee
              : null,
        );
        applyStatusString(item, o.status);
        _orders[o.id] = item;
        added = true;
      }

      if (added) {
        _reassignPrimaryOrderId();
        saveToPrefs();
        notifyListeners();
      }

      // Enrich each ongoing order with full tracking detail (shop phone, QR,
      // rider, map, etc.). syncActiveOrder funnels through updateFromSocket.
      for (final o in ongoing) {
        await syncActiveOrder(orderId: o.id);
      }
    } catch (_) {
      // Best-effort hydration; silent on failure.
    }
  }

  // Persistence logic
  Future<void> saveToPrefs() async {
    try {
      final userId = AuthService().currentUser?.id;
      if (userId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final ordersKey = _prefsKeyForUser(userId);
      final primaryKey = _primaryPrefsKeyForUser(userId);
      final List<String> ordersJson = _orders.values
          .map((o) => jsonEncode(o.toJson()))
          .toList();
      await prefs.setStringList(ordersKey, ordersJson);
      if (_primaryOrderId != null) {
        await prefs.setString(primaryKey, _primaryOrderId!);
      } else {
        await prefs.remove(primaryKey);
      }
    } catch (e) {
      // Ignore prefs save errors
    }
  }

  Future<void> loadFromPrefs() async {
    try {
      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        resetForUserSession();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final ordersKey = _prefsKeyForUser(userId);
      final primaryKey = _primaryPrefsKeyForUser(userId);
      final List<String>? ordersJson = prefs.getStringList(ordersKey);

      resetForUserSession();
      if (ordersJson != null) {
        for (final jsonStr in ordersJson) {
          try {
            final Map<String, dynamic> data = jsonDecode(jsonStr);
            final item = ActiveOrderItem.fromJson(data);
            _orders[item.orderId] = item;
          } catch (e) {
            // Ignore individual item decode errors
          }
        }
      }

      _purgeTerminalOrders();
      final savedPrimary = prefs.getString(primaryKey);
      if (savedPrimary != null &&
          savedPrimary.isNotEmpty &&
          _orders.containsKey(savedPrimary)) {
        _primaryOrderId = savedPrimary;
      } else {
        _reassignPrimaryOrderId();
      }

      notifyListeners();
    } catch (e) {
      // Ignore prefs load errors
    }
  }
}
