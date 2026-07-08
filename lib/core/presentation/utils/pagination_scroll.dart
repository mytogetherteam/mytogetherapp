import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Keeps scroll position stable when paginated lists append or remove footers.
class PaginationScroll {
  static const double defaultEndThreshold = 200;

  /// Explore Menu and other nested slivers prefetch earlier than list pages.
  static const double exploreEndThreshold = 400;

  /// Restaurant detail menu loads the next slice before the user hits the end.
  static const double menuEndThreshold = 500;

  /// Returns how many items can remain below [lastVisibleIndex] before the
  /// next page should be prefetched. For page size 10 this is 4 (6 of 10 seen).
  static int prefetchRemainingForPageSize(int pageSize) {
    return (pageSize * 0.4).ceil().clamp(2, pageSize - 1);
  }

  /// True when [lastVisibleIndex] is far enough into [totalItemCount] that the
  /// next page should load (roughly 60% of the current batch visible).
  static bool shouldPrefetchByItemIndex({
    required int lastVisibleIndex,
    required int totalItemCount,
    required int pageSize,
  }) {
    if (totalItemCount <= 0 || lastVisibleIndex < 0) return false;
    if (lastVisibleIndex >= totalItemCount) return false;
    final remainingBelow = totalItemCount - 1 - lastVisibleIndex;
    return remainingBelow <= prefetchRemainingForPageSize(pageSize);
  }

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
    ScrollController? controller, {
    required bool wasNearEnd,
  }) {
    if (!wasNearEnd || controller == null || !controller.hasClients) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      controller.jumpTo(controller.position.maxScrollExtent);
    });
  }
}
