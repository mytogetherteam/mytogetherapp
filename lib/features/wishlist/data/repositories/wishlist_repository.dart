import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import '../models/wishlist_item_dto.dart';

/// Wraps the new backend's `WishlistModule`:
///   POST   /api/user/wishlist                  body: {menuItemId} | {shopId} | {placeId}
///   GET    /api/user/wishlist/menu-items       paginated
///   GET    /api/user/wishlist/shop             paginated
///   GET    /api/user/wishlist/places           paginated
///   DELETE /api/user/wishlist/:id              by wishlist row id
///
/// Since DELETE expects the wishlist row id (not the menuItemId/shopId), we
/// keep an in-memory lookup populated by `create` and `list` responses so
/// the toggle-style favorite buttons in the UI can keep using domain ids.
class WishlistRepository extends ChangeNotifier {
  static final WishlistRepository instance = WishlistRepository._();
  WishlistRepository._();

  final ApiClient _apiClient = ApiClient();

  /// menuItemId -> wishlist row id
  final Map<int, int> _menuItemIndex = {};

  /// shopId -> wishlist row id
  final Map<int, int> _shopIndex = {};

  /// placeId -> wishlist row id
  final Map<int, int> _placeIndex = {};

  /// Optimistic overrides applied on top of the indexes. They hold the latest
  /// user-intended saved state for an item (true = saved, false = removed) so
  /// every screen that listens to this notifier reflects a toggle instantly and
  /// consistently — even before the network round-trip completes, and even when
  /// the item came from a feed that didn't include `isFavorite`. They take
  /// precedence over the row indexes and are the basis for cross-page sync.
  final Map<int, bool> _menuItemOverride = {};
  final Map<int, bool> _shopOverride = {};
  final Map<int, bool> _placeOverride = {};

  /// Whether `loadAll()` has primed the indexes at least once during this
  /// session. We use this to know if a missing key means "really missing"
  /// or "we haven't loaded yet".
  bool _primed = false;

  bool get isPrimed => _primed;

  /// Returns the cached wishlist id for a menu item (or null if not saved).
  int? wishlistIdForMenuItem(int menuItemId) => _menuItemIndex[menuItemId];

  /// Returns the cached wishlist id for a shop (or null if not saved).
  int? wishlistIdForShop(int shopId) => _shopIndex[shopId];

  int? wishlistIdForPlace(int placeId) => _placeIndex[placeId];

  bool isMenuItemSaved(int menuItemId) =>
      _menuItemOverride[menuItemId] ?? _menuItemIndex.containsKey(menuItemId);

  bool isShopSaved(int shopId) =>
      _shopOverride[shopId] ?? _shopIndex.containsKey(shopId);

  bool isPlaceSaved(int placeId) =>
      _placeOverride[placeId] ?? _placeIndex.containsKey(placeId);

  /// Whether the repository has any authoritative knowledge about an item's
  /// saved state (either a confirmed row or an optimistic override). Callers
  /// use this to decide between trusting the repository or a feed-provided
  /// fallback flag, so freshly loaded items aren't shown as unsaved before the
  /// wishlist is primed.
  bool knowsMenuItem(int menuItemId) =>
      _menuItemOverride.containsKey(menuItemId) ||
      _menuItemIndex.containsKey(menuItemId);

  bool knowsShop(int shopId) =>
      _shopOverride.containsKey(shopId) || _shopIndex.containsKey(shopId);

  bool knowsPlace(int placeId) =>
      _placeOverride.containsKey(placeId) || _placeIndex.containsKey(placeId);

  /// Pre-loads the entire wishlist into memory. Cheap to call repeatedly
  /// since the backend paginates and the lists are user-scoped.
  Future<void> loadAll({int size = 100}) async {
    try {
      await Future.wait([
        listMenuItems(size: size),
        listShops(size: size),
        listPlaces(size: size),
      ]);
      _primed = true;
      notifyListeners();
    } catch (_) {
      // Soft-fail: indexes stay empty, callers degrade gracefully.
    }
  }

  Future<List<WishlistItemDto>> listMenuItems({
    int page = 1,
    int size = 50,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/wishlist/menu-items',
      queryParameters: {'page': page, 'size': size},
    );

    final items = _parseList(response.data);
    for (final item in items) {
      if (item.menuItemId != null) {
        _menuItemIndex[item.menuItemId!] = item.id;
      } else if (item.menuItem != null) {
        _menuItemIndex[item.menuItem!.id] = item.id;
      }
    }
    notifyListeners();
    return items;
  }

  Future<List<WishlistItemDto>> listShops({
    int page = 1,
    int size = 50,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/wishlist/shop',
      queryParameters: {'page': page, 'size': size},
    );

    final items = _parseList(response.data);
    for (final item in items) {
      if (item.shopId != null) {
        _shopIndex[item.shopId!] = item.id;
      } else if (item.shop != null) {
        _shopIndex[item.shop!.id] = item.id;
      }
    }
    notifyListeners();
    return items;
  }

  /// Adds a menu item to the wishlist. Returns the created row.
  /// Throws on hard failures; the caller decides how to surface them.
  Future<WishlistItemDto?> addMenuItem(int menuItemId) async {
    // Optimistic: reflect the saved state everywhere immediately.
    _menuItemOverride[menuItemId] = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.post(
        '${ApiClient.apiPrefix}/user/wishlist',
        data: {'menuItemId': menuItemId},
      );
      final created = _parseSingle(response.data);
      if (created != null) {
        _menuItemIndex[menuItemId] = created.id;
      }
      notifyListeners();
      return created;
    } on DioException catch (e) {
      // 409 = already saved. Recover by syncing the index; stays "saved".
      if (e.response?.statusCode == 409) {
        await listMenuItems();
        notifyListeners();
        return null;
      }
      _menuItemOverride.remove(menuItemId); // rollback
      notifyListeners();
      rethrow;
    } catch (_) {
      _menuItemOverride.remove(menuItemId); // rollback
      notifyListeners();
      rethrow;
    }
  }

  Future<List<WishlistItemDto>> listPlaces({
    int page = 1,
    int size = 50,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/wishlist/places',
      queryParameters: {'page': page, 'size': size},
    );

    final items = _parseList(response.data);
    for (final item in items) {
      if (item.placeId != null) {
        _placeIndex[item.placeId!] = item.id;
      } else if (item.place != null) {
        _placeIndex[item.place!.id] = item.id;
      }
    }
    notifyListeners();
    return items;
  }

  Future<WishlistItemDto?> addShop(int shopId) async {
    _shopOverride[shopId] = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.post(
        '${ApiClient.apiPrefix}/user/wishlist',
        data: {'shopId': shopId},
      );
      final created = _parseSingle(response.data);
      if (created != null) {
        _shopIndex[shopId] = created.id;
      }
      notifyListeners();
      return created;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        await listShops();
        notifyListeners();
        return null;
      }
      _shopOverride.remove(shopId);
      notifyListeners();
      rethrow;
    } catch (_) {
      _shopOverride.remove(shopId);
      notifyListeners();
      rethrow;
    }
  }

  Future<WishlistItemDto?> addPlace(int placeId) async {
    _placeOverride[placeId] = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.post(
        '${ApiClient.apiPrefix}/user/wishlist',
        data: {'placeId': placeId},
      );
      final created = _parseSingle(response.data);
      if (created != null) {
        _placeIndex[placeId] = created.id;
      }
      notifyListeners();
      return created;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        await listPlaces();
        notifyListeners();
        return null;
      }
      _placeOverride.remove(placeId);
      notifyListeners();
      rethrow;
    } catch (_) {
      _placeOverride.remove(placeId);
      notifyListeners();
      rethrow;
    }
  }

  /// Removes a wishlist row by its primary key. Also records an optimistic
  /// "removed" override for the affected domain ids so cards sourced from feeds
  /// (which may still report the item as favorited) reflect the removal.
  Future<void> removeById(int wishlistId) async {
    await _apiClient.dio.delete(
      '${ApiClient.apiPrefix}/user/wishlist/$wishlistId',
    );
    _menuItemIndex.removeWhere((key, value) {
      if (value == wishlistId) {
        _menuItemOverride[key] = false;
        return true;
      }
      return false;
    });
    _shopIndex.removeWhere((key, value) {
      if (value == wishlistId) {
        _shopOverride[key] = false;
        return true;
      }
      return false;
    });
    _placeIndex.removeWhere((key, value) {
      if (value == wishlistId) {
        _placeOverride[key] = false;
        return true;
      }
      return false;
    });
    notifyListeners();
  }

  /// Convenience helper: removes a menu item from the wishlist by its
  /// `menuItemId`. Looks up the wishlist row id from the cache or, if it
  /// isn't there, refreshes the index and tries again.
  Future<bool> removeMenuItem(int menuItemId) async {
    // Optimistic removal first, so the UI updates instantly everywhere.
    _menuItemOverride[menuItemId] = false;
    notifyListeners();
    var wishlistId = _menuItemIndex[menuItemId];
    if (wishlistId == null) {
      await listMenuItems();
      wishlistId = _menuItemIndex[menuItemId];
    }
    if (wishlistId == null) {
      return false;
    }
    try {
      await removeById(wishlistId);
      return true;
    } catch (_) {
      _menuItemOverride.remove(menuItemId); // rollback
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> removeShop(int shopId) async {
    _shopOverride[shopId] = false;
    notifyListeners();
    var wishlistId = _shopIndex[shopId];
    if (wishlistId == null) {
      await listShops();
      wishlistId = _shopIndex[shopId];
    }
    if (wishlistId == null) {
      return false;
    }
    try {
      await removeById(wishlistId);
      return true;
    } catch (_) {
      _shopOverride.remove(shopId);
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> removePlace(int placeId) async {
    _placeOverride[placeId] = false;
    notifyListeners();
    var wishlistId = _placeIndex[placeId];
    if (wishlistId == null) {
      await listPlaces();
      wishlistId = _placeIndex[placeId];
    }
    if (wishlistId == null) {
      return false;
    }
    try {
      await removeById(wishlistId);
      return true;
    } catch (_) {
      _placeOverride.remove(placeId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleMenuItem(int menuItemId, bool save) async {
    if (save) {
      await addMenuItem(menuItemId);
    } else {
      await removeMenuItem(menuItemId);
    }
  }

  Future<void> toggleShop(int shopId, bool save) async {
    if (save) {
      await addShop(shopId);
    } else {
      await removeShop(shopId);
    }
  }

  Future<void> togglePlace(int placeId, bool save) async {
    if (save) {
      await addPlace(placeId);
    } else {
      await removePlace(placeId);
    }
  }

  // ── Parsing helpers ───────────────────────────────────────────────────

  List<WishlistItemDto> _parseList(dynamic body) {
    final raw = body is Map ? body['data'] : body;
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(WishlistItemDto.fromJson)
          .toList();
    }
    return const [];
  }

  WishlistItemDto? _parseSingle(dynamic body) {
    final raw = body is Map ? body['data'] : body;
    if (raw is Map<String, dynamic>) {
      return WishlistItemDto.fromJson(raw);
    }
    return null;
  }
}
