import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/utils/time_formatter.dart';
import '../../data/restaurant_data.dart';

/// Localized, presentation-ready open/closed state for a [Restaurant].
///
/// Prefers the live computation from `operatingHours`; when no schedule is
/// available it falls back to the API-provided `status` flag so behavior never
/// regresses for shops without hours configured.
class RestaurantOpenStatus {
  /// Localized status word ("Open" / "Closed").
  final String text;
  final Color color;

  /// Localized "Opens …" hint shown when the shop is currently closed.
  final String? nextOpenText;

  const RestaurantOpenStatus({
    required this.text,
    required this.color,
    this.nextOpenText,
  });

  bool get isClosed => nextOpenText != null || color == closedColor;

  static const Color openColor = Color(0xFF10B981);
  static const Color closedColor = Color(0xFFEF4444);

  static RestaurantOpenStatus of(BuildContext context, Restaurant restaurant) {
    final status = restaurant.openingStatus;

    if (!status.hasSchedule) {
      final isOpen = restaurant.status.trim().toLowerCase() == 'open';
      return RestaurantOpenStatus(
        text: context.localizedStatus(restaurant.status),
        color: isOpen ? openColor : closedColor,
      );
    }

    if (status.isOpen) {
      return RestaurantOpenStatus(
        text: context.tr('common.open'),
        color: openColor,
      );
    }

    String? next;
    if (status.nextOpenHour != null) {
      final time = TimeFormatter.formatParts(
        status.nextOpenHour!,
        status.nextOpenMinute ?? 0,
      );
      if (status.nextOpenIsToday) {
        next = context.trArgs('restaurant.opens_today', {'time': time});
      } else {
        final day = _dayName(context, status.nextOpenDayIso ?? 0);
        next = context.trArgs('restaurant.opens_on', {'day': day, 'time': time});
      }
    }
    return RestaurantOpenStatus(
      text: context.tr('common.closed'),
      color: closedColor,
      nextOpenText: next,
    );
  }

  static String _dayName(BuildContext context, int iso) {
    switch (iso) {
      case 1:
        return context.tr('common.day_monday');
      case 2:
        return context.tr('common.day_tuesday');
      case 3:
        return context.tr('common.day_wednesday');
      case 4:
        return context.tr('common.day_thursday');
      case 5:
        return context.tr('common.day_friday');
      case 6:
        return context.tr('common.day_saturday');
      case 7:
        return context.tr('common.day_sunday');
      default:
        return '';
    }
  }
}
