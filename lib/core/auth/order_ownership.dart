import 'auth_service.dart';

/// Guards order realtime payloads so one account never adopts another user's order.
class OrderOwnership {
  OrderOwnership._();

  static int? get currentUserId => AuthService().currentUser?.id;

  static int? parseUserId(Map<String, dynamic> data) {
    final raw = data['userId'] ?? data['user_id'];
    if (raw == null && data['user'] is Map) {
      final user = Map<String, dynamic>.from(data['user'] as Map);
      final nested = user['id'] ?? user['userId'];
      if (nested != null) return int.tryParse(nested.toString());
    }
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  /// True when [data] is explicitly owned by the signed-in user.
  static bool isOwnedByCurrentUser(Map<String, dynamic> data) {
    final ownerId = parseUserId(data);
    final current = currentUserId;
    if (ownerId == null || current == null) return false;
    return ownerId == current;
  }

  /// True when [data] belongs to another user (owner id present and mismatched).
  static bool isForeignOrder(Map<String, dynamic> data) {
    final ownerId = parseUserId(data);
    final current = currentUserId;
    if (ownerId == null || current == null) return false;
    return ownerId != current;
  }
}
