import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../analytics/app_stay_reporter.dart';
import '../localization/locale_controller.dart';
import '../../features/cart/presentation/order_action_presenter.dart';
import '../network/websocket_service.dart';
import '../../features/cart/data/active_order_state.dart';
import '../../features/announcements/data/repositories/announcement_repository.dart';
import '../../features/notifications/data/repositories/notification_repository.dart';
import '../../features/chat/data/services/chat_unread_controller.dart';
import '../../features/call/data/call_session.dart';

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
    AppStayReporter.markForeground();
    OrderActionPresenter.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppStayReporter.markForeground();
      unawaited(LocaleController.instance.refreshLanguagePolicy());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(AppStayReporter.reportAndReset());
    }

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

    // Keep STOMP WebSocket connected while a call is active/ringing or during
    // transient `inactive` states (e.g. permission dialogs, CallKit overlays).
    if (state == AppLifecycleState.paused) {
      if (CallSession().state.value == CallState.idle) {
        WebSocketService().disconnect();
      }
    } else if (state == AppLifecycleState.resumed) {
      _handleForegroundResumed();
    }
  }

  Future<void> _handleForegroundResumed() async {
    if (_isProcessingForeground) return;
    _isProcessingForeground = true;

    try {
      // Reconnect WebSocket immediately so incoming call/order signaling isn't delayed by HTTP syncs
      WebSocketService().connect();

      // 1. SYNC: Always pull server truth via HTTP
      if (ActiveOrderState.instance.hasActiveOrder) {
        await ActiveOrderState.instance.syncActiveOrder();
      } else {
        await ActiveOrderState.instance.hydrateActiveOrdersFromApi();
      }

      // Re-check whether a slip re-upload or item revision needs a global modal
      // after catching up on missed WebSocket events while backgrounded.
      OrderActionPresenter.start();

      // Catch up on counts that may have changed while backgrounded (a push
      // could have been missed), so the badges are accurate on resume.
      NotificationRepository().getUnreadCount();
      AnnouncementRepository().getUnreadCount();
      
      final activeOrderIdStr = ActiveOrderState.instance.orderId?.replaceAll('#', '');
      final activeOrderId = activeOrderIdStr != null ? int.tryParse(activeOrderIdStr) : null;
      if (activeOrderId != null) {
        ChatUnreadController.instance.refreshOrder(activeOrderId);
      }
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
