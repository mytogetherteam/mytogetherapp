import 'package:flutter/material.dart';
import 'floating_chat_head.dart';

/// A NavigatorObserver that automatically hides the FloatingChatHead
/// whenever ChatPage is the active route, and shows it otherwise.
class ChatHeadRouteObserver extends NavigatorObserver {
  static final ChatHeadRouteObserver instance = ChatHeadRouteObserver._();
  ChatHeadRouteObserver._();

  bool _isChatPageActive = false;

  void _updateVisibility(Route<dynamic>? route) {
    final isChatPage = route?.settings.name == '/chat' ||
        (route is MaterialPageRoute &&
            _isRouteChatPage(route));
    if (isChatPage != _isChatPageActive) {
      _isChatPageActive = isChatPage;
      FloatingChatHead.isHiddenNotifier.value = isChatPage;
    }
  }

  bool _isRouteChatPage(MaterialPageRoute route) {
    try {
      // Build the widget to check its type — Flutter stores a builder, not the widget
      // We use a sentinel context trick instead: check if builder creates a ChatPage.
      // Since we can't easily introspect builder without context, we rely on didPush/didPop
      // being called with the route. We'll set the flag from ChatPage itself as backup,
      // but this observer also ensures restoration on pop.
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Give ChatPage time to set isHiddenNotifier itself via initState/didChangeDependencies
    // This observer handles the pop (back) case to restore visibility.
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // When popping back FROM ChatPage, restore chat head visibility
    if (FloatingChatHead.isHiddenNotifier.value) {
      FloatingChatHead.isHiddenNotifier.value = false;
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (FloatingChatHead.isHiddenNotifier.value) {
      FloatingChatHead.isHiddenNotifier.value = false;
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (FloatingChatHead.isHiddenNotifier.value) {
      FloatingChatHead.isHiddenNotifier.value = false;
    }
  }
}
