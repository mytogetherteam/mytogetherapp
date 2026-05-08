import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_manager.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_service.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'dart:convert';

class ActiveOrderItem {
  final String orderId;
  String? storeName;
  String? restaurantName;
  String? logoPath;
  String? estimatedTime;
  String? restaurantId;
  String? statusLabel;
  String? statusLabelMm;
  int orderStatus; // 0: Awaiting Confirmation, etc.
  double? totalAmount;
  String? paymentMethod;
  String? cancelReason;
  List<CartItem> orderItems;
  bool showUploadSection;
  bool isPaymentChecking;
  
  // Refined shop details from WS
  String? shopId;
  String? shopName;
  String? shopNameMm;
  String? shopLogo;
  String? shopImageUrl;
  
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

  // Missing fields for backward compatibility
  String? deliveryAddress;
  String? restaurantAddress;
  String? userLocationName;
  LatLng? restaurantLatLng;
  LatLng? userLocation;
  String? displayFoodPrice;
  String? displayDeliveryFee;
  String? displayTotalAmount;
  double? idleSolidProgress;
  bool hasNotifiedSlipRequest;
  bool isSlipRequested;

  ActiveOrderItem({
    required this.orderId,
    this.storeName,
    this.restaurantName,
    this.logoPath,
    this.estimatedTime,
    this.restaurantId,
    this.statusLabel,
    this.statusLabelMm,
    this.orderStatus = 0,
    this.totalAmount,
    this.paymentMethod,
    this.cancelReason,
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
    this.displayDeliveryFee,
    this.displayTotalAmount,
    this.idleSolidProgress,
    this.hasNotifiedSlipRequest = false,
    this.isSlipRequested = false,
    this.shopId,
    this.shopName,
    this.shopNameMm,
    this.shopLogo,
    this.shopImageUrl,
    this.paymentMethodId,
    this.paymentMethodImageUrl,
  });

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'storeName': storeName,
    'restaurantName': restaurantName,
    'logoPath': logoPath,
    'estimatedTime': estimatedTime,
    'restaurantId': restaurantId,
    'statusLabel': statusLabel,
    'statusLabelMm': statusLabelMm,
    'orderStatus': orderStatus,
    'totalAmount': totalAmount,
    'paymentMethod': paymentMethod,
    'cancelReason': cancelReason,
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
    'displayDeliveryFee': displayDeliveryFee,
    'displayTotalAmount': displayTotalAmount,
    'idleSolidProgress': idleSolidProgress,
    'shopId': shopId,
    'shopName': shopName,
    'shopNameMm': shopNameMm,
    'shopLogo': shopLogo,
    'shopImageUrl': shopImageUrl,
    'paymentMethodId': paymentMethodId,
    'paymentMethodImageUrl': paymentMethodImageUrl,
  };

  factory ActiveOrderItem.fromJson(Map<String, dynamic> json) => ActiveOrderItem(
    orderId: json['orderId'],
    storeName: json['storeName'],
    restaurantName: json['restaurantName'],
    logoPath: json['logoPath'],
    estimatedTime: json['estimatedTime'],
    restaurantId: json['restaurantId'],
    statusLabel: json['statusLabel'],
    statusLabelMm: json['statusLabelMm'],
    orderStatus: json['orderStatus'] ?? 0,
    totalAmount: json['totalAmount'],
    paymentMethod: json['paymentMethod'],
    cancelReason: json['cancelReason'],
    showUploadSection: json['showUploadSection'] ?? false,
    isPaymentChecking: json['isPaymentChecking'] ?? false,
    routeDistanceKm: json['routeDistanceKm'],
    routeDurationMins: json['routeDurationMins'],
    deliveryFee: json['deliveryFee'],
    riderName: json['riderName'],
    riderPhone: json['riderPhone'],
    deliveryTrackingUrl: json['deliveryTrackingUrl'],
    shopPaymentQrUrl: json['shopPaymentQrUrl'],
    deliveryAddress: json['deliveryAddress'],
    restaurantAddress: json['restaurantAddress'],
    userLocationName: json['userLocationName'],
    restaurantLatLng: (json['restaurantLat'] != null && json['restaurantLng'] != null)
        ? LatLng(json['restaurantLat'], json['restaurantLng'])
        : null,
    userLocation: (json['userLat'] != null && json['userLng'] != null)
        ? LatLng(json['userLat'], json['userLng'])
        : null,
    displayFoodPrice: json['displayFoodPrice'],
    displayDeliveryFee: json['displayDeliveryFee'],
    displayTotalAmount: json['displayTotalAmount'],
    idleSolidProgress: json['idleSolidProgress'],
    shopId: json['shopId'],
    shopName: json['shopName'],
    shopNameMm: json['shopNameMm'],
    shopLogo: json['shopLogo'],
    shopImageUrl: json['shopImageUrl'],
    paymentMethodId: json['paymentMethodId'],
    paymentMethodImageUrl: json['paymentMethodImageUrl'],
  );
}

class ActiveOrderState extends ChangeNotifier {
  static final ActiveOrderState instance = ActiveOrderState._();
  ActiveOrderState._();

  final Map<String, ActiveOrderItem> _orders = {};
  final Set<String> _cancellingOrders = {}; 
  
  // Returns only non-terminal orders (not COMPLETED or CANCELLED)
  List<ActiveOrderItem> get activeOrdersList => _orders.values
      .where((o) => o.orderStatus != 4 && o.orderStatus != -1)
      .toList();
      
  // Returns everything currently tracked
  List<ActiveOrderItem> get allOrdersList => _orders.values.toList();
  
  // --- Properties & Backward Compatibility ---
  bool get hasActiveOrder => activeOrdersList.isNotEmpty;
  set hasActiveOrder(bool val) { /* Legacy compatibility setter */ }
  
  ActiveOrderItem? get _primary => _orders.isNotEmpty ? _orders.values.first : null;

  // Helper to get a specific order
  ActiveOrderItem? getOrder(String? id) => _orders[id];

  String? get orderId => _primary?.orderId;
  set orderId(String? val) {
    if (val == null) return;
    if (!_orders.containsKey(val)) {
      _orders[val] = ActiveOrderItem(orderId: val);
      notifyListeners();
    }
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
  double? get totalAmount => _primary?.totalAmount;
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
  int? get paymentMethodId => _primary?.paymentMethodId;
  String? get paymentMethodImageUrl => _primary?.paymentMethodImageUrl;
  String? get cancelReason => _primary?.cancelReason;
  set cancelReason(String? val) { if (_primary != null) _primary!.cancelReason = val; }

  // Refined shop details getters
  String? get shopId => _primary?.shopId;
  String? get shopName => _primary?.shopName;
  String? get shopNameMm => _primary?.shopNameMm;
  String? get shopLogo => _primary?.shopLogo;
  String? get shopImageUrl => _primary?.shopImageUrl;

  // More restored getters/setters for legacy UI
  String? get deliveryAddress => _primary?.deliveryAddress;
  set deliveryAddress(String? val) { if (_primary != null) _primary!.deliveryAddress = val; }

  String? get restaurantAddress => _primary?.restaurantAddress;
  set restaurantAddress(String? val) { if (_primary != null) _primary!.restaurantAddress = val; }

  String? get userLocationName => _primary?.userLocationName;
  set userLocationName(String? val) { if (_primary != null) _primary!.userLocationName = val; }

  LatLng? get restaurantLatLng => _primary?.restaurantLatLng;
  set restaurantLatLng(LatLng? val) { if (_primary != null) _primary!.restaurantLatLng = val; }

  LatLng? get userLocation => _primary?.userLocation;
  set userLocation(LatLng? val) { if (_primary != null) _primary!.userLocation = val; }

  String? get displayFoodPrice => _primary?.displayFoodPrice;
  set displayFoodPrice(String? val) { if (_primary != null) _primary!.displayFoodPrice = val; }

  String? get displayDeliveryFee => _primary?.displayDeliveryFee;
  set displayDeliveryFee(String? val) { if (_primary != null) _primary!.displayDeliveryFee = val; }

  String? get displayTotalAmount => _primary?.displayTotalAmount;
  set displayTotalAmount(String? val) { if (_primary != null) _primary!.displayTotalAmount = val; }

  double? get idleSolidProgress => _primary?.idleSolidProgress;
  set idleSolidProgress(double? val) { if (_primary != null) _primary!.idleSolidProgress = val; }

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
  }) {
    final id = orderId ?? DateTime.now().millisecondsSinceEpoch.toString().substring(7);
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
    );
    saveToPrefs();
    notifyListeners();
  }

  void setOrderDetails({
    required double totalAmount,
    required String paymentMethod,
    required List<CartItem> items,
    int? paymentMethodId,
    String? paymentMethodImageUrl,
    String? orderId,
  }) {
    final targetId = orderId ?? this.orderId;
    if (targetId == null || !_orders.containsKey(targetId)) return;
    
    final item = _orders[targetId]!;
    item.totalAmount = totalAmount;
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
    
    // Disconnect WebSocket only if ALL orders are terminal
    if (status == 4 || status == -1) {
      final allTerminal = _orders.isNotEmpty && _orders.values.every((o) => o.orderStatus == 4 || o.orderStatus == -1);
      if (allTerminal && !kIsWeb) {
        WebSocketService().disconnect();
      }
    }
    
    saveToPrefs();
    notifyListeners();
  }



  Future<void> syncActiveOrder({String? orderId}) async {
    final targetId = orderId ?? this.orderId;
    if (targetId == null || !hasActiveOrder) return;
    
    try {
      final sanitizedOrderId = targetId.replaceAll('#', '');
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/orders/$sanitizedOrderId',
        options: Options(extra: {'@dio_cache_interceptor@': CacheOptions(store: MemCacheStore(), policy: CachePolicy.refresh)}),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> data = response.data as Map<String, dynamic>;
        // Unwrap success/data envelope if present
        if (data.containsKey('data') && data['data'] is Map) {
          data = Map<String, dynamic>.from(data['data'] as Map);
        }
        data['orderId'] = targetId;
        updateFromSocket(data);
      }
    } catch (e) {
      // Silent fail
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

    // Identify the target order
    final id = data['orderId']?.toString() ?? data['id']?.toString() ?? orderId;
    if (id == null || !_orders.containsKey(id)) return;
    
    final item = _orders[id]!;

    if (data['deliveryFee'] != null) item.deliveryFee = _parseSafeDouble(data['deliveryFee']);
    if (data['deliveryRiderName'] != null) item.riderName = _parseSafeString(data['deliveryRiderName']);
    if (data['deliveryPhoneNo'] != null) item.riderPhone = _parseSafeString(data['deliveryPhoneNo']);

    final trackingUrl = _parseSafeString(data['deliveryTrackingUrl']);
    if (trackingUrl != null && _isValidUrl(trackingUrl)) item.deliveryTrackingUrl = trackingUrl;

    final qrUrl = _parseSafeString(data['shopPaymentQrUrl']);
    if (qrUrl != null && _isValidUrl(qrUrl)) item.shopPaymentQrUrl = qrUrl;

    final logoUrl = _parseSafeString(data['logoPath']);
    if (logoUrl != null && _isValidUrl(logoUrl)) item.logoPath = logoUrl;

    if (data['statusLabel'] != null) item.statusLabel = _parseSafeString(data['statusLabel']);
    if (data['statusLabelMm'] != null) item.statusLabelMm = _parseSafeString(data['statusLabelMm']);
    
    if (data['paymentMethod'] != null) {
      if (data['paymentMethod'] is String) {
        item.paymentMethod = data['paymentMethod'] as String;
      } else if (data['paymentMethod'] is Map) {
        item.paymentMethod = _parseSafeString(data['paymentMethod']['name'] ?? data['paymentMethod']['code']);
      }
    }

    if (data['displayFoodPrice'] != null) item.displayFoodPrice = _parseSafeString(data['displayFoodPrice']);
    if (data['displayDeliveryFee'] != null) item.displayDeliveryFee = _parseSafeString(data['displayDeliveryFee']);
    if (data['displayTotalAmount'] != null) item.displayTotalAmount = _parseSafeString(data['displayTotalAmount']);

    if (data['deliveryAddress'] != null) item.deliveryAddress = _parseSafeString(data['deliveryAddress']);
    if (data['restaurantAddress'] != null) item.restaurantAddress = _parseSafeString(data['restaurantAddress']);
    if (data['userLocationName'] != null) item.userLocationName = _parseSafeString(data['userLocationName']);

    if (data['restaurantLatitude'] != null && data['restaurantLongitude'] != null) {
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

    // Refined shop fields
    if (data['shopId'] != null) item.shopId = _parseSafeString(data['shopId']);
    if (data['shopName'] != null) item.shopName = _parseSafeString(data['shopName']);
    if (data['shopNameMM'] != null) item.shopNameMm = _parseSafeString(data['shopNameMM']);
    if (data['shopLogo'] != null) item.shopLogo = _parseSafeString(data['shopLogo']);
    if (data['shopImageUrl'] != null) item.shopImageUrl = _parseSafeString(data['shopImageUrl']);

    // Handle ongoing status
    if (data.containsKey('ongoing')) {
      final isOngoing = data['ongoing'] as bool?;
      if (isOngoing == false) {
        // We don't remove it immediately to allow UI to show completion, 
        // but it will be filtered out next time or handled by UI
      }
    }

    final String? statusStr = _parseSafeString(data['statusName'] ?? data['status']);
    if (statusStr != null) {
      final upStatus = statusStr.toUpperCase();
      switch (upStatus) {
        case 'PENDING':
        case 'AWAITING_APPROVAL':
          item.orderStatus = 0; 
          item.showUploadSection = false;
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
          item.showUploadSection = true; 
          item.isPaymentChecking = false;
          item.isSlipRequested = true;
          break;
        case 'PAID':
        case 'PAYMENT_VERIFIED':
        case 'PREPARING':
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
          item.orderStatus = 4;
          break;
        case 'CANCELLED':
          item.orderStatus = -1;
          break;
      }
      
      // Reset notification flag if status is no longer REQUESTED
      if (upStatus != 'PAYMENT_SLIP_REQUESTED') {
        item.hasNotifiedSlipRequest = false;
        item.isSlipRequested = false;
      }
    } else if (data['orderStatus'] != null) {
      item.orderStatus = data['orderStatus'] as int;
    }

    // Disconnect if ALL orders are terminal
    final allTerminal = _orders.isNotEmpty && _orders.values.every((o) => o.orderStatus == 4 || o.orderStatus == -1);
    if (allTerminal && !kIsWeb) {
       WebSocketService().disconnect();
    }

    saveToPrefs();
    notifyListeners();
  }

  double? _parseSafeDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _parseSafeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      return value['name']?.toString() ?? value['label']?.toString() ?? value['status']?.toString();
    }
    return value.toString();
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
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

  void updateIdleProgress(double val, {String? orderId}) {
    final targetId = orderId ?? this.orderId;
    if (targetId == null || !_orders.containsKey(targetId)) return;
    _orders[targetId]!.idleSolidProgress = val;
    // Don't notify listeners here to avoid rebuild loops during animation
    // Just save the state
    saveToPrefs();
  }


  Future<bool> cancelActiveOrder({String? reason, String? orderId}) async {
    final targetId = orderId ?? this.orderId;
    if (targetId == null || !_orders.containsKey(targetId)) return false;
    
    // Concurrency guard
    if (_cancellingOrders.contains(targetId)) return false;
    _cancellingOrders.add(targetId);
    
    final sanitizedOrderId = targetId.replaceAll('#', '');
    
    try {
      final response = await ApiClient().dio.put(
        '${ApiClient.apiPrefix}/orders/$sanitizedOrderId/cancel',
        queryParameters: {'reason': reason ?? 'User cancelled'},
        data: {},
        options: Options(contentType: 'application/json'),
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        _cancellingOrders.remove(targetId);
        clearOrder(orderId: targetId);
        return true;
      }
    } catch (e) {
      _cancellingOrders.remove(targetId);
      clearOrder(orderId: targetId);
      return true; 
    }
    
    _cancellingOrders.remove(targetId);
    clearOrder(orderId: targetId);
    return true;
  }

  void clearOrder({String? orderId}) {
    if (orderId != null) {
      _orders.remove(orderId);
    } else {
      _orders.clear();
    }
    
    if (_orders.isEmpty && !kIsWeb) {
      WebSocketService().disconnect();
    }
    
    saveToPrefs();
    notifyListeners();
  }

  // Persistence logic
  Future<void> saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> ordersJson = _orders.values
          .map((o) => jsonEncode(o.toJson()))
          .toList();
      await prefs.setStringList('active_orders_v2', ordersJson);
    } catch (e) {
      // Ignore prefs save errors
    }
  }

  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? ordersJson = prefs.getStringList('active_orders_v2');
      
      if (ordersJson != null) {
        _orders.clear();
        for (final jsonStr in ordersJson) {
          try {
            final Map<String, dynamic> data = jsonDecode(jsonStr);
            final item = ActiveOrderItem.fromJson(data);
            _orders[item.orderId] = item;
          } catch (e) {
            // Ignore individual item decode errors
          }
        }
      } else {
        // Fallback for transition from v1 (single order)
        final bool legacyActive = prefs.getBool('hasActiveOrder') ?? false;
        if (legacyActive) {
          final legacyId = prefs.getString('orderId');
          if (legacyId != null && legacyId.isNotEmpty) {
             _orders[legacyId] = ActiveOrderItem(
               orderId: legacyId,
               storeName: prefs.getString('storeName'),
               restaurantName: prefs.getString('restaurantName'),
               logoPath: prefs.getString('logoPath'),
               orderStatus: prefs.getInt('orderStatus') ?? 0,
             );
          }
        }
      }
      notifyListeners();
    } catch (e) {
      // Ignore prefs load errors
    }
  }
}
