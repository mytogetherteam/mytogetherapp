import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mytogetherapp/core/network/websocket_service.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_service.dart';

/// Tracks the customer's unread chat count per order conversation.
///
/// Conversations are keyed by `orderId` on the backend, so the badge shown on
/// an order's chat button reflects how many messages the shop has sent that the
/// customer hasn't opened yet. The count updates live from the shared
/// `/user/queue/chat-updates` stream and is cleared once the thread is opened.
class ChatUnreadController {
  ChatUnreadController._();
  static final ChatUnreadController instance = ChatUnreadController._();

  final Map<int, ValueNotifier<int>> _notifiers = {};
  StreamSubscription<Map<String, dynamic>>? _chatSub;
  bool _started = false;

  /// The unread notifier for [orderId], created lazily on first use.
  ValueNotifier<int> notifierFor(int orderId) =>
      _notifiers.putIfAbsent(orderId, () => ValueNotifier<int>(0));

  /// Subscribes to realtime chat events. Safe to call multiple times.
  void start() {
    if (_started) return;
    _started = true;
    _chatSub = WebSocketService().chatUpdates.listen(_onChatEvent);
  }

  void _onChatEvent(Map<String, dynamic> event) {
    final orderId = (event['orderId'] as num?)?.toInt();
    if (orderId == null) return;

    final type = event['type'] as String?;
    if (type == 'CHAT_CONVERSATION_HIDDEN') {
      _set(orderId, 0);
      return;
    }

    final unread = (event['userUnreadCount'] as num?)?.toInt();
    if (unread != null) {
      _set(orderId, unread);
    }
  }

  void _set(int orderId, int count) {
    notifierFor(orderId).value = count < 0 ? 0 : count;
  }

  /// Fetches the authoritative unread count for [orderId] from the backend.
  Future<void> refreshOrder(int orderId) async {
    final count = await ChatService.instance.getUnreadCountForOrder(orderId);
    if (count != null) {
      _set(orderId, count);
    }
  }

  /// Marks an order's conversation as read locally (badge -> 0).
  void clear(int orderId) => _set(orderId, 0);

  void dispose() {
    _chatSub?.cancel();
    _chatSub = null;
    _started = false;
  }
}
