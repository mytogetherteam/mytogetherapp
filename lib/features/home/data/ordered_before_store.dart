import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/network/api_client.dart';

/// Shop ids the signed-in user has finished an order from.
/// Restaurant cards listen to this and show "Ordered before".
class OrderedBeforeStore extends ChangeNotifier {
  static final OrderedBeforeStore instance = OrderedBeforeStore._();
  OrderedBeforeStore._();

  final Set<int> _shopIds = {};
  int? _loadedForUserId;
  int? _loadingForUserId;

  bool contains(int shopId) => _shopIds.contains(shopId);

  /// Loads once per signed-in user. Guests stay empty.
  void ensureLoaded() {
    final userId = AuthService().isLoggedIn
        ? AuthService().currentUser?.id
        : null;
    if (userId == null) {
      if (_shopIds.isNotEmpty || _loadedForUserId != null) {
        _shopIds.clear();
        _loadedForUserId = null;
        _loadingForUserId = null;
        notifyListeners();
      }
      return;
    }
    if (_loadedForUserId == userId || _loadingForUserId == userId) return;
    _loadingForUserId = userId;
    _load(userId);
  }

  /// A just-finished order should label that restaurant immediately.
  void remember(int shopId) {
    if (shopId <= 0) return;
    if (_shopIds.add(shopId)) notifyListeners();
  }

  Future<void> _load(int userId) async {
    final knownBefore = Set<int>.from(_shopIds);
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/orders/ordered-shops',
        options: Options(
          extra: {
            '@dio_cache_interceptor@': CacheOptions(
              store: MemCacheStore(),
              policy: CachePolicy.noCache,
            ),
          },
        ),
      );
      if (AuthService().currentUser?.id != userId) return;
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final raw = data is Map ? data['shopIds'] : null;
      final arrivedDuringLoad = _shopIds.difference(knownBefore);
      _shopIds
        ..clear()
        ..addAll(
          raw is List
              ? raw.map((id) => int.tryParse(id.toString()) ?? 0).where((id) => id > 0)
              : const <int>[],
        )
        ..addAll(arrivedDuringLoad);
      _loadedForUserId = userId;
      notifyListeners();
    } catch (_) {
      if (AuthService().currentUser?.id == userId) {
        _loadedForUserId = null;
      }
    } finally {
      if (_loadingForUserId == userId) _loadingForUserId = null;
    }
  }
}
