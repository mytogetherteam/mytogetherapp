import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/localization/app_translations.dart';
import '../data/active_order_state.dart';
import 'screens/awaiting_payment_page.dart';
import 'screens/order_cancel_page.dart';
import 'screens/revise_order_page.dart';
import 'widgets/order_action_dialog.dart';

/// Pops a localized action modal when the shop requests a new payment slip or
/// marks items unavailable, regardless of which screen the user is on.
///
/// Mirrors [AnnouncementPresenter]: uses the global navigator key, dedupes per
/// order+action episode, and never stacks dialogs.
class OrderActionPresenter {
  OrderActionPresenter._();

  static bool _started = false;
  static bool _isShowing = false;
  static final Set<String> _shownEpisodeKeys = <String>{};

  static void start() {
    if (_started) return;
    _started = true;
    ActiveOrderState.instance.addListener(_evaluateAllOrders);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateAllOrders());
  }

  static void stop() {
    if (!_started) return;
    _started = false;
    ActiveOrderState.instance.removeListener(_evaluateAllOrders);
  }

  static void _evaluateAllOrders() {
    if (!AuthService().isLoggedIn) return;

    for (final order in ActiveOrderState.instance.allOrdersList) {
      _evaluateOrder(order);
    }
  }

  static void _evaluateOrder(ActiveOrderItem order) {
    final slipEpisode = '${order.orderId}:SLIP';
    final reviseEpisode = '${order.orderId}:REVISED';
    final shopCancelEpisode = '${order.orderId}:SHOP_CANCEL';

    if (order.orderStatus == -1) {
      if (!ActiveOrderState.instance.wasCancelledByUser(order.orderId) &&
          !_shownEpisodeKeys.contains(shopCancelEpisode) &&
          !OrderCancelPage.isCurrentlyVisible) {
        unawaited(_presentShopCancelled(order, shopCancelEpisode));
      }
      return;
    }
    _shownEpisodeKeys.remove(shopCancelEpisode);

    final needsSlip = order.isSlipRequested &&
        order.orderStatus == 1 &&
        !order.isPaymentChecking;
    final needsRevise = order.isRevised && order.orderStatus == 0;

    if (!needsSlip) _shownEpisodeKeys.remove(slipEpisode);
    if (!needsRevise) _shownEpisodeKeys.remove(reviseEpisode);

    if (needsSlip && !_shownEpisodeKeys.contains(slipEpisode) && !_suppressSlipModal()) {
      unawaited(_present(
        kind: OrderActionDialogKind.slipReupload,
        order: order,
        episodeKey: slipEpisode,
      ));
      return;
    }

    if (needsRevise &&
        !_shownEpisodeKeys.contains(reviseEpisode) &&
        !_suppressReviseModal()) {
      unawaited(_present(
        kind: OrderActionDialogKind.unavailableItems,
        order: order,
        episodeKey: reviseEpisode,
      ));
    }
  }

  static bool _suppressSlipModal() =>
      AwaitingPaymentPage.isCurrentlyVisible;

  static bool _suppressReviseModal() =>
      ReviseOrderPage.isCurrentlyVisible ||
      (AwaitingPaymentPage.isCurrentlyVisible &&
          ActiveOrderState.instance.activeOrdersList.any((o) => o.isRevised));

  static Future<void> _presentShopCancelled(
    ActiveOrderItem order,
    String episodeKey,
  ) async {
    if (_isShowing || _shownEpisodeKeys.contains(episodeKey)) return;

    final nav = App.navigatorKey.currentState;
    if (nav == null) return;

    _isShowing = true;
    _shownEpisodeKeys.add(episodeKey);
    try {
      final route = MaterialPageRoute(
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
        ),
      );

      if (AwaitingPaymentPage.isCurrentlyVisible) {
        await nav.pushReplacement(route);
      } else {
        await nav.push(route);
      }
    } finally {
      _isShowing = false;
    }
  }

  static Future<void> _present({
    required OrderActionDialogKind kind,
    required ActiveOrderItem order,
    required String episodeKey,
  }) async {
    if (_isShowing || _shownEpisodeKeys.contains(episodeKey)) return;

    final context = App.navigatorKey.currentContext;
    if (context == null) return;

    _isShowing = true;
    _shownEpisodeKeys.add(episodeKey);
    try {
      final result = await OrderActionDialog.show(
        context,
        kind: kind,
        order: order,
      );
      if (result == null || result == OrderActionDialogResult.later) return;

      final navContext = App.navigatorKey.currentContext;
      final nav = App.navigatorKey.currentState;
      if (navContext == null || !navContext.mounted || nav == null) return;

      switch (result) {
        case OrderActionDialogResult.uploadSlip:
          _openAwaitingPayment(navContext, order);
        case OrderActionDialogResult.reviewOrder:
          nav.push(
            MaterialPageRoute(
              builder: (_) => ReviseOrderPage(orderId: order.orderId),
            ),
          );
        case OrderActionDialogResult.cancelOrder:
          await _confirmAndCancel(navContext, order);
        case OrderActionDialogResult.later:
          break;
      }
    } finally {
      _isShowing = false;
    }
  }

  static void _openAwaitingPayment(BuildContext context, ActiveOrderItem order) {
    final deliveryFee = order.deliveryFee ?? 0;
    final foodTotal = order.resolvedItemSubtotal;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AwaitingPaymentPage(
          orderId: order.orderId,
          foodTotal: foodTotal > 0 ? foodTotal : 0,
          deliveryFee: deliveryFee,
        ),
      ),
    );
  }

  static Future<void> _confirmAndCancel(
    BuildContext context,
    ActiveOrderItem order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          ctx.tr('order_action.cancel_confirm_title'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          ctx.tr('order_action.cancel_confirm_message'),
          style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              ctx.tr('order_action.keep_order'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ctx.tr('order_action.revise_cancel'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ActiveOrderState.instance.cancelActiveOrder(
      orderId: order.orderId,
    );

    final afterContext = App.navigatorKey.currentContext;
    if (afterContext == null || !afterContext.mounted || !success) return;

    Navigator.of(afterContext).pushReplacement(
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
          cancelledByUser: true,
        ),
      ),
    );
  }
}
