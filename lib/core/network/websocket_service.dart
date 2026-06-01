import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../auth/auth_service.dart';
import '../../features/cart/data/active_order_state.dart';
import '../../features/home/data/repositories/restaurant_repository.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _stompClient;
  bool get isConnected => _stompClient?.connected ?? false;

  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);

  final StreamController<Map<String, dynamic>> _orderUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get orderUpdates =>
      _orderUpdateController.stream;

  final StreamController<Map<String, dynamic>> _menuUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get menuUpdates => _menuUpdateController.stream;

  bool _isConnecting = false;

  void connect({bool force = false}) {
    if (_isConnecting && !force) return;

    if (isConnected && !force) return;

    if (_stompClient != null) {
      if (force) {
        debugPrint(' [WS] Force reconnecting...');
        _stompClient = null;
      } else {
        _stompClient?.activate();
        return;
      }
    }

    _isConnecting = true;
    debugPrint(
      ' [WS] Connecting to: wss://myshopdemoapi-production.up.railway.app/ws/websocket',
    );

    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) {
      debugPrint(' [WS] Connection aborted: No access token found.');
      _isConnecting = false;
      return;
    }

    _stompClient = StompClient(
      config: StompConfig(
        url: 'wss://myshopdemoapi-production.up.railway.app/ws/websocket',
        onConnect: onConnect,
        beforeConnect: () async {
          debugPrint(' [WS] Preparing connection headers...');
        },
        onWebSocketError: (dynamic error) {
          debugPrint(' 🚨 [WS] WebSocket Error: $error');
          _isConnecting = false;
          connectionStatus.value = false;
        },
        onWebSocketDone: () {
          debugPrint(' 🔌 [WS] WebSocket Connection Closed.');
          _isConnecting = false;
          connectionStatus.value = false;
        },
        onDebugMessage: (String message) {
          debugPrint(' ⚙️ [WS] [STOMP] $message');
        },
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        onStompError: (frame) {
          debugPrint(' [WS] STOMP Error: ${frame.body}');
        },
        onUnhandledFrame: (frame) {
          debugPrint(' [WS] Unhandled Frame: ${frame.command}');
        },
        onUnhandledMessage: (frame) {
          debugPrint(' [WS] Unhandled Message: ${frame.body}');
        },
        onUnhandledReceipt: (frame) {
          debugPrint(' [WS] Unhandled Receipt: ${frame.headers}');
        },
        webSocketConnectHeaders: {},
        onDisconnect: (frame) {
          debugPrint(' [WS] Disconnected.');
          connectionStatus.value = false;
        },
        heartbeatOutgoing: const Duration(milliseconds: 10000),
        heartbeatIncoming: const Duration(milliseconds: 10000),
      ),
    );

    _stompClient?.activate();
  }

  void onConnect(dynamic frame) {
    debugPrint(' [WS]   Connected!');
    _isConnecting = false;
    connectionStatus.value = true;

    final token = AuthService().accessToken;
    final headers = {if (token != null) 'Authorization': 'Bearer $token'};

    // Shop API uses /user/queue/shop-order-updates
    const destination = '/user/queue/shop-order-updates';
    debugPrint(' [WS] Subscribing to: $destination');

    _stompClient?.subscribe(
      destination: destination,
      headers: {...headers, 'receipt': 'rcpt-order-updates'},
      callback: (StompFrame frame) {
        if (frame.body == null) return;

        try {
          final decoded = json.decode(frame.body!);
          if (decoded is! Map) return;

          final raw = Map<String, dynamic>.from(decoded);
          final messageType = raw['type']?.toString();

          // ── MENU_ITEM_UPDATE (Real-time Menu synchronization) ─────────────
          if (messageType == 'MENU_ITEM_UPDATE') {
            final shopId = raw['shopId'];
            final itemId = raw['itemId'];
            debugPrint(
              ' 📡 [WS] MENU_ITEM_UPDATE RECEIVED: shopId=$shopId, itemId=$itemId',
            );
            if (shopId != null) {
              final id = int.tryParse(shopId.toString());
              if (id != null) {
                debugPrint(
                  ' ✨ [WS] Triggering cache invalidation for Shop: $id',
                );
                RestaurantRepository.instance.clearCache(shopId: id);
                _menuUpdateController.add(raw);
              }
            }
            return;
          }

          // ── ORDER_UPDATE (existing logic) ─────────────────────────────────
          dynamic payload = raw;

          // Unmarshall if wrapped
          if (payload is Map &&
              payload.containsKey('order') &&
              payload['order'] is Map) {
            payload = payload['order'];
          } else if (payload is Map &&
              payload.containsKey('data') &&
              payload['data'] is Map) {
            payload = payload['data'];
          }

          if (payload is Map) {
            final Map<String, dynamic> orderRaw = Map<String, dynamic>.from(
              payload,
            );

            // Smarter status extraction: check root then nested
            String? status =
                (orderRaw['statusName'] ??
                        orderRaw['statusLabel'] ??
                        orderRaw['status'])
                    ?.toString();

            // Fallback: search in nested fields if still null
            if (status == null) {
              final nested =
                  orderRaw['order'] ?? orderRaw['data'] ?? orderRaw['status'];
              if (nested is Map) {
                status =
                    (nested['statusName'] ??
                            nested['statusLabel'] ??
                            nested['status'] ??
                            nested['name'] ??
                            nested['code'])
                        ?.toString();
              }
            }

            final displayStatus = (status ?? 'UNKNOWN').toUpperCase();
            debugPrint(' 📡 [WS] STATUS: $displayStatus 🔔 ✨');
            debugPrint(' [WS] Message Content: $orderRaw');

            ActiveOrderState.instance.updateFromSocket(orderRaw);
            _orderUpdateController.add(orderRaw);
          }
        } catch (e) {
          // Silent fail for demo
        }
      },
    );
  }

  void disconnect() {
    _stompClient?.deactivate();
    _stompClient = null;
    connectionStatus.value = false;
  }
}
