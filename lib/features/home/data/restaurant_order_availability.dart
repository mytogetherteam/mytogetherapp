import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'models/shop_dto.dart' show OperatingHourDto;
import 'restaurant_data.dart';
import '../presentation/widgets/restaurant_open_status.dart'
    show RestaurantOpenStatus;

/// Why a customer cannot place a delivery order right now.
enum OrderBlockReason { none, deliveryDisabled, closed }

/// Unified order eligibility for a shop, combining the merchant's delivery
/// toggle with live operating-hours computation.
class RestaurantOrderAvailability {
  final OrderBlockReason reason;
  final bool deliveryEnabled;
  final OpeningStatus openingStatus;
  final List<OperatingHourDto> operatingHours;
  final String statusFallback;

  const RestaurantOrderAvailability({
    required this.reason,
    required this.deliveryEnabled,
    required this.openingStatus,
    this.operatingHours = const [],
    this.statusFallback = 'Open',
  });

  bool get canOrder => reason == OrderBlockReason.none;
  bool get isBlocked => !canOrder;
  /// Gray image dim is shown only when the shop is closed — not for delivery-off.
  bool get shouldDimImage => reason == OrderBlockReason.closed;

  static RestaurantOrderAvailability of(Restaurant restaurant) {
    return fromParts(
      deliveryEnabled: restaurant.deliveryEnabled,
      operatingHours: restaurant.operatingHours,
      status: restaurant.status,
    );
  }

  static RestaurantOrderAvailability fromParts({
    required bool deliveryEnabled,
    required List<OperatingHourDto> operatingHours,
    required String status,
  }) {
    final opening = OpeningStatus.fromHours(operatingHours);

    final isOpen = opening.hasSchedule
        ? opening.isOpen
        : status.trim().toLowerCase() == 'open';

    // Closed hours take precedence over delivery toggle when both block ordering.
    if (!isOpen) {
      return RestaurantOrderAvailability(
        reason: OrderBlockReason.closed,
        deliveryEnabled: deliveryEnabled,
        openingStatus: opening,
        operatingHours: operatingHours,
        statusFallback: status,
      );
    }

    if (!deliveryEnabled) {
      return RestaurantOrderAvailability(
        reason: OrderBlockReason.deliveryDisabled,
        deliveryEnabled: false,
        openingStatus: opening,
        operatingHours: operatingHours,
        statusFallback: status,
      );
    }

    return RestaurantOrderAvailability(
      reason: OrderBlockReason.none,
      deliveryEnabled: true,
      openingStatus: opening,
      operatingHours: operatingHours,
      statusFallback: status,
    );
  }

  Restaurant _presentationRestaurant() {
    return Restaurant(
      id: '',
      name: '',
      category: '',
      rating: 0,
      distance: '',
      imagePath: '',
      logoPath: '',
      deliveryTime: '',
      status: statusFallback,
      operatingHours: operatingHours,
    );
  }

  /// Compact status for list cards (e.g. "Closed · Opens today at 8:00").
  String cardStatusLine(BuildContext context) {
    switch (reason) {
      case OrderBlockReason.none:
        return '';
      case OrderBlockReason.deliveryDisabled:
        return context.tr('order.delivery_unavailable');
      case OrderBlockReason.closed:
        final openStatus = RestaurantOpenStatus.of(
          context,
          _presentationRestaurant(),
        );
        final next = openStatus.nextOpenText;
        if (next != null && next.isNotEmpty) {
          return context.trArgs('order.card_closed_opens', {'opens': next});
        }
        return context.tr('common.closed');
    }
  }

  /// One-line hint under menu item cards on home/food feeds.
  String menuCardHintLine(BuildContext context) {
    if (!isBlocked) return '';
    switch (reason) {
      case OrderBlockReason.deliveryDisabled:
        return context.tr('order.delivery_unavailable');
      case OrderBlockReason.closed:
        final openStatus = RestaurantOpenStatus.of(
          context,
          _presentationRestaurant(),
        );
        final next = openStatus.nextOpenText;
        if (next != null && next.isNotEmpty) {
          return context.trArgs('order.card_closed_opens', {'opens': next});
        }
        return context.tr('common.closed');
      case OrderBlockReason.none:
        return '';
    }
  }

  /// Grab-style strip above the restaurant info card.
  String statusStripText(BuildContext context) {
    switch (reason) {
      case OrderBlockReason.none:
        return '';
      case OrderBlockReason.deliveryDisabled:
        return context.tr('order.status_strip_delivery');
      case OrderBlockReason.closed:
        final openStatus = RestaurantOpenStatus.of(
          context,
          _presentationRestaurant(),
        );
        final next = openStatus.nextOpenText;
        if (next != null && next.isNotEmpty) {
          return context.trArgs('order.status_strip_closed', {'opens': next});
        }
        return context.tr('order.status_strip_closed_short');
    }
  }

  /// Banner on the restaurant detail header card.
  String restaurantBannerText(BuildContext context) =>
      statusStripText(context);

  /// Banner on the menu item detail page (distinct copy / tone).
  String menuItemBannerText(BuildContext context) {
    switch (reason) {
      case OrderBlockReason.none:
        return '';
      case OrderBlockReason.deliveryDisabled:
        return context.tr('order.menu_item_delivery_banner');
      case OrderBlockReason.closed:
        final line = cardStatusLine(context);
        return line.isNotEmpty
            ? line
            : context.tr('order.menu_item_closed_banner');
    }
  }

  String bottomSheetTitle(BuildContext context) {
    switch (reason) {
      case OrderBlockReason.none:
        return '';
      case OrderBlockReason.deliveryDisabled:
        return context.tr('order.delivery_unavailable_sheet_title');
      case OrderBlockReason.closed:
        return context.tr('order.closed_sheet_title');
    }
  }

  String bottomSheetBody(BuildContext context) {
    switch (reason) {
      case OrderBlockReason.none:
        return '';
      case OrderBlockReason.deliveryDisabled:
        return context.tr('order.delivery_unavailable_sheet_body');
      case OrderBlockReason.closed:
        return context.tr('order.closed_sheet_body');
    }
  }

  /// Small grey hint above the menu when ordering is blocked.
  String menuBrowseHint(BuildContext context) {
    switch (reason) {
      case OrderBlockReason.none:
        return '';
      case OrderBlockReason.deliveryDisabled:
        return context.tr('order.menu_browse_hint_delivery');
      case OrderBlockReason.closed:
        return context.tr('order.menu_browse_hint_closed');
    }
  }

}
