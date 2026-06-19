import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Keeps scroll position stable when paginated lists append or remove footers.
class PaginationScroll {
  static const double defaultEndThreshold = 200;

  static bool wasNearEnd(
    ScrollController controller, {
    double threshold = defaultEndThreshold,
  }) {
    if (!controller.hasClients) return false;
    final position = controller.position;
    return position.pixels >= position.maxScrollExtent - threshold;
  }

  /// When the user was near the bottom, re-anchor to the new bottom after the
  /// list height changes so content does not jump upward.
  static void maintainAfterPageAppend(
    ScrollController controller, {
    required bool wasNearEnd,
  }) {
    if (!wasNearEnd || !controller.hasClients) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      controller.jumpTo(controller.position.maxScrollExtent);
    });
  }
}
