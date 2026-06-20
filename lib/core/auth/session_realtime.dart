import '../../features/cart/data/active_order_state.dart';
import '../network/websocket_service.dart';

/// Tears down or boots realtime order state when the auth session changes.
class SessionRealtime {
  SessionRealtime._();

  static void teardown() {
    WebSocketService().disconnect();
    ActiveOrderState.instance.resetForUserSession();
  }

  static Future<void> bootstrap() async {
    ActiveOrderState.instance.resetForUserSession();
    await ActiveOrderState.instance.loadFromPrefs();
    await ActiveOrderState.instance.hydrateActiveOrdersFromApi();
    WebSocketService().enableReconnect();
    WebSocketService().connect(force: true);
  }
}
