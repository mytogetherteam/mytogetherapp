import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../network/websocket_service.dart';
import '../../features/cart/data/active_order_state.dart';
import '../../features/announcements/data/repositories/announcement_repository.dart';
import '../../features/notifications/data/repositories/notification_repository.dart';

class LifecycleObserver extends StatefulWidget {
  final Widget child;

  const LifecycleObserver({super.key, required this.child});

  @override
  State<LifecycleObserver> createState() => _LifecycleObserverState();
}

class _LifecycleObserverState extends State<LifecycleObserver> with WidgetsBindingObserver {
  bool _isProcessingForeground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On web, switching browser tabs/windows fires inactive/paused even though
    // the app is still "running". Disconnecting here drops the STOMP subscription
    // and menu/order broadcasts are missed while the shop-admin tab is focused.
    if (kIsWeb) {
      if (state == AppLifecycleState.resumed &&
          !WebSocketService().isConnected) {
        WebSocketService().connect(force: true);
      }
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      WebSocketService().disconnect();
    } else if (state == AppLifecycleState.resumed) {
      _handleForegroundResumed();
    }
  }

  Future<void> _handleForegroundResumed() async {
    if (_isProcessingForeground) return;
    _isProcessingForeground = true;

    try {
      // 1. SYNC: Always pull server truth via HTTP first
      // This is the "unbreakable" part — FCM might have been missed,
      // so we catch up here before resuming live stream.
      await ActiveOrderState.instance.syncActiveOrder();

      // Catch up on counts that may have changed while backgrounded (a push
      // could have been missed), so the badges are accurate on resume.
      NotificationRepository().getUnreadCount();
      AnnouncementRepository().getUnreadCount();

      // 2. RECONNECT: After sync, safe to listen for new events
      WebSocketService().connect();
    } catch (_) {
      // Fail-safe: trigger a background sync attempt later if critical
    } finally {
      _isProcessingForeground = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
