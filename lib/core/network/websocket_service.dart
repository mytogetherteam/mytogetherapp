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
    // --- MOCK WEBSOCKET CONNECTION ---
    debugPrint(' [WS] WebSocket service disabled for mock environment.');
    connectionStatus.value = true;
  }

  void onConnect(dynamic frame) {
    // No-op for mock mode
  }

  void disconnect() {
    _stompClient?.deactivate();
    _stompClient = null;
    connectionStatus.value = false;
  }
}
