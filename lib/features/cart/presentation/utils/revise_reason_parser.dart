import '../../../../core/localization/locale_controller.dart';

/// Parses revise metadata from the backend.
///
/// Preferred source: structured `reviseItems[]` on the order payload.
/// Fallback: combined `reviseReason` string (`"Item A, Item B: reason"`).
class ReviseReasonParser {
  ReviseReasonParser._();

  static ({List<String> names, String? reason}) parseReviseItemsPayload(
    dynamic raw,
  ) {
    if (raw is! List || raw.isEmpty) {
      return (names: const <String>[], reason: null);
    }

    final names = <String>[];
    String? reason;

    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final name = _menuItemNameFromReviseEntry(map);
      if (name.isNotEmpty) names.add(name);

      final entryReason = map['reason']?.toString().trim();
      if (entryReason != null && entryReason.isNotEmpty) {
        reason ??= entryReason;
      }
    }

    return (names: names, reason: reason);
  }

  static String _menuItemNameFromReviseEntry(Map<String, dynamic> entry) {
    final orderItem = entry['orderItem'];
    if (orderItem is Map) {
      final orderItemMap = Map<String, dynamic>.from(orderItem);
      final menuItem = orderItemMap['menuItem'];
      if (menuItem is Map) {
        final menu = Map<String, dynamic>.from(menuItem);
        final localized = LocaleController.instance.localized(
          en: menu['nameEn']?.toString() ?? menu['name']?.toString(),
          mm: menu['nameMm']?.toString(),
          th: menu['nameTh']?.toString(),
        );
        if (localized.isNotEmpty) return localized;
      }
      final fallback = orderItemMap['menuItemName']?.toString() ??
          orderItemMap['name']?.toString();
      if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
    }
    return '';
  }

  /// Resolves unavailable item names and the free-text reason, preferring
  /// structured API fields when present.
  static ({List<String> items, String reason}) resolve({
    String? reviseReason,
    List<String>? structuredItemNames,
    String? structuredItemReason,
  }) {
    final parsed = parse(reviseReason);
    final items = (structuredItemNames != null && structuredItemNames.isNotEmpty)
        ? structuredItemNames
        : parsed.items;

    if (structuredItemReason != null && structuredItemReason.trim().isNotEmpty) {
      return (items: items, reason: structuredItemReason.trim());
    }
    if (parsed.reason.isNotEmpty) {
      return (items: items, reason: parsed.reason);
    }
    return (items: items, reason: reviseReason?.trim() ?? '');
  }

  /// Parses the legacy combined revise reason the shop backend stores as
  /// `"Item A, Item B: <free-text reason>"`.
  static ({List<String> items, String reason}) parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return (items: const <String>[], reason: '');
    }
    final trimmed = raw.trim();
    final sep = trimmed.lastIndexOf(': ');
    if (sep > 0) {
      final itemsPart = trimmed.substring(0, sep);
      final reason = trimmed.substring(sep + 2).trim();
      final items = itemsPart
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (items.isNotEmpty) {
        return (items: items, reason: reason);
      }
    }
    return (items: const <String>[], reason: trimmed);
  }
}
