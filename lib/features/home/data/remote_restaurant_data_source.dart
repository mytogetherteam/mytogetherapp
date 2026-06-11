import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/features/search/data/search_repository.dart';
import 'package:mytogetherapp/features/wishlist/data/repositories/wishlist_repository.dart';
import '../../../../core/auth/auth_service.dart';
import 'models/banner_image_dto.dart';
import 'models/shop_dto.dart';
import 'models/trending_item_dto.dart';
import 'models/shop_feed_item_dto.dart';
import 'models/food_detail_dto.dart';
import 'models/shop_review_dto.dart';
import 'models/master_category_dto.dart';
import 'models/menu_category_dto.dart';
import 'models/collection_dto.dart';

import 'shop_storage.dart';

class RemoteRestaurantDataSource {
  final ApiClient _apiClient = ApiClient();

  /// Backend (auth): GET /api/user/banners?position=Ads|Promotions
  Future<List<BannerImageDto>> getBanners({String? position}) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/banners',
        queryParameters: position != null ? {'position': position} : null,
      );

      if (response.statusCode == 200) {
        final raw = response.data;
        final List<dynamic> data = raw is Map
            ? (raw['data'] as List<dynamic>? ?? const [])
            : (raw is List ? raw : const []);
        return data
            .whereType<Map<String, dynamic>>()
            .map(BannerImageDto.fromJson)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<ApiResponseSliceShopListDto> getNearbyShops(ShopRequestDto request) async {
    try {
      // Backend (public): GET /api/shops/nearby (PublicController.getNearbyShops).
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/shops/nearby',
        queryParameters: request.toJson(),
      );
      
      if (response.statusCode == 200) {
        return ApiResponseSliceShopListDto.fromJson(response.data);
      } else {
        throw Exception('Failed to load nearby shops: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<ApiResponseShopDetailDto> getShopById(int id, {double? lat, double? lon}) async {
    try {
      // Backend (public): GET /api/shops/:id (PublicController.getShopById).
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/shops/$id',
        queryParameters: {
          'lat': ?lat,
          'lon': ?lon,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['data'] != null) {
          // Save to local storage for future use (e.g. payment types in order summary)
          ShopStorage.saveShop(id, data['data'] as Map<String, dynamic>);
        }
        return ApiResponseShopDetailDto.fromJson(data);
      } else {
        throw Exception('Failed to load shop details: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Active payment methods for a shop, used in the order/checkout flow.
  /// Backend (auth): `GET /api/user/shops/:shopId/payment-methods`
  /// (`UserShopPaymentMethodsController`). Returns `{ success, data: [...] }`
  /// where each row is a `shopPaymentMethod` with its `paymentMethod` relation.
  Future<List<ShopPaymentTypeDto>> getShopPaymentMethods(int shopId) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/shops/$shopId/payment-methods',
    );
    final raw = response.data;
    final List<dynamic> data = raw is Map
        ? (raw['data'] as List<dynamic>? ?? const [])
        : (raw is List ? raw : const []);
    return data
        .whereType<Map<String, dynamic>>()
        .map(ShopPaymentTypeDto.fromUserApiJson)
        .toList();
  }

  Future<TrendingSectionDto> getTrendingItems({
    required double lat,
    required double lon,
    double radiusKm = 10.0,
    int page = 0,
    int size = 20,
  }) async {
    // Backend (public): GET /api/feed/trending-items
    // (PublicController.getTrendingItems). It returns the trending payload
    // directly (not wrapped in `data`).
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/feed/trending-items',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'radiusKm': radiusKm,
        'page': page,
        'size': size,
      },
    );
    final raw = response.data;
    final data = raw is Map && raw['data'] is Map
        ? raw['data'] as Map<String, dynamic>
        : raw as Map<String, dynamic>;
    return TrendingSectionDto.fromJson(data);
  }

  Future<ApiResponseSliceShopFeedItemDto> getShopMenu({
    required int shopId,
    int page = 0,
    int size = 20,
  }) async {
    try {
      // Backend (auth): GET /api/user/menu-items?shopId=...&page=...&size=...
      // (UserMenuItemsController.findAll). Returns a paginated envelope:
      // { success, data: [...], meta: { page, size, total, ... } }.
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/menu-items',
        queryParameters: {
          'shopId': shopId,
          'page': page + 1, // API uses 1-based index
          'size': size,
        },
        options: Options(
          extra: {
            '@dio_cache_interceptor@': CacheOptions(
              store: MemCacheStore(),
              policy: CachePolicy.refresh,
            ),
          },
        ),
      );
      if (response.statusCode == 200) {
        return ApiResponseSliceShopFeedItemDto.fromJson(response.data);
      } else {
        throw Exception('Failed to load shop menu: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches one of the 5 shop feed types.
  /// [feedType] must be one of: right-now, for-you, hot-deals, trending, popular-dishes
  Future<ShopFeedSectionDto> getShopFeed({
    required int shopId,
    required String feedType,
  }) async {
    if (!AuthService().isLoggedIn) {
      return ShopFeedSectionDto(items: []);
    }

    try {
      // Backend (public): GET /api/shops/:id/feed/:feedType
      // (PublicController.getShopFeed). No auth required.
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/shops/$shopId/feed/$feedType',
      );
      // Explicitly throw on non-2xx so FutureBuilder snapshot.hasError = true
      if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
        throw Exception('Feed request failed: ${response.statusCode} for $feedType');
      }
      return ShopFeedSectionDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return ShopFeedSectionDto(items: []);
      }
      rethrow;
    }
  }

  /// Fetches one of the 5 food tab feed types.
  /// [feedType] must be one of: right-now, for-you, hot-deals, trending, popular-dishes
  Future<ShopFeedSectionDto> getFoodTabFeed({
    required String feedType,
    required double lat,
    required double lon,
    double radiusKm = 10.0,
    int page = 0,
    int size = 20,
  }) async {
    if (!AuthService().isLoggedIn) {
      return ShopFeedSectionDto(items: []);
    }

    // "Explore menu" uses the authenticated paginated catalog endpoint
    // (GET /api/user/menu-items) instead of the public right-now feed.
    if (feedType == 'explore') {
      try {
        final explore = await getExploreMenuItems(
          page: page + 1, // user endpoint is 1-based
          size: size,
        );
        if (explore.items.isNotEmpty) return explore;
        // On a "load more" page, an empty result means the catalog is
        // exhausted. Return it so pagination terminates instead of falling
        // through to the public feed, which would keep returning items and
        // loop forever. The fall-through only makes sense for the first page.
        if (page > 0) return explore;
      } catch (_) {
        // Fall through to the public feed below.
      }
    }

    // Trending nearby uses the authenticated meal-type-aware user search endpoint.
    // Fall back to the public feed when empty or on error.
    if (feedType == 'trending') {
      try {
        final section = await SearchRepository.instance.searchTrendingNearby(
          latitude: lat,
          longitude: lon,
          radiusKm: radiusKm,
          page: page + 1,
          size: size,
        );
        if (section.items.isNotEmpty) {
          return ShopFeedSectionDto(
            items: section.items.map(ShopFeedItemDto.fromTrendingItem).toList(),
          );
        }
        // End of the paginated list: stop instead of looping the public feed.
        if (page > 0) return ShopFeedSectionDto(items: const []);
      } catch (_) {
        // Fall through to the public feed below.
      }
    }

    // Personalized "for-you" uses the authenticated, location-aware endpoint.
    // Fall back to the public feed if it's empty (e.g. no order history) or errors.
    if (feedType == 'for-you') {
      try {
        final personalized = await getForYouFeed(
          lat: lat,
          lon: lon,
          radiusKm: radiusKm,
          page: page + 1, // user endpoint is 1-based
          size: size,
        );
        if (personalized.items.isNotEmpty) return personalized;
        // End of the paginated list: stop instead of looping the public feed.
        if (page > 0) return personalized;
      } catch (_) {
        // Fall through to the public feed below.
      }
    }

    // The public feed has no "explore" type; fall back to the latest items.
    final publicFeedType = feedType == 'explore' ? 'right-now' : feedType;

    try {
      // Backend (public): GET /api/menu/feed/:feedType
      // (PublicController.getMenuFeed). Latitude/longitude are not used by
      // the backend yet but are forwarded for future compatibility.
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/menu/feed/$publicFeedType',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'radiusKm': radiusKm,
          'page': page,
          'size': size,
        },
      );
      if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
        throw Exception('Feed request failed: ${response.statusCode} for $feedType');
      }
      return ShopFeedSectionDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return ShopFeedSectionDto(items: []);
      }
      rethrow;
    }
  }

  /// Personalized "For You" menu items for the current user.
  /// Backend (auth): GET /api/user/menu-items/for-you (UserMenuItemsController.forYou).
  /// Returns `{ data: { content: [...menu items...] } }`. Requires location.
  /// Returns an empty section when the user has no order history yet.
  Future<ShopFeedSectionDto> getForYouFeed({
    required double lat,
    required double lon,
    double? radiusKm,
    int page = 1,
    int size = 20,
  }) async {
    if (!AuthService().isLoggedIn) {
      return ShopFeedSectionDto(items: []);
    }
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/menu-items/for-you',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'radiusKm': ?radiusKm,
        'page': page,
        'size': size,
      },
    );
    final raw = response.data;
    final data = raw is Map ? raw['data'] : null;
    final content = data is Map ? data['content'] : null;
    final items = content is List
        ? content
            .whereType<Map<String, dynamic>>()
            .map((e) => ShopFeedItemDto.fromJson(flattenMenuItemForFeed(e)))
            .toList()
        : <ShopFeedItemDto>[];
    return ShopFeedSectionDto(items: items);
  }

  /// "Explore menu" — paginated catalog of published menu items visible to the
  /// user. Backend (auth): GET /api/user/menu-items (UserMenuItemsController.findAll).
  /// Returns `{ data: { content: [...menu items...] } }`.
  Future<ShopFeedSectionDto> getExploreMenuItems({
    int page = 1,
    int size = 20,
  }) async {
    if (!AuthService().isLoggedIn) {
      return ShopFeedSectionDto(items: []);
    }
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/menu-items',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
    final raw = response.data;
    final data = raw is Map ? raw['data'] : null;
    final content = data is Map ? data['content'] : null;
    final items = content is List
        ? content
            .whereType<Map<String, dynamic>>()
            .map((e) => ShopFeedItemDto.fromJson(flattenMenuItemForFeed(e)))
            .toList()
        : <ShopFeedItemDto>[];
    return ShopFeedSectionDto(items: items);
  }

  /// Nearby discounted menu items for the home "Together — Up to X% Off" strip.
  /// Backend (auth): GET /api/user/menu-items/discount
  /// (UserMenuItemsController.getDiscountMenuItems). Returns items whose
  /// discount is `<= percentage`, plus the section title and the actual max
  /// discount among results. Requires login and a location.
  Future<DiscountDealsDto> getDiscountDeals({
    required double lat,
    required double lon,
    int percentage = 50,
    double? radiusKm,
    int page = 1,
    int size = 10,
    String? sectionTitle,
  }) async {
    if (!AuthService().isLoggedIn) {
      return DiscountDealsDto(
        sectionTitle: '',
        maxDiscountPercentage: 0,
        items: const [],
      );
    }
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/menu-items/discount',
        queryParameters: {
          'percentage': percentage,
          'latitude': lat,
          'longitude': lon,
          'radiusKm': ?radiusKm,
          'page': page,
          'size': size,
          'sectionTitle': ?sectionTitle,
        },
      );
      return DiscountDealsDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return DiscountDealsDto(
          sectionTitle: '',
          maxDiscountPercentage: 0,
          items: const [],
        );
      }
      rethrow;
    }
  }

  /// A shop's published menu categories, ordered by displayOrder.
  /// Backend (auth): GET /api/user/menu-categories?shopId=...
  /// (UserMenuCategoriesController.findAll). Used to group the menu on the
  /// restaurant detail page. Returns an empty list for guests.
  Future<List<MenuCategoryDto>> getMenuCategories({
    required int shopId,
    int page = 1,
    int size = 100,
    String? search,
  }) async {
    if (!AuthService().isLoggedIn) return [];
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/menu-categories',
        queryParameters: {
          'shopId': shopId,
          'page': page,
          'size': size,
          'search': ?search,
        },
      );
      final raw = response.data;
      final data = raw is Map ? raw['data'] : null;
      final content = data is Map ? data['content'] : null;
      if (content is List) {
        return content
            .whereType<Map<String, dynamic>>()
            .map(MenuCategoryDto.fromJson)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) return [];
      rethrow;
    }
  }

  /// Full master menu category catalog for search filters.
  /// Backend (public): GET /api/menu/master/categories (MasterController).
  Future<List<MasterCategoryDto>> getMasterCategories() async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/menu/master/categories',
      );
      final raw = response.data;
      final list = raw is Map ? (raw['data'] ?? raw['content']) : raw;
      if (list is List) {
        final categories = list
            .whereType<Map<String, dynamic>>()
            .map(MasterCategoryDto.fromJson)
            .where((c) => c.id > 0 && c.isActive)
            .toList();
        categories.sort(
          (a, b) => (a.displayOrder ?? 999).compareTo(b.displayOrder ?? 999),
        );
        return categories;
      }
      return [];
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403 || code == 404) return [];
      rethrow;
    }
  }

  /// Popular master menu categories ranked by completed orders.
  /// Backend (auth): GET /api/user/master-menu-categories/popular.
  Future<List<MasterCategoryDto>> getPopularMasterCategories({
    int limit = 10,
  }) async {
    if (!AuthService().isLoggedIn) return [];
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/master-menu-categories/popular',
        queryParameters: {'limit': limit},
      );
      final raw = response.data;
      final list = raw is Map ? raw['data'] : raw;
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(MasterCategoryDto.fromJson)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) return [];
      rethrow;
    }
  }

  /// Cuisine types available for filtering search results.
  /// Backend (public): GET /api/master/cuisine-types (MasterController).
  /// The response is wrapped by the global TransformInterceptor as
  /// `{ data: [...] }`. Returns an empty list when the endpoint is unavailable.
  Future<List<CuisineTypeDto>> getCuisineTypes() async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/master/cuisine-types',
      );
      final raw = response.data;
      final list = raw is Map ? (raw['data'] ?? raw['content']) : raw;
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(CuisineTypeDto.fromJson)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403 || code == 404) return [];
      rethrow;
    }
  }

  /// Curated collections (paginated). Backend (auth): GET /api/user/collections.
  Future<List<CollectionDto>> getCollections({
    int page = 1,
    int size = 20,
    String? search,
  }) async {
    if (!AuthService().isLoggedIn) return [];
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/collections',
        queryParameters: {
          'page': page,
          'size': size,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final raw = response.data;
      final list = raw is Map ? raw['data'] : raw;
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(CollectionDto.fromJson)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) return [];
      rethrow;
    }
  }

  /// One collection with its menu items. Backend (auth): GET /api/user/collections/:id.
  Future<CollectionDto?> getCollectionById(int id) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/collections/$id',
    );
    final raw = response.data;
    final data = raw is Map ? raw['data'] : raw;
    if (data is Map<String, dynamic>) {
      return CollectionDto.fromJson(data);
    }
    return null;
  }

  Future<FoodDetailDto?> getFoodById(int id) async {
    try {
      // Backend (public): GET /api/foods/:id (PublicController.getFoodById).
      final response = await _apiClient.dio.get('${ApiClient.apiPrefix}/foods/$id');
      if (response.statusCode == 200) {
        final apiResponse = ApiResponseFoodDetailDto.fromJson(response.data);
        return apiResponse.data;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Backend (auth): GET /api/user/menu-items/:id
  /// (UserMenuItemsController.findOne). Returns a published menu item with
  /// the current user's favorite state. Falls back to the public food
  /// endpoint when the user is not logged in.
  Future<FoodDetailDto?> getUserMenuItemById(int id) async {
    if (!AuthService().isLoggedIn) {
      return getFoodById(id);
    }
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/menu-items/$id',
      );
      if (response.statusCode == 200) {
        final apiResponse = ApiResponseFoodDetailDto.fromJson(response.data);
        return apiResponse.data;
      }
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return getFoodById(id);
      }
      rethrow;
    }
  }

  // ── Favorites (wishlist) ─────────────────────────────────────────────────
  // The new backend exposes wishlist endpoints under /api/user/wishlist.
  // We keep the legacy add/remove method names so callers stay unchanged,
  // but route everything through WishlistRepository which handles the
  // wishlist-id ↔ shop/menu-item id translation needed for DELETE.

  Future<void> addShopFavorite(int shopId) async {
    try {
      await WishlistRepository.instance.addShop(shopId);
    } catch (_) {}
  }

  Future<void> removeShopFavorite(int shopId) async {
    try {
      await WishlistRepository.instance.removeShop(shopId);
    } catch (_) {}
  }

  Future<void> addMenuFavorite(int menuItemId) async {
    try {
      await WishlistRepository.instance.addMenuItem(menuItemId);
    } catch (_) {}
  }

  Future<void> removeMenuFavorite(int menuItemId) async {
    try {
      await WishlistRepository.instance.removeMenuItem(menuItemId);
    } catch (_) {}
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Future<List<ShopReviewDto>> getShopReviews(int shopId) async {
    // Preferred (auth): GET /api/user/shop/:id/reviews
    // (UserReviewsController.findAllForShop) — visible shops only, paginated
    // envelope: { success, data: { content: [...], totalElements, ... } }.
    if (AuthService().isLoggedIn) {
      try {
        final response = await _apiClient.dio.get(
          '${ApiClient.apiPrefix}/user/shop/$shopId/reviews',
        );
        if (response.statusCode == 200) {
          return _parseReviewList(response.data);
        }
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        // Fall back to the public endpoint for auth issues; rethrow otherwise.
        if (code != 401 && code != 403) rethrow;
      }
    }

    // Fallback (public): GET /api/shops/:id/reviews. Envelope: { success, data: [...] }.
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/shops/$shopId/reviews',
    );
    if (response.statusCode == 200) {
      return _parseReviewList(response.data);
    }
    return [];
  }

  /// Extracts a review list from either the public (flat `data` list) or the
  /// authed user (`data.content`) response envelope.
  List<ShopReviewDto> _parseReviewList(dynamic raw) {
    dynamic list;
    if (raw is Map) {
      final data = raw['data'];
      if (data is List) {
        list = data;
      } else if (data is Map && data['content'] is List) {
        list = data['content'];
      } else if (raw['content'] is List) {
        list = raw['content'];
      }
    } else if (raw is List) {
      list = raw;
    }
    if (list is List) {
      return list
          .whereType<Map<String, dynamic>>()
          .map(ShopReviewDto.fromJson)
          .toList();
    }
    return const [];
  }

  Future<ShopReviewSummaryDto> getShopReviewSummary(int shopId) async {
    // Preferred (auth): GET /api/user/shop/:id/reviews/summary
    // (UserReviewsController.getShopSummary). Envelope: { success, data: {...} }.
    if (AuthService().isLoggedIn) {
      try {
        final response = await _apiClient.dio.get(
          '${ApiClient.apiPrefix}/user/shop/$shopId/reviews/summary',
        );
        if (response.statusCode == 200) {
          return ShopReviewSummaryDto.fromJson(response.data);
        }
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code != 401 && code != 403) rethrow;
      }
    }

    // Fallback (public): GET /api/shops/:id/reviews/summary.
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/shops/$shopId/reviews/summary',
    );
    if (response.statusCode == 200) {
      return ShopReviewSummaryDto.fromJson(response.data);
    }
    throw Exception('Failed to load review summary');
  }
}
