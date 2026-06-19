import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/network/websocket_service.dart';
import 'models/shop_dto.dart' show OperatingHourDto;
import 'restaurant_data.dart';
import 'restaurant_order_availability.dart';

/// In-memory shop order state shared across cards and detail pages.
///
/// Populated whenever a shop is fetched and patched in real time from
/// `SHOP_PROFILE_UPDATE` WebSocket events (`deliveryEnabled` / `isOpen`).
class ShopOrderStateCache extends ChangeNotifier {
  ShopOrderStateCache._();
  static final ShopOrderStateCache instance = ShopOrderStateCache._();

  final Map<int, _ShopOrderEntry> _entries = {};
  final Set<int> _unavailableSheetShown = {};
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  bool _listening = false;

  void ensureListening() {
    if (_listening) return;
    _listening = true;
    _wsSub = WebSocketService().shopProfileUpdates.listen(_onProfileUpdate);
  }

  void _onProfileUpdate(Map<String, dynamic> event) {
    final shopId = int.tryParse(event['shopId']?.toString() ?? '');
    if (shopId == null) return;

    final existing = _entries[shopId];
    var deliveryEnabled = existing?.deliveryEnabled ?? true;
    var status = existing?.status ?? 'Open';

    if (event.containsKey('deliveryEnabled')) {
      deliveryEnabled = event['deliveryEnabled'] == true;
    }
    if (event.containsKey('isOpen')) {
      status = event['isOpen'] == true ? 'Open' : 'Closed';
    }

    _entries[shopId] = _ShopOrderEntry(
      deliveryEnabled: deliveryEnabled,
      operatingHours: existing?.operatingHours ?? const [],
      status: status,
    );
    notifyListeners();
  }

  void remember(Restaurant restaurant) {
    rememberParts(
      int.tryParse(restaurant.id) ?? 0,
      deliveryEnabled: restaurant.deliveryEnabled,
      operatingHours: restaurant.operatingHours,
      status: restaurant.status,
    );
  }

  void rememberParts(
    int shopId, {
    required bool deliveryEnabled,
    required List<OperatingHourDto> operatingHours,
    required String status,
  }) {
    if (shopId <= 0) return;
    final existing = _entries[shopId];
    _entries[shopId] = _ShopOrderEntry(
      deliveryEnabled: deliveryEnabled,
      operatingHours: operatingHours.isNotEmpty
          ? operatingHours
          : (existing?.operatingHours ?? const []),
      status: status,
    );
    notifyListeners();
  }

  bool hasShownUnavailableSheet(int shopId) =>
      _unavailableSheetShown.contains(shopId);

  void markUnavailableSheetShown(int shopId) {
    if (shopId <= 0) return;
    _unavailableSheetShown.add(shopId);
  }

  RestaurantOrderAvailability availabilityForShopIdOrDefault(
    int shopId, {
    bool deliveryEnabled = true,
    List<OperatingHourDto> operatingHours = const [],
    String status = 'Open',
  }) {
    final entry = _entries[shopId];
    final mergedHours = entry != null && entry.operatingHours.isNotEmpty
        ? entry.operatingHours
        : operatingHours;
    final mergedDelivery = entry?.deliveryEnabled ?? deliveryEnabled;
    final mergedStatus = entry != null &&
            (entry.operatingHours.isNotEmpty || !entry.deliveryEnabled)
        ? entry.status
        : status;

    return RestaurantOrderAvailability.fromParts(
      deliveryEnabled: mergedDelivery,
      operatingHours: mergedHours,
      status: mergedStatus,
    );
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

class _ShopOrderEntry {
  final bool deliveryEnabled;
  final List<OperatingHourDto> operatingHours;
  final String status;

  const _ShopOrderEntry({
    required this.deliveryEnabled,
    required this.operatingHours,
    required this.status,
  });
}
