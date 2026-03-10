import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../auth/auth_service.dart';
import '../../features/cart/data/active_order_state.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _stompClient;
  bool get isConnected => _stompClient?.connected ?? false;
  
  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);

  final StreamController<Map<String, dynamic>> _orderUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get orderUpdates => _orderUpdateController.stream;

  bool _isConnecting = false;

  void connect({bool force = false}) {
    if (_isConnecting && !force) return;

    if (isConnected && !force) return;

    if (_stompClient != null) {
      if (force) {
        _stompClient = null;
      } else {
        _stompClient?.activate();
        return;
      }
    }

    _isConnecting = true;

    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('❌ [WebSocket] Token missing.');
      return;
    }

    _stompClient = StompClient(
      config: StompConfig(
        // Use the raw WebSocket endpoint for SockJS compliance
        url: 'wss://mytogetherapi-production.up.railway.app/ws/websocket',
        onConnect: onConnect,
        beforeConnect: () async {},
        onWebSocketError: (dynamic error) {
          _isConnecting = false;
          connectionStatus.value = false;
          debugPrint('❌ [WebSocket] Error: $error');
        },
        onDebugMessage: (String message) {},
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        onStompError: (frame) {
          debugPrint('❌ [WebSocket] STOMP Error: ${frame.body}');
        },
        onUnhandledFrame: (frame) {},
        onUnhandledMessage: (frame) {},
        onUnhandledReceipt: (frame) {},
        // Avoid custom headers in HTTP Upgrade to prevent 400 errors on some proxies
        webSocketConnectHeaders: {}, 
        onDisconnect: (frame) {
          connectionStatus.value = false;
          debugPrint('Disconnected from WebSocket');
        },
        heartbeatOutgoing: const Duration(milliseconds: 10000),
        heartbeatIncoming: const Duration(milliseconds: 10000),
      ),
    );

    _stompClient?.activate();
  }

  void onConnect(dynamic frame) {
    _isConnecting = false;
    connectionStatus.value = true;
    
    final currentUser = AuthService().currentUser;
    final email = currentUser?.email;
    final username = currentUser?.username;
    final userId = currentUser?.id;
    final activeOrderId = ActiveOrderState.instance.orderId;

    final destinations = {
      '/user/queue/order-updates',
      '/user/topic/order-updates',
      '/topic/order-updates',
      '/topic/orders',
      '/topic/order-status',
      '/queue/order-updates',
      if (activeOrderId != null) ...{
        '/topic/order-updates-$activeOrderId',
        '/topic/order-updates/$activeOrderId',
        '/topic/order-updates.$activeOrderId',
        '/queue/order-updates-$activeOrderId',
        '/topic/order/$activeOrderId',
        '/topic/order-status/$activeOrderId',
        '/queue/order/$activeOrderId',
        '/topic/orders/$activeOrderId',
        '/exchange/order-updates/$activeOrderId',
      },
      if (userId != null) ...{
        '/user/$userId/queue/order-updates',
        '/user/$userId/topic/order-updates',
        '/user/$userId/queue/notifications',
      },
      if (email != null) ...{
        '/user/$email/queue/order-updates',
        '/user/${email.toLowerCase()}/queue/order-updates',
        '/user/$email/topic/order-updates',
      },
      if (username != null) ...{
        '/user/$username/queue/order-updates',
        '/user/${username.toLowerCase()}/queue/order-updates',
        '/user/$username/topic/order-updates',
      },
      '/user/queue/reply',
      '/topic/public',
    };

    final token = AuthService().accessToken;
    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
    };

    for (final destination in destinations) {
      _stompClient?.subscribe(
        destination: destination,
        headers: {
          ...headers,
          'receipt': 'rcpt-$destination',
        },
        callback: (StompFrame frame) {
          if (frame.body != null) {
            // debugPrint('📦 [WebSocket] Message on: $destination');
            try {
              final Map<String, dynamic> data = json.decode(frame.body!);
              data['_destination'] = destination;
              
              // Centralized state update
              ActiveOrderState.instance.updateFromSocket(data);
              
              _orderUpdateController.add(data);
            } catch (e) {
              debugPrint('❌ [WebSocket] Parsing Error: $e');
            }
          }
        },
      );
    }
  }

  void disconnect() {
    _stompClient?.deactivate();
    _stompClient = null;
    connectionStatus.value = false;
  }
}
