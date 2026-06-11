import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../auth/auth_service.dart';
import '../config/env_config.dart';
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
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  /// STOMP-over-WebSocket endpoint exposed by NestJS at `/ws/websocket`
  /// (see `src/modules/events/events.gateway.ts`). Mirrors [EnvConfig.wsUrl].
  static String get _wsUrl => EnvConfig.wsUrl;

  void connect({bool force = false}) {
    if (_isConnecting && !force) return;
    if (isConnected && !force) return;

    // We've decided to (re)connect — re-enable auto-reconnect and cancel any
    // pending retry so a stale timer can't tear down the fresh connection.
    _shouldReconnect = true;
    _reconnectTimer?.cancel();

    if (_stompClient != null) {
      // Re-create the client unless it's already connected and the caller
      // isn't forcing. A stale (disconnected) client must not be silently
      // re-activated, otherwise reconnects fail without any signal.
      if (force || !isConnected) {
        debugPrint(' [WS] Re-creating STOMP client...');
        try {
          _stompClient?.deactivate();
        } catch (_) {}
        _stompClient = null;
        // deactivate() above may have fired onDisconnect → _scheduleReconnect;
        // drop that timer since we're about to connect immediately.
        _reconnectTimer?.cancel();
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
          _scheduleReconnect();
        },
        onWebSocketDone: () {
          debugPrint(' 🔌 [WS] WebSocket Connection Closed.');
          _isConnecting = false;
          connectionStatus.value = false;
          _scheduleReconnect();
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
          _scheduleReconnect();
        },
        heartbeatOutgoing: const Duration(milliseconds: 10000),
        heartbeatIncoming: const Duration(milliseconds: 10000),
        reconnectDelay: const Duration(seconds: 3),
      ),
    );

    _stompClient?.activate();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(' 🚫 [WS] Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    debugPrint(
      ' 🔄 [WS] Scheduling reconnection in ${delay.inSeconds}s '
      '(attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => connect(force: true));
  }

  void onConnect(dynamic frame) {
    debugPrint(' [WS]   Connected!');
    _isConnecting = false;
    _reconnectAttempts = 0;
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
    final body = _stompBody(frame);
    if (body == null) return;
    try {
      final decoded = json.decode(body);
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
    final body = _stompBody(frame);
    if (body == null) return;
    try {
      final decoded = json.decode(body);
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

  String? _stompBody(StompFrame frame) {
    final raw = frame.body;
    if (raw == null || raw.isEmpty) return null;
    return raw.replaceAll('\u0000', '').trim();
  }

  /// Handles `/topic/shop-menu-updates` (MENU_UPDATE).
  void _handleShopMenuFrame(StompFrame frame) {
    final body = _stompBody(frame);
    if (body == null) return;
    try {
      final decoded = json.decode(body);
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
      final body = _stompBody(frame);
      if (body == null) return;

      try {
        final decoded = json.decode(body);
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
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _stompClient?.deactivate();
    _stompClient = null;
    connectionStatus.value = false;
  }

  /// Re-enable auto-reconnect after a manual [disconnect] (e.g. on re-login).
  void enableReconnect() {
    _shouldReconnect = true;
    _reconnectAttempts = 0;
  }
}
