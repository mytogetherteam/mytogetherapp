import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../auth/auth_service.dart';
import '../../features/cart/data/active_order_state.dart';
import '../../features/home/data/repositories/restaurant_repository.dart';
import '../../features/announcements/data/models/announcement_model.dart';
import '../../features/announcements/presentation/announcement_presenter.dart';

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

  /// Public broadcast: a shop's realtime fields changed (isOpen /
  /// deliveryEnabled). Payload: { type: SHOP_PROFILE_UPDATE, shopId, ... }.
  final StreamController<Map<String, dynamic>> _shopProfileUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get shopProfileUpdates =>
      _shopProfileUpdateController.stream;

  bool _isConnecting = false;

  /// STOMP-over-WebSocket endpoint exposed by NestJS at `/ws/websocket`
  /// (see `src/modules/events/events.gateway.ts`).
  ///
  /// Mirrors `ApiClient.baseUrl`; uses secure `wss://` for the production
  /// (TLS) host.
  static String get _wsUrl {
    return 'wss://api.mytogether.org/ws/websocket';
  }

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
    debugPrint(' [WS] Connecting to: $_wsUrl');

    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) {
      debugPrint(' [WS] Connection aborted: No access token found.');
      _isConnecting = false;
      return;
    }

    _stompClient = StompClient(
      config: StompConfig(
        url: _wsUrl,
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

    // Private per-user order updates: /user/queue/shop-order-updates
    const destination = '/user/queue/shop-order-updates';
    debugPrint(' [WS] Subscribing to: $destination');

    _stompClient?.subscribe(
      destination: destination,
      headers: {...headers, 'receipt': 'rcpt-order-updates'},
      callback: _handleOrderFrame,
    );

    // Public broadcasts: shop open/closed + menu structure changes.
    _stompClient?.subscribe(
      destination: '/topic/shop-profile-updates',
      headers: {...headers, 'receipt': 'rcpt-shop-profile-updates'},
      callback: _handleShopProfileFrame,
    );

    _stompClient?.subscribe(
      destination: '/topic/shop-menu-updates',
      headers: {...headers, 'receipt': 'rcpt-shop-menu-updates'},
      callback: _handleShopMenuFrame,
    );

    // Admin broadcasts/announcements: public USERS topic + private per-user
    // queue (SINGLE_USER). Pops the announcement modal globally on arrival.
    _stompClient?.subscribe(
      destination: '/topic/broadcasts/users',
      headers: {...headers, 'receipt': 'rcpt-broadcasts-users'},
      callback: _handleBroadcastFrame,
    );

    _stompClient?.subscribe(
      destination: '/user/queue/broadcasts',
      headers: {...headers, 'receipt': 'rcpt-broadcasts-user'},
      callback: _handleBroadcastFrame,
    );
  }

  /// Handles `/topic/broadcasts/users` and `/user/queue/broadcasts`
  /// (type: BROADCAST). Builds an [AnnouncementModel] from the live payload and
  /// shows the detail modal regardless of the current screen.
  void _handleBroadcastFrame(StompFrame frame) {
    if (frame.body == null) return;
    try {
      final decoded = json.decode(frame.body!);
      if (decoded is! Map) return;
      final raw = Map<String, dynamic>.from(decoded);
      if (raw['id'] == null) return;
      debugPrint(' 📡 [WS] BROADCAST received: ${raw['title']}');
      final announcement = AnnouncementModel.fromJson(raw);
      AnnouncementPresenter.present(announcement);
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  /// Handles `/topic/shop-profile-updates` (SHOP_PROFILE_UPDATE).
  /// Invalidates the affected shop's cache and forwards the payload so
  /// listeners (e.g. shop detail/list) can refresh open/closed state.
  void _handleShopProfileFrame(StompFrame frame) {
    if (frame.body == null) return;
    try {
      final decoded = json.decode(frame.body!);
      if (decoded is! Map) return;
      final raw = Map<String, dynamic>.from(decoded);
      final id = int.tryParse(raw['shopId']?.toString() ?? '');
      if (id != null) {
        debugPrint(' 📡 [WS] SHOP_PROFILE_UPDATE shopId=$id: $raw');
        RestaurantRepository.instance.clearCache(shopId: id);
        _shopProfileUpdateController.add(raw);
      }
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  /// Handles `/topic/shop-menu-updates` (MENU_UPDATE).
  void _handleShopMenuFrame(StompFrame frame) {
    if (frame.body == null) return;
    try {
      final decoded = json.decode(frame.body!);
      if (decoded is! Map) return;
      final raw = Map<String, dynamic>.from(decoded);
      final id = int.tryParse(raw['shopId']?.toString() ?? '');
      if (id != null) {
        debugPrint(' 📡 [WS] MENU_UPDATE shopId=$id: $raw');
        RestaurantRepository.instance.clearCache(shopId: id);
        _menuUpdateController.add(raw);
      }
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  void _handleOrderFrame(StompFrame frame) {
    {
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
    }
  }

  void disconnect() {
    _stompClient?.deactivate();
    _stompClient = null;
    connectionStatus.value = false;
  }
}
