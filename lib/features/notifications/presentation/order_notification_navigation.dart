import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import 'package:mytogetherapp/features/chat/presentation/screens/chat_page.dart';
import 'package:mytogetherapp/features/notifications/data/models/notification_model.dart';
import 'package:mytogetherapp/features/cart/data/active_order_state.dart';
import 'package:mytogetherapp/features/cart/data/cart_manager.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/awaiting_payment_page.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/order_cancel_page.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/order_complete_page.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/order_status_page.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/order_tracking_page.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/revise_order_page.dart';

/// Opens the order-scoped chat thread for a shop message notification.
Future<void> navigateToChatFromNotification(
  BuildContext context,
  NotificationModel notification,
) async {
  final orderId = notification.referenceId;
  if (orderId == null || !context.mounted) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatPage(
        orderId: orderId,
        peerName: _chatPeerName(notification, context),
        peerSubtitle: context.tr('common.restaurant'),
      ),
    ),
  );
}

String _chatPeerName(NotificationModel notification, BuildContext context) {
  const prefix = 'New message from ';
  final title = notification.title.trim();
  if (title.startsWith(prefix)) {
    final name = title.substring(prefix.length).trim();
    if (name.isNotEmpty) return name;
  }

  final body = notification.body;
  final paren = body.indexOf(' (');
  if (paren > 0) {
    final name = body.substring(0, paren).trim();
    if (name.isNotEmpty) return name;
  }

  return context.tr('common.restaurant');
}

/// Loads the tapped order and opens the screen that matches its current stage.
/// Mirrors [ActiveOrderBar] / push-notification routing so in-app notification
/// taps land on the same place as myshop's notification list.
Future<void> navigateToOrderFromNotification(
  BuildContext context,
  int orderId,
) async {
  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CustomLoadingIndicator(size: 40)),
  );

  final state = ActiveOrderState.instance;
  final id = orderId.toString();
  await state.adoptOrderIfOwned(id);
  state.focusOrder(id);

  if (context.mounted) {
    Navigator.pop(context);
  }
  if (!context.mounted) return;

  final order = state.getOrder(id);
  if (order == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('notification.order_not_found'))),
    );
    return;
  }

  if (order.isRevised) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviseOrderPage(orderId: order.orderId),
      ),
    );
    return;
  }

  final s = order.orderStatus;
  if (s == -1) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderCancelPage(
          orderId: order.orderId,
          reason: order.cancelReason,
          shopId: order.shopId,
          shopName: order.shopNameEn ??
              order.shopName ??
              order.restaurantName ??
              order.storeName,
          shopNameMm: order.shopNameMm,
          shopNameTh: order.shopNameTh,
          shopLogo: order.shopLogo ?? order.logoPath,
          shopImageUrl: order.shopImageUrl,
          cancelledByUser: state.wasCancelledByUser(order.orderId),
        ),
      ),
    );
    return;
  }

  if (s == 2) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderStatusPage(
          foodTotal: order.resolvedItemSubtotal,
          deliveryFee: order.deliveryFee ?? 0,
        ),
      ),
    );
    return;
  }

  if (s == 1) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AwaitingPaymentPage(
          orderId: order.orderId,
          foodTotal: order.resolvedItemSubtotal,
          deliveryFee: order.deliveryFee ?? 0,
        ),
      ),
    );
    return;
  }

  if (s == 3 || s == 0) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingPage(
          store: CartStore(
            nameKey: order.shopNameEn ?? order.storeName ?? '',
            nameEn: order.shopNameEn ?? order.storeName,
            nameMm: order.shopNameMm,
            nameTh: order.shopNameTh,
            items: order.orderItems,
          ),
          foodTotal: order.resolvedItemSubtotal.round(),
        ),
      ),
    );
    return;
  }

  if (s == 4 && !OrderCompletePage.isCurrentlyVisible) {
    OrderCompletePage.navigateTo(context);
  }
}
