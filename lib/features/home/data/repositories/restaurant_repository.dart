import 'dart:math' as math;

import '../restaurant_data.dart';
import '../models/banner_image_dto.dart';
import '../models/trending_item_dto.dart';
import '../models/shop_feed_item_dto.dart';
import '../remote_restaurant_data_source.dart';
import '../models/shop_dto.dart';
import '../models/food_detail_dto.dart';
import '../models/shop_review_dto.dart';
import '../models/master_category_dto.dart';
import '../models/menu_category_dto.dart';
import '../models/collection_dto.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/features/search/data/search_repository.dart';
import 'package:mytogetherapp/features/search/data/models/search_shop_dto.dart';
import 'package:mytogetherapp/features/search/data/models/search_filters.dart';

class RestaurantRepository {
  static final RestaurantRepository instance = RestaurantRepository(
    RemoteRestaurantDataSource(),
  );

  final RemoteRestaurantDataSource _remoteDataSource;

  // Simple cache for nearby shops
  List<Restaurant>? _cachedNearbyShops;
  String? _lastCacheKey;
  DateTime? _lastFetchTime;

  // Cache for trending items
  TrendingSectionDto? _cachedTrending;
  DateTime? _trendingLastFetch;

  // Cache for banners
  final Map<String, List<BannerImageDto>> _cachedBanners = {};
  DateTime? _bannersLastFetch;

  // Cache for shop feed sections: key = "shopId-feedType"
  final Map<String, ShopFeedSectionDto> _feedCache = {};
  final Map<String, DateTime> _feedCacheTime = {};

  // Cache for the home discount carousel
  DiscountDealsDto? _cachedDiscountDeals;
  DateTime? _discountDealsLastFetch;

  RestaurantRepository(this._remoteDataSource);

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  Future<List<BannerImageDto>> getBanners({String? position}) async {
    final cacheKey = position ?? 'all';
    final now = DateTime.now();

    if (_cachedBanners.containsKey(cacheKey) &&
        _bannersLastFetch != null &&
        now.difference(_bannersLastFetch!).inMinutes < 10) {
      return _cachedBanners[cacheKey]!;
    }

    try {
      final banners = await _remoteDataSource.getBanners(position: position);
      _cachedBanners[cacheKey] = banners;
      _bannersLastFetch = now;
      return banners;
    } catch (e) {
      if (_cachedBanners.containsKey(cacheKey)) {
        return _cachedBanners[cacheKey]!;
      }
      rethrow;
    }
  }

  Future<List<Restaurant>> getNearbyShops({
    required double lat,
    required double lon,
    double radius = 5.0,
    int page = 0,
    int size = 20,
    String? search,
  }) async {
    // Generate a unique key for this request
    final cacheKey = '$lat-$lon-$radius-$page-$size-$search';
    final now = DateTime.now();

    // If we have cached data for the SAME request and it's less than 30 seconds old, return it
    if (_cachedNearbyShops != null &&
        _lastCacheKey == cacheKey &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inSeconds < 30) {
      return _cachedNearbyShops!;
    }

    try {
      List<Restaurant> results;

      if (AuthService().isLoggedIn) {
        final SearchPageResult response;
        final hasSearch = search != null && search.trim().isNotEmpty;
        if (hasSearch) {
          response = await SearchRepository.instance.searchShops(
            latitude: lat,
            longitude: lon,
            search: search,
            radiusKm: radius,
            page: page + 1,
            size: size,
          );
        } else {
          response = await SearchRepository.instance.searchNearby(
            latitude: lat,
            longitude: lon,
            radiusKm: radius,
            page: page + 1,
            size: size,
          );
        }
        results = response.shops
            .map((dto) => _mapShopDtoToDomain(dto.shop))
            .toList();
      } else {
        final request = ShopRequestDto(
          lat: lat,
          lon: lon,
          radius: radius,
          page: page,
          size: size,
          search: search,
        );
        final response = await _remoteDataSource.getNearbyShops(request);
        results = response.data.content
            .map((dto) => _mapShopDtoToDomain(dto))
            .toList();
      }

      // Update cache
      _cachedNearbyShops = results;
      _lastCacheKey = cacheKey;
      _lastFetchTime = now;

      return results;
    } catch (e) {
      // If we have a recent in-memory cache, return it silently
      if (_cachedNearbyShops != null) {
        return _cachedNearbyShops!;
      }
      // No cache — let the error propagate so the UI shows the retry card
      rethrow;
    }
  }

  /// Popular shops from `GET /api/user/shop-profile/popular`.
  /// Falls back to nearby search when the user is not logged in.
  Future<List<Restaurant>> getPopularShops({
    required double lat,
    required double lon,
    int page = 1,
    int size = 10,
  }) async {
    if (AuthService().isLoggedIn) {
      final response = await SearchRepository.instance.getPopularShops(
        page: page,
        size: size,
      );
      return response.shops
          .map((dto) => _mapShopDtoToDomain(dto.shop))
          .toList();
    }

    return getNearbyShops(
      lat: lat,
      lon: lon,
      radius: 10.0,
      page: page - 1,
      size: size,
    );
  }

  /// Full shop search with preview menu items (for FoodSearchPage).
  Future<SearchPageResult> searchShopsWithMenu({
    required double lat,
    required double lon,
    required String query,
    double radiusKm = 99999.0,
    int page = 1,
    int size = 20,
    SearchFilters? filters,
  }) {
    return SearchRepository.instance.searchShops(
      latitude: lat,
      longitude: lon,
      search: query,
      radiusKm: radiusKm,
      page: page,
      size: size,
      filters: filters,
    );
  }

  /// Trending shops (by completed orders) from
  /// `GET /api/user/shop-profile/trending`. Returns mapped domain models.
  /// Falls back to nearby shops when the user is not logged in.
  Future<List<Restaurant>> getTrendingShops({
    required double lat,
    required double lon,
    int page = 1,
    int size = 10,
    int? days,
  }) async {
    if (AuthService().isLoggedIn) {
      final response = await SearchRepository.instance.getTrendingShops(
        page: page,
        size: size,
        days: days,
      );
      return response.shops.map((dto) {
        final shop = dto.shop;
        final dist = (shop.latitude != null && shop.longitude != null)
            ? _haversineKm(lat, lon, shop.latitude!, shop.longitude!)
            : null;
        return _mapShopDtoToDomain(shop, distanceKmOverride: dist);
      }).toList();
    }

    return getNearbyShops(
      lat: lat,
      lon: lon,
      radius: 10.0,
      page: page - 1,
      size: size,
    );
  }

  /// Full master menu category catalog (`GET /api/menu/master/categories`).
  Future<List<MasterCategoryDto>> getMasterCategories() {
    return _remoteDataSource.getMasterCategories();
  }

  /// Popular master menu categories (`GET /api/user/master-menu-categories/popular`).
  Future<List<MasterCategoryDto>> getPopularMasterCategories({
    int limit = 10,
    int? days,
  }) {
    return _remoteDataSource.getPopularMasterCategories(limit: limit, days: days);
  }

  /// Cuisine types for search filtering (`GET /api/user/cuisine-types`).
  Future<List<CuisineTypeDto>> getCuisineTypes() {
    return _remoteDataSource.getCuisineTypes();
  }

  /// Curated collections (`GET /api/user/collections`).
  Future<List<CollectionDto>> getCollections({
    int page = 1,
    int size = 20,
    String? search,
  }) {
    return _remoteDataSource.getCollections(page: page, size: size, search: search);
  }

  /// One collection with its items (`GET /api/user/collections/:id`).
  Future<CollectionDto?> getCollectionById(int id) {
    return _remoteDataSource.getCollectionById(id);
  }

  /// Paginated catalog of user-visible shops from
  /// `GET /api/user/shop-profile`. When [originLat]/[originLon] are supplied
  /// and a shop has coordinates, distance is computed client-side (the catalog
  /// endpoint is not geo-aware and omits `distanceKm`).
  ///
  /// Requires an authenticated user; throws otherwise.
  Future<List<Restaurant>> getShopProfiles({
    String? search,
    int? categoryId,
    int page = 1,
    int size = 20,
    double? originLat,
    double? originLon,
  }) async {
    final response = await SearchRepository.instance.listShopProfiles(
      search: search,
      categoryId: categoryId,
      page: page,
      size: size,
    );
    return response.shops.map((dto) {
      final shop = dto.shop;
      final hasOrigin = originLat != null && originLon != null;
      final distance = (hasOrigin &&
              shop.latitude != null &&
              shop.longitude != null)
          ? _haversineKm(originLat, originLon, shop.latitude!, shop.longitude!)
          : null;
      return _mapShopDtoToDomain(shop, distanceKmOverride: distance);
    }).toList();
  }

  Future<Restaurant> getShopById(int id, {double? lat, double? lon}) async {
    try {
      final response = await _remoteDataSource.getShopById(
        id,
        lat: lat,
        lon: lon,
      );
      return _mapShopDetailDtoToDomain(response.data);
    } catch (e) {
      // Auth fallback: enriched user shop-profile detail
      // (GET /api/user/shop-profile/:id) enforces verified-visible shops and
      // carries the authoritative `isFavorite` flag.
      if (AuthService().isLoggedIn) {
        final shop = await SearchRepository.instance.getShopProfileById(id);
        if (shop != null) {
          final dist = (lat != null &&
                  lon != null &&
                  shop.latitude != null &&
                  shop.longitude != null)
              ? _haversineKm(lat, lon, shop.latitude!, shop.longitude!)
              : null;
          return _mapShopDtoToDomain(shop, distanceKmOverride: dist);
        }
      }
      rethrow;
    }
  }

  /// Active payment methods for a shop, used by the checkout flow.
  /// Backend (auth): `GET /api/user/shops/:shopId/payment-methods`.
  Future<List<ShopPaymentTypeDto>> getShopPaymentMethods(int shopId) async {
    return _remoteDataSource.getShopPaymentMethods(shopId);
  }

  /// Great-circle distance in kilometers (haversine).
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

  Future<TrendingSectionDto> getTrendingItems({
    required double lat,
    required double lon,
    double radiusKm = 10.0,
    int page = 0,
    int size = 20,
  }) async {
    final now = DateTime.now();
    // Return cache if less than 2 minutes old AND it's the first page
    if (page == 0 &&
        _cachedTrending != null &&
        _trendingLastFetch != null &&
        now.difference(_trendingLastFetch!).inSeconds < 120) {
      return _cachedTrending!;
    }

    TrendingSectionDto result;
    if (AuthService().isLoggedIn) {
      try {
        result = await SearchRepository.instance.searchTrendingNearby(
          latitude: lat,
          longitude: lon,
          radiusKm: radiusKm,
          page: page + 1, // user endpoint is 1-based
          size: size,
        );
      } catch (_) {
        result = await _remoteDataSource.getTrendingItems(
          lat: lat,
          lon: lon,
          radiusKm: radiusKm,
          page: page,
          size: size,
        );
      }
    } else {
      result = await _remoteDataSource.getTrendingItems(
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
        page: page,
        size: size,
      );
    }

    if (page == 0) {
      _cachedTrending = result;
      _trendingLastFetch = now;
    }
    return result;
  }


  Restaurant _mapShopDtoToDomain(
    ShopListItemDto dto, {
    double? distanceKmOverride,
  }) {
    final imagePath = dto.bannerImageUrl ?? '';

    return Restaurant(
      id: dto.id.toString(),
      name: dto.name,
      nameEn: dto.nameEn,
      nameMm: dto.nameMm,
      nameTh: dto.nameTh,
      category: dto.category ?? 'Restaurant',
      rating: dto.rating,
      reviewCount: dto.reviewCount,
      distance:
          '${(distanceKmOverride ?? dto.distance).toStringAsFixed(1)} km',
      imagePath: _getImageUrl(imagePath),
      logoPath: _getImageUrl(
        (dto.logoUrl != null && !dto.logoUrl!.contains('pinterest.com'))
            ? dto.logoUrl!
            : '',
      ),
      deliveryTime: dto.estimatedTime ?? '20-30 mins',
      deliveryFee: dto.displayDeliveryFee,
      originalDeliveryFee: dto.originalDeliveryFee,
      status: dto.isOpen ? 'Open' : 'Closed',
      latitude: dto.latitude,
      longitude: dto.longitude,
      imageUrls: dto.imageUrls.map((url) => _getImageUrl(url)).toList(),
      isFavorite: dto.isFavorite,
    );
  }

  Restaurant _mapShopDetailDtoToDomain(ShopDetailDto dto) {
    final imagePath = dto.bannerImageUrl ?? '';

    return Restaurant(
      id: dto.id.toString(),
      name: dto.name,
      nameEn: dto.nameEn,
      nameMm: dto.nameMm,
      nameTh: dto.nameTh,
      category: dto.category ?? 'Restaurant',
      rating: dto.rating,
      reviewCount: dto.reviewCount,
      distance: '${dto.distance.toStringAsFixed(1)} km',
      imagePath: _getImageUrl(imagePath),
      logoPath: _getImageUrl(
        (dto.logoUrl != null && !dto.logoUrl!.contains('pinterest.com'))
            ? dto.logoUrl!
            : '',
      ),
      deliveryTime: dto.estimatedTime ?? '20-30 mins',
      status: dto.isOpen ? 'Open' : 'Closed',
      latitude: dto.latitude,
      longitude: dto.longitude,
      imageUrls: dto.photos.map((url) => _getImageUrl(url)).toList(),
      popularDishes: dto.popularDishes,
      recommendations: dto.recommendations,
      hotDeals: dto.hotDeals,
      address: dto.address,
      addressMm: dto.addressMm,
      addressTh: dto.addressTh,
      addressEn: dto.addressEn,
      phone: dto.phone,
      email: dto.email,
      googleMapsLink: dto.googleMapsLink,
      operatingHours: dto.operatingHours,
      hasParking: dto.hasParking,
      hasWifi: dto.hasWifi,
      isHalal: dto.isHalal,
      isVegetarian: dto.isVegetarian,
      isFavorite: dto.isFavorite,
      paymentTypes: dto.paymentTypes,
      paymentQrUrl: dto.paymentQrUrl,
    );
  }

  static const _feedTypes = [
    'right-now',
    'for-you',
    'hot-deals',
    'trending',
    'popular-dishes',
  ];

  /// Fires all 5 feed requests in parallel. Call this on page entry for
  /// best performance — results land in cache before the user scrolls down.
  void prefetchShopFeeds(int shopId, {bool forceRefresh = false}) {
    for (final type in _feedTypes) {
      getShopFeed(shopId: shopId, feedType: type, forceRefresh: forceRefresh);
    }
  }

  /// A shop's menu categories (`GET /api/user/menu-categories?shopId=`), used
  /// to group the restaurant detail menu into sections.
  Future<List<MenuCategoryDto>> getMenuCategories({
    required int shopId,
    String? search,
  }) {
    return _remoteDataSource.getMenuCategories(shopId: shopId, search: search);
  }

  Future<SliceShopFeedItemDto> getShopMenu({
    required int shopId,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _remoteDataSource.getShopMenu(
      shopId: shopId,
      page: page,
      size: size,
    );
    return response.data;
  }

  /// Returns a cached feed section or fetches from the API.
  /// Cache TTL: 5 minutes per shopId+feedType combination.
  Future<ShopFeedSectionDto> getShopFeed({
    required int shopId,
    required String feedType,
    bool forceRefresh = false,
  }) async {
    final key = '$shopId-$feedType';
    final now = DateTime.now();
    final cached = _feedCache[key];
    final cacheTime = _feedCacheTime[key];

    if (!forceRefresh &&
        cached != null &&
        cacheTime != null &&
        now.difference(cacheTime).inMinutes < 1) {
      return cached;
    }
    final result = await _remoteDataSource.getShopFeed(
      shopId: shopId,
      feedType: feedType,
    );
    _feedCache[key] = result;
    _feedCacheTime[key] = now;
    return result;
  }

  /// Returns a cached food tab feed section or fetches from the API.
  /// Cache TTL: 5 minutes per feedType.
  Future<ShopFeedSectionDto> getFoodTabFeed({
    required String feedType,
    required double lat,
    required double lon,
    double radiusKm = 10.0,
    int page = 0,
    int size = 20,
  }) async {
    final key = 'food-tab-$feedType-$page-$size';
    final now = DateTime.now();
    final cached = _feedCache[key];
    final cacheTime = _feedCacheTime[key];
    if (cached != null &&
        cacheTime != null &&
        now.difference(cacheTime).inMinutes < 5) {
      return cached;
    }
    final result = await _remoteDataSource.getFoodTabFeed(
      feedType: feedType,
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
      page: page,
      size: size,
    );
    _feedCache[key] = result;
    _feedCacheTime[key] = now;
    return result;
  }

  /// Discounted menu items for the home "Together — Up to X% Off" carousel
  /// (`GET /api/user/menu-items/discount`). Cached for 5 minutes.
  Future<DiscountDealsDto> getDiscountDeals({
    required double lat,
    required double lon,
    int percentage = 50,
    double radiusKm = 30.0,
    int size = 10,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedDiscountDeals != null &&
        _discountDealsLastFetch != null &&
        now.difference(_discountDealsLastFetch!).inMinutes < 5) {
      return _cachedDiscountDeals!;
    }

    final result = await _remoteDataSource.getDiscountDeals(
      lat: lat,
      lon: lon,
      percentage: percentage,
      radiusKm: radiusKm,
      size: size,
    );
    _cachedDiscountDeals = result;
    _discountDealsLastFetch = now;
    return result;
  }

  Future<FoodDetailDto?> getFoodById(int id) async {
    return _remoteDataSource.getFoodById(id);
  }

  /// Auth-aware menu item fetch (includes favorite state). Falls back to the
  /// public food endpoint when not logged in.
  Future<FoodDetailDto?> getUserFoodById(int id) async {
    return _remoteDataSource.getUserMenuItemById(id);
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  Future<void> toggleShopFavorite(int shopId, bool isFavorite) async {
    if (isFavorite) {
      await _remoteDataSource.addShopFavorite(shopId);
    } else {
      await _remoteDataSource.removeShopFavorite(shopId);
    }
  }

  Future<void> toggleMenuFavorite(int menuItemId, bool isFavorite) async {
    if (isFavorite) {
      await _remoteDataSource.addMenuFavorite(menuItemId);
    } else {
      await _remoteDataSource.removeMenuFavorite(menuItemId);
    }
  }

  Future<void> trackConversion(int shopId, String action) async {
    await _remoteDataSource.trackConversion(shopId, action);
  }

  /// Clears the feed cache for a specific shop or all shops.
  void clearCache({int? shopId}) {
    if (shopId != null) {
      _feedCache.removeWhere((key, _) => key.startsWith('$shopId-'));
      _feedCacheTime.removeWhere((key, _) => key.startsWith('$shopId-'));
      _cachedNearbyShops =
          null; // Clear nearby shops as status might have changed
    } else {
      _feedCache.clear();
      _feedCacheTime.clear();
      _cachedNearbyShops = null;
      _cachedTrending = null;
      _cachedBanners.clear();
      _bannersLastFetch = null;
      _cachedDiscountDeals = null;
      _discountDealsLastFetch = null;
    }
  }

  Future<List<ShopReviewDto>> getShopReviews(int shopId) {
    return _remoteDataSource.getShopReviews(shopId);
  }

  Future<ShopReviewSummaryDto> getShopReviewSummary(int shopId) {
    return _remoteDataSource.getShopReviewSummary(shopId);
  }
}
