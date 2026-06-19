import 'package:intl/intl.dart';

/// Shared 24-hour clock formatting for the app.
class TimeFormatter {
  TimeFormatter._();

  static final DateFormat _clock = DateFormat('HH:mm');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, HH:mm');

  /// Formats [dateTime] as `HH:mm`.
  static String formatClock(DateTime dateTime) => _clock.format(dateTime);

  /// Formats [dateTime] as `dd MMM yyyy, HH:mm`.
  static String formatDateTime(DateTime dateTime) => _dateTime.format(dateTime);

  /// Formats hour/minute as zero-padded `HH:mm`.
  static String formatParts(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Converts embedded 12-hour clock values to 24-hour display.
  ///
  /// Duration strings such as `20-30 min` or `45 mins` are left unchanged.
  static String normalizeDisplay(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return input;
    if (_looksLikeDuration(trimmed)) return input;

    return trimmed.replaceAllMapped(
      RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\b', caseSensitive: false),
      (match) {
        var hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2) ?? '0');
        final period = match.group(3)!.toUpperCase();
        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return formatParts(hour, minute);
      },
    );
  }

  static bool _looksLikeDuration(String value) {
    return RegExp(r'\bmin\b|\bmins\b|\bhour|\bhr\b', caseSensitive: false)
        .hasMatch(value);
  }
}
