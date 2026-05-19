import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import '../network/websocket_service.dart';
import '../../features/cart/data/active_order_state.dart';

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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // On Web, we don't want to disconnect just because the tab lost focus briefly
      if (!kIsWeb) {
        WebSocketService().disconnect();
      }
    } else if (state == AppLifecycleState.resumed) {
      // 2. Foreground: Robust Sync then Reconnect
      _handleForegroundResumed();
    }
  }

  Future<void> _handleForegroundResumed() async {
    if (_isProcessingForeground) return;
    _isProcessingForeground = true;

    try {
      // Run sync and WebSocket reconnect in PARALLEL instead of sequentially.
      // The old sequential approach blocked WS reconnect behind a potentially
      // slow HTTP sync, adding seconds of delay on app resume.
      await Future.wait([
        ActiveOrderState.instance.syncActiveOrder()
            .timeout(const Duration(seconds: 5), onTimeout: () {}),
        Future(() => WebSocketService().connect()),
      ]);
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
