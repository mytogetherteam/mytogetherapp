import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
import 'models/home_discount_section_dto.dart';

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

  Future<Map<String, dynamic>?> getBackgroundTheme() async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/background-themes',
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        List list = [];
        if (data is Map && data['data'] is List) {
          list = data['data'] as List;
        } else if (data is List) {
          list = data;
        }
        
        if (list.isNotEmpty) {
          // Try to find the first active theme, or fallback to the first theme
          var activeTheme = list.firstWhere(
            (theme) => theme['isActive'] == true,
            orElse: () => list.first,
          );
          return {
            'url': activeTheme['imageUrl']?.toString() ?? activeTheme['image']?.toString(),
            'name': activeTheme['name']?.toString() ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint('getBackgroundTheme error: $e');
      if (e is DioException) {
        debugPrint('Response data: ${e.response?.data}');
        debugPrint('Status code: ${e.response?.statusCode}');
      }
    }
    return null;
  }

  Future<ApiResponseShopDetailDto> getShopById(int id, {double? lat, double? lon}) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/shop-profile/$id',
      );

      if (response.statusCode == 200) {
        final envelope = response.data as Map<String, dynamic>;
        final data = envelope['data'];
        if (data is Map<String, dynamic>) {
          ShopStorage.saveShop(id, data);
          final distanceKm = _distanceKmFromShop(data, lat: lat, lon: lon);
          final detail = ShopDetailDto.fromUserProfileJson(
            data,
            distanceKm: distanceKm,
          );
          return ApiResponseShopDetailDto(
            success: envelope['success'] == true,
            message: envelope['message']?.toString() ?? '',
            data: detail,
            status: response.statusCode ?? 200,
            timestamp: envelope['timestamp']?.toString() ?? '',
          );
        }
      }
      throw Exception('Failed to load shop details: ${response.statusCode}');
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
    return SearchRepository.instance.searchTrendingNearby(
      latitude: lat,
      longitude: lon,
      radiusKm: radiusKm,
      page: page + 1,
      size: size,
    );
  }

  Future<ApiResponseSliceShopFeedItemDto> getShopMenu({
    required int shopId,
    int page = 0,
    int size = 20,
    int? categoryId,
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
          'categoryId': ?categoryId,
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

  /// Shop feed sections built from `GET /api/user/menu-items?shopId=`.
  /// [feedType]: right-now | for-you | hot-deals | trending | popular-dishes
  Future<ShopFeedSectionDto> getShopFeed({
    required int shopId,
    required String feedType,
  }) async {
    if (!AuthService().isLoggedIn) {
      return ShopFeedSectionDto(items: []);
    }

    try {
      final rawItems = await _fetchMenuItemMaps(shopId: shopId, size: 100);
      final filtered = _filterMenuMapsForFeed(rawItems, feedType);
      final maps = filtered.isNotEmpty || feedType == 'right-now'
          ? filtered
          : rawItems.take(12).toList();
      final items = maps
          .map((e) => ShopFeedItemDto.fromJson(flattenMenuItemForFeed(e)))
          .toList();
      return ShopFeedSectionDto(items: items);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return ShopFeedSectionDto(items: []);
      }
      rethrow;
    }
  }

  /// Food-tab feeds via authenticated user menu/search endpoints only.
  /// [feedType]: explore | right-now | for-you | hot-deals | trending | popular-dishes
  Future<ShopFeedSectionDto> getFoodTabFeed({
    required String feedType,
    required double lat,
    required double lon,
    double radiusKm = 10.0,
    int page = 0,
    int size = 20,
  }) async {
    if (feedType == 'explore' || feedType == 'right-now') {
      return getExploreMenuItems(
        lat: lat,
        lon: lon,
        page: page + 1,
        size: size,
      );
    }

    if (feedType == 'trending') {
      final section = await SearchRepository.instance.searchTrendingNearby(
        latitude: lat,
        longitude: lon,
        radiusKm: radiusKm,
        page: page + 1,
        size: size,
      );
      return ShopFeedSectionDto(
        items: section.items.map(ShopFeedItemDto.fromTrendingItem).toList(),
      );
    }

    if (feedType == 'for-you') {
      return getForYouFeed(
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
        page: page + 1,
        size: size,
      );
    }

    if (feedType == 'hot-deals') {
      final deals = await getDiscountDeals(
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
        page: page + 1,
        size: size,
      );
      return ShopFeedSectionDto(items: deals.items);
    }

    if (feedType == 'popular-dishes') {
      final rawItems = await _fetchMenuItemMaps(page: page + 1, size: size);
      final recommended = rawItems
          .where((m) => m['isRecommended'] == true)
          .toList();
      final maps = recommended.isNotEmpty ? recommended : rawItems;
      return ShopFeedSectionDto(
        items: maps
            .map(
              (e) => ShopFeedItemDto.fromJson(
                flattenMenuItemForFeed(e),
                originLat: lat,
                originLon: lon,
              ),
            )
            .toList(),
      );
    }

    return ShopFeedSectionDto(items: const []);
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
            .map(
              (e) => ShopFeedItemDto.fromJson(
                flattenMenuItemForFeed(e),
                originLat: lat,
                originLon: lon,
              ),
            )
            .toList()
        : <ShopFeedItemDto>[];
    return ShopFeedSectionDto(items: items);
  }

  /// "Explore menu" — paginated catalog of published menu items visible to the
  /// user. Backend (auth): GET /api/user/menu-items (UserMenuItemsController.findAll).
  /// Returns `{ data: { content: [...menu items...] } }`.
  /// The catalog endpoint is not geo-aware; [lat]/[lon] are used client-side to
  /// compute distance from each item's nested shop coordinates.
  Future<ShopFeedSectionDto> getExploreMenuItems({
    required double lat,
    required double lon,
    int page = 1,
    int size = 20,
  }) async {
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
            .map(
              (e) => ShopFeedItemDto.fromJson(
                flattenMenuItemForFeed(e),
                originLat: lat,
                originLon: lon,
              ),
            )
            .toList()
        : <ShopFeedItemDto>[];
    return ShopFeedSectionDto(items: items);
  }

  /// Nearby discounted menu items for the home "Together — Up to X% Off" strip.
  /// Backend (auth): GET /api/user/menu-items/discount
  /// (UserMenuItemsController.getDiscountMenuItems). Returns items whose
  /// discount is `<= percentage`, plus the section title and the actual max
  /// discount among results. Location is required via query lat/lon or saved
  /// user location when signed in.
  Future<DiscountDealsDto> getDiscountDeals({
    required double lat,
    required double lon,
    int percentage = 50,
    double? radiusKm,
    int page = 1,
    int size = 10,
    String? sectionTitle,
  }) async {
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
      return DiscountDealsDto.fromJson(
        response.data as Map<String, dynamic>,
        originLat: lat,
        originLon: lon,
      );
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

  /// Admin-controlled home discount carousel config.
  /// Backend (auth): GET /api/user/home-discount-section
  /// (UserHomeDiscountSectionController). Returns all configured sections with
  /// their computed status plus the single `activeSection` (if any). Returns an
  /// empty config on auth errors so the carousel simply hides.
  Future<HomeDiscountSectionListDto> getHomeDiscountSection() async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/home-discount-section',
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return HomeDiscountSectionListDto.fromJson(raw);
      }
      return HomeDiscountSectionListDto.empty;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return HomeDiscountSectionListDto.empty;
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

  /// Master menu categories for search filters via the user popular endpoint.
  /// Backend: `GET /api/user/master-menu-categories/popular`.
  Future<List<MasterCategoryDto>> getMasterCategories() async {
    return getPopularMasterCategories(limit: 100);
  }

  /// Popular master menu categories ranked by completed orders.
  /// Backend (auth): GET /api/user/master-menu-categories/popular.
  Future<List<MasterCategoryDto>> getPopularMasterCategories({
    int limit = 10,
  }) async {
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

  /// Cuisine types for search filters.
  /// Backend (auth): GET /api/user/cuisine-types (UserCuisineController).
  Future<List<CuisineTypeDto>> getCuisineTypes() async {
    if (!AuthService().isLoggedIn) return [];
    try {
      return await SearchRepository.instance.listCuisineTypes();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) return [];
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
    return getUserMenuItemById(id);
  }

  /// Backend (auth): GET /api/user/menu-items/:id
  Future<FoodDetailDto?> getUserMenuItemById(int id) async {
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
        return null;
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
    if (!AuthService().isLoggedIn) return [];

    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/shop/$shopId/reviews',
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
    if (!AuthService().isLoggedIn) {
      throw Exception('Login required for review summary');
    }

    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/shop/$shopId/reviews/summary',
    );
    if (response.statusCode == 200) {
      return ShopReviewSummaryDto.fromJson(response.data);
    }
    throw Exception('Failed to load review summary');
  }

  Future<List<Map<String, dynamic>>> _fetchMenuItemMaps({
    int? shopId,
    int page = 1,
    int size = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/menu-items',
      queryParameters: {
        'page': page,
        'size': size,
        'shopId': ?shopId,
      },
    );
    final raw = response.data;
    final data = raw is Map ? raw['data'] : null;
    final content = data is Map ? data['content'] : null;
    if (content is List) {
      return content.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _filterMenuMapsForFeed(
    List<Map<String, dynamic>> items,
    String feedType,
  ) {
    switch (feedType) {
      case 'hot-deals':
        return items.where((m) => m['isHotDeal'] == true).toList();
      case 'popular-dishes':
      case 'for-you':
        return items.where((m) => m['isRecommended'] == true).toList();
      case 'trending':
        final sorted = List<Map<String, dynamic>>.from(items);
        sorted.sort((a, b) {
          final ar = (a['reviewCount'] as num?)?.toInt() ?? 0;
          final br = (b['reviewCount'] as num?)?.toInt() ?? 0;
          return br.compareTo(ar);
        });
        return sorted;
      case 'right-now':
      default:
        return items;
    }
  }

  double? _distanceKmFromShop(
    Map<String, dynamic> shop, {
    double? lat,
    double? lon,
  }) {
    if (lat == null || lon == null) return null;
    final slat = shop['latitude'];
    final slon = shop['longitude'];
    if (slat == null || slon == null) return null;
    return _haversineKm(
      lat,
      lon,
      (slat as num).toDouble(),
      (slon as num).toDouble(),
    );
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
