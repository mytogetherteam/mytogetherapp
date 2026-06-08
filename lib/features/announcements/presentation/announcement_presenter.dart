import '../../../app.dart';
import '../data/models/announcement_model.dart';
import '../data/repositories/announcement_repository.dart';
import 'widgets/announcement_detail_sheet.dart';

/// Shows the announcement detail modal from anywhere in the app (no matter
/// which screen is on top) using the global navigator key, and keeps the
/// unread badge in sync.
///
/// A new broadcast can reach the device over two channels at once (live STOMP
/// while connected, plus an FCM push). We dedupe by broadcast id so a single
/// announcement only pops once and only bumps the badge once.
class AnnouncementPresenter {
  AnnouncementPresenter._();

  static final Set<int> _autoShownIds = <int>{};
  static bool _isShowing = false;

  /// Present an announcement.
  ///
  /// [isNewArrival] is `true` when the broadcast just arrived in the
  /// foreground (live socket / foreground push): the badge is bumped and the
  /// modal pops automatically. Pass `false` when the user explicitly opened a
  /// background notification — we only reconcile the server count and show the
  /// modal without double-counting.
  static Future<void> present(
    AnnouncementModel announcement, {
    bool isNewArrival = true,
  }) async {
    final repo = AnnouncementRepository();

    if (isNewArrival) {
      if (_autoShownIds.contains(announcement.id)) {
        // Already delivered via the other channel; just keep the count honest.
        repo.getUnreadCount();
        return;
      }
      _autoShownIds.add(announcement.id);
      if (!announcement.isRead) repo.increment();
    }

    // Reconcile with server truth regardless of channel.
    repo.getUnreadCount();

    // Avoid stacking dialogs on top of each other.
    if (_isShowing) return;

    final context = App.navigatorKey.currentContext;
    if (context == null) return;

    _isShowing = true;
    try {
      await AnnouncementDetailSheet.show(context, announcement);
    } finally {
      _isShowing = false;
    }
  }
}
