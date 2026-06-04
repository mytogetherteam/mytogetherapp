import 'package:dio/dio.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import '../models/wishlist_item_dto.dart';

/// Wraps the new backend's `WishlistModule`:
///   POST   /api/user/wishlist                  body: {menuItemId} | {shopId}
///   GET    /api/user/wishlist/menu-items       paginated
///   GET    /api/user/wishlist/shop             paginated
///   DELETE /api/user/wishlist/:id              by wishlist row id
///
/// Since DELETE expects the wishlist row id (not the menuItemId/shopId), we
/// keep an in-memory lookup populated by `create` and `list` responses so
/// the toggle-style favorite buttons in the UI can keep using domain ids.
class WishlistRepository {
  static final WishlistRepository instance = WishlistRepository._();
  WishlistRepository._();

  final ApiClient _apiClient = ApiClient();

  /// menuItemId -> wishlist row id
  final Map<int, int> _menuItemIndex = {};

  /// shopId -> wishlist row id
  final Map<int, int> _shopIndex = {};

  /// Whether `loadAll()` has primed the indexes at least once during this
  /// session. We use this to know if a missing key means "really missing"
  /// or "we haven't loaded yet".
  bool _primed = false;

  bool get isPrimed => _primed;

  /// Returns the cached wishlist id for a menu item (or null if not saved).
  int? wishlistIdForMenuItem(int menuItemId) => _menuItemIndex[menuItemId];

  /// Returns the cached wishlist id for a shop (or null if not saved).
  int? wishlistIdForShop(int shopId) => _shopIndex[shopId];

  bool isMenuItemSaved(int menuItemId) =>
      _menuItemIndex.containsKey(menuItemId);

  bool isShopSaved(int shopId) => _shopIndex.containsKey(shopId);

  /// Pre-loads the entire wishlist into memory. Cheap to call repeatedly
  /// since the backend paginates and the lists are user-scoped.
  Future<void> loadAll({int size = 100}) async {
    try {
      final menuFuture = listMenuItems(size: size);
      final shopFuture = listShops(size: size);
      await Future.wait([menuFuture, shopFuture]);
      _primed = true;
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
    return items;
  }

  /// Adds a menu item to the wishlist. Returns the created row.
  /// Throws on hard failures; the caller decides how to surface them.
  Future<WishlistItemDto?> addMenuItem(int menuItemId) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiClient.apiPrefix}/user/wishlist',
        data: {'menuItemId': menuItemId},
      );
      final created = _parseSingle(response.data);
      if (created != null) {
        _menuItemIndex[menuItemId] = created.id;
      }
      return created;
    } on DioException catch (e) {
      // 409 = already saved. Try to recover by syncing the index.
      if (e.response?.statusCode == 409) {
        await listMenuItems();
        return null;
      }
      rethrow;
    }
  }

  Future<WishlistItemDto?> addShop(int shopId) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiClient.apiPrefix}/user/wishlist',
        data: {'shopId': shopId},
      );
      final created = _parseSingle(response.data);
      if (created != null) {
        _shopIndex[shopId] = created.id;
      }
      return created;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        await listShops();
        return null;
      }
      rethrow;
    }
  }

  /// Removes a wishlist row by its primary key.
  Future<void> removeById(int wishlistId) async {
    await _apiClient.dio.delete(
      '${ApiClient.apiPrefix}/user/wishlist/$wishlistId',
    );
    _menuItemIndex.removeWhere((_, value) => value == wishlistId);
    _shopIndex.removeWhere((_, value) => value == wishlistId);
  }

  /// Convenience helper: removes a menu item from the wishlist by its
  /// `menuItemId`. Looks up the wishlist row id from the cache or, if it
  /// isn't there, refreshes the index and tries again.
  Future<bool> removeMenuItem(int menuItemId) async {
    var wishlistId = _menuItemIndex[menuItemId];
    if (wishlistId == null) {
      await listMenuItems();
      wishlistId = _menuItemIndex[menuItemId];
    }
    if (wishlistId == null) return false;
    await removeById(wishlistId);
    return true;
  }

  Future<bool> removeShop(int shopId) async {
    var wishlistId = _shopIndex[shopId];
    if (wishlistId == null) {
      await listShops();
      wishlistId = _shopIndex[shopId];
    }
    if (wishlistId == null) return false;
    await removeById(wishlistId);
    return true;
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
