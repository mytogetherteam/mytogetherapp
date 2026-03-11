import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_manager.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_service.dart';
import 'dart:convert';

class ActiveOrderState extends ChangeNotifier {
  static final ActiveOrderState instance = ActiveOrderState._();
  ActiveOrderState._();

  String? storeName;
  String? restaurantName;
  String? logoPath;
  String? estimatedTime; // e.g. "09:45 PM"
  String? orderId;
  String? restaurantId;
  String? statusLabel;
  String? statusLabelMm;
  bool hasActiveOrder = false;
  String? deliveryAddress;
  String? restaurantAddress;   // shop's physical address
  String? userLocationName;    // user's saved location name (e.g. "Home")
  LatLng? restaurantLatLng;
  LatLng? userLocation;

  // Cached route data
  List<LatLng> routePoints = [];
  double? routeDistanceKm;
  int? routeDurationMins;
  double? deliveryFee;
  String? riderName;
  String? riderPhone;
  String? deliveryTrackingUrl;
  String? deliveryCycleNo;
  String? shopPaymentQrUrl;
  String? displayFoodPrice;
  String? displayDeliveryFee;
  String? displayTotalAmount;

  /// 0: Awaiting Confirmation
  /// 1: Awaiting Payment
  /// 2: Payment Checking
  /// 3: Preparing
  /// 5: Completed
  /// -1: Cancelled
  int orderStatus = 0; 
  String? cancelReason;
  double? totalAmount;
  String? paymentMethod;
  List<CartItem> orderItems = [];

  // Track if we are in upload state in AwaitingPaymentPage
  bool showUploadSection = false;
  void setActiveOrder({
    required String storeName,
    required String restaurantName,
    String? logoPath,
    String? estimatedTime,
    String? orderId,
    String? restaurantId,
  }) {
    this.storeName = storeName;
    this.restaurantName = restaurantName;
    this.logoPath = logoPath;
    this.estimatedTime = estimatedTime;
    this.orderId = orderId ?? DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    this.restaurantId = restaurantId;
    hasActiveOrder = true;
    saveToPrefs();
    notifyListeners();
  }

  void setOrderDetails({
    required double totalAmount,
    required String paymentMethod,
    required List<CartItem> items,
  }) {
    this.totalAmount = totalAmount;
    this.paymentMethod = paymentMethod;
    orderItems = List.from(items);
    saveToPrefs();
    notifyListeners();
  }

  void setOrderStatus(int status) {
    orderStatus = status;
    saveToPrefs();
    notifyListeners();
    
    // Disconnect WebSocket if order is terminal (Completed = 4, Cancelled = -1)
    if (status == 4 || status == -1) {
      debugPrint('🔌 [ActiveOrderState] Order reached terminal status ($status). Disconnecting WebSocket.');
      WebSocketService().disconnect();
    }
  }

  void setShowUploadSection(bool show) {
    showUploadSection = show;
    saveToPrefs();
    notifyListeners();
  }

  void updateFromSocket(Map<String, dynamic> data) {
    // Handle the server wrapper: { "type": "ORDER_UPDATE", "order": { ... } }
    if (data.containsKey('order') && data['order'] is Map) {
      data = data['order'] as Map<String, dynamic>;
    } else if (data.containsKey('data') && data['data'] is Map) {
      data = data['data'] as Map<String, dynamic>;
    }

    // Skip any non-order WebSocket messages (e.g. rating/review updates)
    final String? msgType = data['type'] as String?;
    if (msgType != null && msgType != 'ORDER_UPDATE') return;

    if (data['deliveryFee'] != null) deliveryFee = _parseSafeDouble(data['deliveryFee']);
    if (data['deliveryRiderName'] != null) riderName = data['deliveryRiderName'] as String?;
    if (data['deliveryPhoneNo'] != null) riderPhone = data['deliveryPhoneNo'] as String?;
    if (data['deliveryTrackingUrl'] != null) deliveryTrackingUrl = data['deliveryTrackingUrl'] as String?;
    if (data['deliveryCycleNo'] != null) deliveryCycleNo = data['deliveryCycleNo'] as String?;
    if (data['shopPaymentQrUrl'] != null) shopPaymentQrUrl = data['shopPaymentQrUrl'] as String?;
    if (data['displayFoodPrice'] != null) displayFoodPrice = data['displayFoodPrice'] as String?;
    if (data['displayDeliveryFee'] != null) displayDeliveryFee = data['displayDeliveryFee'] as String?;
    if (data['displayTotalAmount'] != null) displayTotalAmount = data['displayTotalAmount'] as String?;
    if (data['statusLabel'] != null) statusLabel = data['statusLabel'] as String?;
    if (data['statusLabelMm'] != null) statusLabelMm = data['statusLabelMm'] as String?;
    if (data['paymentMethod'] != null) {
      if (data['paymentMethod'] is String) {
        paymentMethod = data['paymentMethod'] as String;
      } else if (data['paymentMethod'] is Map) {
        paymentMethod = data['paymentMethod']['name'] as String? ?? 
                        data['paymentMethod']['code'] as String? ?? 
                        paymentMethod;
      }
    }

    if (data['cancelReason'] != null) {
      cancelReason = data['cancelReason'] as String?;
    }

    // Handle ongoing status
    if (data.containsKey('ongoing')) {
      final isOngoing = data['ongoing'] as bool?;
      if (isOngoing == false) {
        // Drop from active bar but keep data for UI to render history/receipt
        hasActiveOrder = false;
      }
    }

    final String? statusStr = data['status'] as String?;
    if (statusStr != null) {
      final upStatus = statusStr.toUpperCase();
      switch (upStatus) {
        case 'PENDING':
        case 'AWAITING_APPROVAL':
          orderStatus = 0; // Awaiting Confirmation
          showUploadSection = false;
          break;
        case 'CONFIRMED':
          // Shop confirmed order & set delivery fee → user needs to pay
          orderStatus = 1; // Awaiting Payment
          showUploadSection = false;
          break;
        case 'PAYMENT_UPLOADED':
        case 'PAYMENT_CHECKING':
          // User uploaded slip, waiting for shop to verify
          orderStatus = 1; // Awaiting Payment (checking)
          showUploadSection = false;
          break;
        case 'PAYMENT_SLIP_REQUESTED':
          // Shop rejected slip, user must re-upload
          orderStatus = 1; // Awaiting Payment
          showUploadSection = false;
          break;
        case 'PAID':
        case 'PAYMENT_VERIFIED':
        case 'PREPARING':
          orderStatus = 2; // Preparing
          showUploadSection = false;
          break;
        case 'ON_THE_WAY':
        case 'DELIVERING':
        case 'SHIPPED':
          orderStatus = 3; // On the way
          break;
        case 'COMPLETED':
        case 'DELIVERED':
          orderStatus = 4; // Completed
          WebSocketService().disconnect();
          break;
        case 'CANCELLED':
          orderStatus = -1;
          WebSocketService().disconnect();
          break;
      }
    } else if (data['orderStatus'] != null) {
      final int newStatus = data['orderStatus'] as int;
      orderStatus = newStatus;
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

  void updateRouteData({
    required List<LatLng> points,
    required double distanceKm,
    required int durationMins,
    required double fee,
    LatLng? restaurantLatLng,
    LatLng? userLocation,
  }) {
    routePoints = points;
    routeDistanceKm = distanceKm;
    routeDurationMins = durationMins;
    deliveryFee = fee;
    if (restaurantLatLng != null) this.restaurantLatLng = restaurantLatLng;
    if (userLocation != null) this.userLocation = userLocation;
    notifyListeners();
  }

  Future<bool> cancelActiveOrder({String? reason}) async {
    if (orderId == null) {
      debugPrint('cancelActiveOrder: orderId is null');
      return false;
    }
    
    final String cancelReason = reason ?? 'test';
    final String sanitizedOrderId = orderId!.replaceAll('#', '');
    
    debugPrint('cancelActiveOrder: Attempting to cancel order $sanitizedOrderId');
    
    try {
      final response = await ApiClient().dio.put(
        '${ApiClient.apiPrefix}/orders/$sanitizedOrderId/cancel',
        queryParameters: {'reason': cancelReason},
        data: {}, // Explicitly pass empty body for PUT
        options: Options(
          contentType: 'application/json',
          headers: {
            'Accept': '*/*',
          },
        ),
      );
      
      debugPrint('cancelActiveOrder: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        WebSocketService().disconnect();
        clearOrder();
        return true;
      }
    } catch (e) {
      debugPrint('cancelActiveOrder: Error: $e');
      // If it's a 404 or 400, it's likely already cancelled or in an un-cancellable state
      // but the user wants to clear the local state regardless.
      WebSocketService().disconnect();
      clearOrder();
      return true; 
    }
    
    // Fallback: clear anyway to resolve UX hang
    WebSocketService().disconnect();
    clearOrder();
    return true;
  }

  void clearOrder() {
    // Ensure WebSocket is closed when clearing the order state
    WebSocketService().disconnect();
    
    storeName = null;
    restaurantName = null;
    logoPath = null;
    estimatedTime = null;
    orderId = null;
    hasActiveOrder = false;
    orderStatus = 0;
    totalAmount = null;
    paymentMethod = null;
    cancelReason = null;
    orderItems = [];
    routePoints = [];
    routeDistanceKm = null;
    routeDurationMins = null;
    deliveryFee = null;
    riderName = null;
    riderPhone = null;
    deliveryTrackingUrl = null;
    deliveryCycleNo = null;
    shopPaymentQrUrl = null;
    displayFoodPrice = null;
    displayDeliveryFee = null;
    displayTotalAmount = null;
    statusLabel = null;
    statusLabelMm = null;
    showUploadSection = false;
    deliveryAddress = null;
    restaurantAddress = null;
    userLocationName = null;
    restaurantId = null;
    restaurantLatLng = null;
    userLocation = null;
    saveToPrefs();
    notifyListeners();
  }

  // Persistence logic
  Future<void> saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasActiveOrder', hasActiveOrder);
      await prefs.setString('storeName', storeName ?? '');
      await prefs.setString('restaurantName', restaurantName ?? '');
      await prefs.setString('logoPath', logoPath ?? '');
      await prefs.setString('estimatedTime', estimatedTime ?? '');
      await prefs.setString('orderId', orderId ?? '');
      await prefs.setString('restaurantId', restaurantId ?? '');
      await prefs.setInt('orderStatus', orderStatus);
      await prefs.setDouble('totalAmount', totalAmount ?? 0.0);
      await prefs.setString('paymentMethod', paymentMethod ?? '');
      await prefs.setString('cancelReason', cancelReason ?? '');
      await prefs.setDouble('deliveryFee', deliveryFee ?? 0.0);
      await prefs.setString('riderName', riderName ?? '');
      await prefs.setString('riderPhone', riderPhone ?? '');
      await prefs.setString('deliveryTrackingUrl', deliveryTrackingUrl ?? '');
      await prefs.setString('deliveryCycleNo', deliveryCycleNo ?? '');
      await prefs.setString('shopPaymentQrUrl', shopPaymentQrUrl ?? '');
      await prefs.setString('displayFoodPrice', displayFoodPrice ?? '');
      await prefs.setString('displayDeliveryFee', displayDeliveryFee ?? '');
      await prefs.setString('displayTotalAmount', displayTotalAmount ?? '');
      await prefs.setString('statusLabel', statusLabel ?? '');
      await prefs.setString('statusLabelMm', statusLabelMm ?? '');
      await prefs.setString('deliveryAddress', deliveryAddress ?? '');
      await prefs.setString('restaurantAddress', restaurantAddress ?? '');
      await prefs.setString('userLocationName', userLocationName ?? '');
      await prefs.setBool('showUploadSection', showUploadSection);

      // Serialize routePoints
      if (routePoints.isNotEmpty) {
        final List<Map<String, double>> pointsJson = routePoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList();
        await prefs.setString('routePoints', jsonEncode(pointsJson));
      } else {
        await prefs.remove('routePoints');
      }
      await prefs.setDouble('routeDistanceKm', routeDistanceKm ?? 0.0);
      await prefs.setInt('routeDurationMins', routeDurationMins ?? 0);
    } catch (e) {
      debugPrint('Error saving order state: $e');
    }
  }

  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hasActiveOrder = prefs.getBool('hasActiveOrder') ?? false;
      if (hasActiveOrder) {
        storeName = prefs.getString('storeName');
        restaurantName = prefs.getString('restaurantName');
        logoPath = prefs.getString('logoPath');
        estimatedTime = prefs.getString('estimatedTime');
        orderId = prefs.getString('orderId');
        restaurantId = prefs.getString('restaurantId');
        orderStatus = prefs.getInt('orderStatus') ?? 0;
        totalAmount = prefs.getDouble('totalAmount');
        paymentMethod = prefs.getString('paymentMethod');
        cancelReason = prefs.getString('cancelReason');
        deliveryFee = prefs.getDouble('deliveryFee');
        riderName = prefs.getString('riderName');
        riderPhone = prefs.getString('riderPhone');
        deliveryTrackingUrl = prefs.getString('deliveryTrackingUrl');
        deliveryCycleNo = prefs.getString('deliveryCycleNo');
        shopPaymentQrUrl = prefs.getString('shopPaymentQrUrl');
        displayFoodPrice = prefs.getString('displayFoodPrice');
        displayDeliveryFee = prefs.getString('displayDeliveryFee');
        displayTotalAmount = prefs.getString('displayTotalAmount');
        statusLabel = prefs.getString('statusLabel');
        statusLabelMm = prefs.getString('statusLabelMm');
        showUploadSection = prefs.getBool('showUploadSection') ?? false;

        routeDistanceKm = prefs.getDouble('routeDistanceKm');
        routeDurationMins = prefs.getInt('routeDurationMins');
        if (routeDistanceKm == 0.0) routeDistanceKm = null;
        if (routeDurationMins == 0) routeDurationMins = null;

        final String? pointsStr = prefs.getString('routePoints');
        if (pointsStr != null && pointsStr.isNotEmpty) {
          try {
            final List<dynamic> decoded = jsonDecode(pointsStr);
            routePoints = decoded.map((p) => LatLng(p['lat'], p['lng'])).toList();
          } catch (e) {
            debugPrint('Error decoding routePoints: $e');
          }
        }
        
        if (riderName == '') riderName = null;
        if (riderPhone == '') riderPhone = null;
        if (deliveryTrackingUrl == '') deliveryTrackingUrl = null;
        if (deliveryCycleNo == '') deliveryCycleNo = null;
        if (shopPaymentQrUrl == '') shopPaymentQrUrl = null;
        if (displayFoodPrice == '') displayFoodPrice = null;
        if (displayDeliveryFee == '') displayDeliveryFee = null;
        if (displayTotalAmount == '') displayTotalAmount = null;
        if (statusLabel == '') statusLabel = null;
        if (statusLabelMm == '') statusLabelMm = null;
        
        if (storeName == '') storeName = null;
        if (restaurantName == '') restaurantName = null;
        if (logoPath == '') logoPath = null;
        if (estimatedTime == '') estimatedTime = null;
        if (orderId == '') orderId = null;
        if (restaurantId == '') restaurantId = null;
        deliveryAddress = prefs.getString('deliveryAddress');
        restaurantAddress = prefs.getString('restaurantAddress');
        userLocationName = prefs.getString('userLocationName');
        if (deliveryAddress == '') deliveryAddress = null;
        if (restaurantAddress == '') restaurantAddress = null;
        if (userLocationName == '') userLocationName = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading order state: $e');
    }
  }
}
