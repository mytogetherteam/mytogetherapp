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

  static const int _completeScheduleDays = 7;

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

    final operatingHours = existing?.operatingHours ?? const [];
    rememberParts(
      shopId,
      deliveryEnabled: deliveryEnabled,
      operatingHours: operatingHours,
      status: _statusFromHoursOrFallback(operatingHours, status),
    );
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
    final mergedHours = _pickRicherOperatingHours(
      existing?.operatingHours ?? const [],
      operatingHours,
    );
    final mergedDelivery = !deliveryEnabled
        ? false
        : (existing?.deliveryEnabled ?? deliveryEnabled);
    final mergedStatus = _statusFromHoursOrFallback(
      mergedHours,
      status.isNotEmpty ? status : (existing?.status ?? 'Open'),
    );

    _entries[shopId] = _ShopOrderEntry(
      deliveryEnabled: mergedDelivery,
      operatingHours: mergedHours,
      status: mergedStatus,
    );
    notifyListeners();
  }

  /// Replaces cached order state with a fresh API snapshot (no merge).
  /// Use when polling `GET /api/user/shop-profile/:id` without WebSocket.
  void replaceParts(
    int shopId, {
    required bool deliveryEnabled,
    required List<OperatingHourDto> operatingHours,
    required String status,
  }) {
    if (shopId <= 0) return;
    _entries[shopId] = _ShopOrderEntry(
      deliveryEnabled: deliveryEnabled,
      operatingHours: operatingHours,
      status: _statusFromHoursOrFallback(operatingHours, status),
    );
    notifyListeners();
  }

  bool hasCompleteOperatingHours(int shopId) {
    final hours = _entries[shopId]?.operatingHours ?? const [];
    return hours.length >= _completeScheduleDays;
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
    final mergedHours = _pickRicherOperatingHours(
      entry?.operatingHours ?? const [],
      operatingHours,
    );
    final mergedDelivery = entry?.deliveryEnabled ?? deliveryEnabled;
    final mergedStatus = _statusFromHoursOrFallback(
      mergedHours,
      entry?.status ?? status,
    );

    return RestaurantOrderAvailability.fromParts(
      deliveryEnabled: mergedDelivery,
      operatingHours: mergedHours,
      status: mergedStatus,
    );
  }

  static List<OperatingHourDto> _pickRicherOperatingHours(
    List<OperatingHourDto> existing,
    List<OperatingHourDto> incoming,
  ) {
    if (existing.isEmpty) return incoming;
    if (incoming.isEmpty) return existing;
    return existing.length >= incoming.length ? existing : incoming;
  }

  static String _statusFromHoursOrFallback(
    List<OperatingHourDto> hours,
    String fallback,
  ) {
    final opening = OpeningStatus.fromHours(hours);
    if (opening.hasSchedule) {
      return opening.isOpen ? 'Open' : 'Closed';
    }
    return fallback;
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
