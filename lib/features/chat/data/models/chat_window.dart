class ChatWindow {
  static const duration = Duration(hours: 4);

  static bool isCompletedStatus(String? status) {
    final value = status?.toUpperCase();
    return value == 'DELIVERED' || value == 'PICKED_UP' || value == 'COMPLETED';
  }

  static DateTime? closesAt(String? status, DateTime? completedAt) {
    if (!isCompletedStatus(status) || completedAt == null) return null;
    return completedAt.add(duration);
  }

  static Duration? remaining(String? status, DateTime? completedAt) {
    final deadline = closesAt(status, completedAt);
    if (deadline == null) return null;
    final value = deadline.difference(DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  static bool isWritable(String? status, DateTime? completedAt) {
    final value = status?.toUpperCase();
    if (value == 'CANCELED' || value == 'CANCELLED') return false;
    if (!isCompletedStatus(value)) return true;

    // The backend remains authoritative when older responses omit updatedAt.
    final timeLeft = remaining(value, completedAt);
    return timeLeft == null || timeLeft > Duration.zero;
  }

  /// Time left until [deadline], or null when there is no deadline or it has
  /// already passed. Callers localize it via `context.countdown(...)`.
  static Duration? timeLeftUntil(DateTime? deadline) {
    if (deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    return remaining <= Duration.zero ? null : remaining;
  }
}
