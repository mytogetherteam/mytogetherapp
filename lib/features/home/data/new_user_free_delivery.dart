import 'package:flutter/foundation.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/network/api_client.dart';

/// Platform offer: a signed-in customer's first delivery order has no delivery fee.
/// Guests can see the short promo line. They are not given the free fee.
class NewUserFreeDeliveryOffer extends ChangeNotifier {
  NewUserFreeDeliveryOffer._();
  static final NewUserFreeDeliveryOffer instance = NewUserFreeDeliveryOffer._();

  bool enabled = false;
  bool eligible = false;

  /// Fee is actually free for this signed-in account.
  bool get applies => enabled && eligible && AuthService().isLoggedIn;

  /// Promo line for guests and for accounts that still qualify.
  bool get showBanner =>
      enabled && (!AuthService().isLoggedIn || eligible);

  Future<void> refresh() async {
    final previousApplies = applies;
    final previousBanner = showBanner;
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/free-delivery/new-user',
      );
      final body = response.data;
      final data = body is Map && body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : (body is Map ? Map<String, dynamic>.from(body) : null);
      enabled = data?['enabled'] == true;
      eligible = data?['eligible'] == true;
    } catch (_) {
      // Keep the last known offer when the request fails.
    }
    if (applies != previousApplies || showBanner != previousBanner) {
      notifyListeners();
    }
  }
}
