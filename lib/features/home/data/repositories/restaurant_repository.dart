import 'dart:async';

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
import '../models/home_discount_section_dto.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/location/geo_distance.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/features/search/data/search_repository.dart';
import 'package:mytogetherapp/features/search/data/models/search_shop_dto.dart';
import 'package:mytogetherapp/features/search/data/models/search_filters.dart';
import '../models/nearby_shops_page_result.dart';
import '../shop_order_state_cache.dart';
import '../shop_storage.dart';

class RestaurantRepository {
  static final RestaurantRepository instance = RestaurantRepository(
    RemoteRestaurantDataSource(),
  );

  final RemoteRestaurantDataSource _remoteDataSource;

  // Simple cache for nearby shops
  List<Restaurant>? _cachedNearbyShops;
  NearbyShopsPageResult? _cachedNearbyPageResult;
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

  /// Caps in-memory feed pages so long explore scrolls do not grow without bound.
  static const int _maxFeedCacheEntries = 48;

  // Cache for the home discount carousel
  DiscountDealsDto? _cachedDiscountDeals;
  String? _discountDealsCacheKey;
  DateTime? _discountDealsLastFetch;

  // Cache for the admin-controlled home discount section config.
  // Mirrors the backend Redis TTL (~60s); admin edits invalidate server-side.
  HomeDiscountSectionListDto? _cachedDiscountConfig;
  DateTime? _discountConfigLastFetch;

  RestaurantRepository(this._remoteDataSource);

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  /// Active banners for [position]: Ads, Promotions, Order, or Splash.
  /// Results are cached briefly and ordered by [BannerImageDto.displayOrder].
  /// Network failures are not written to cache (important for Order / Splash).
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
      // Don't cache empty Order/Splash — a failed/empty fetch must not block a
      // newly published banner for the full 10-minute window.
      final isOrderOrSplash = position == 'Order' || position == 'Splash';
      if (!isOrderOrSplash || banners.isNotEmpty) {
        _cachedBanners[cacheKey] = banners;
        _bannersLastFetch = now;
      }
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
    final result = await getNearbyShopsPage(
      lat: lat,
      lon: lon,
      radius: radius,
      page: page,
      size: size,
      search: search,
    );
    return result.restaurants;
  }

  Future<List<Restaurant>> getShopsWithActiveMyDays({
    int size = 20,
  }) async {
    try {
      final response = await SearchRepository.instance.searchNearbyActiveMyDays(
        page: 1,
        size: size,
      );
      return response.shops
          .map((dto) => _mapShopWithDistance(dto.shop, lat: 0, lon: 0))
          .toList();
    } catch (e) {
      print('Error fetching shops with active mydays: $e');
      return [];
    }
  }


  Future<NearbyShopsPageResult> getNearbyShopsPage({
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
    if (_cachedNearbyPageResult != null &&
        _lastCacheKey == cacheKey &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inSeconds < 30) {
      unawaited(_prefetchOrderStateForRestaurants(_cachedNearbyPageResult!.restaurants));
      return _cachedNearbyPageResult!;
    }

    try {
      List<Restaurant> results;
      SearchPageResult response;

      if (AuthService().isLoggedIn) {
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
            .map((dto) => _mapShopWithDistance(dto.shop, lat: lat, lon: lon))
            .toList();
      } else {
        response = await SearchRepository.instance.searchNearby(
          latitude: lat,
          longitude: lon,
          radiusKm: radius,
          page: page + 1,
          size: size,
        );
        results = response.shops
            .map((dto) => _mapShopWithDistance(dto.shop, lat: lat, lon: lon))
            .toList();
      }

      final pageResult = NearbyShopsPageResult(
        restaurants: results,
        page: response.currentPage,
        lastPage: response.lastPage,
        total: response.total,
        pageSize: size,
      );

      // Update cache
      _cachedNearbyShops = results;
      _cachedNearbyPageResult = pageResult;
      _lastCacheKey = cacheKey;
      _lastFetchTime = now;

      unawaited(_prefetchOrderStateForRestaurants(results));

      return pageResult;
    } catch (e) {
      // If we have a recent in-memory cache, return it silently
      if (_cachedNearbyShops != null) {
        return NearbyShopsPageResult(
          restaurants: _cachedNearbyShops!,
          page: page + 1,
          lastPage: page + 1,
          total: _cachedNearbyShops!.length,
          pageSize: size,
        );
      }
      // No cache — let the error propagate so the UI shows the retry card
      rethrow;
    }
  }

  /// Loads every shop within [radius] km for map markers. The nearby API caps
  /// each page at 100; this walks pages until [SearchPageResult.hasMore] is false.
  Future<List<Restaurant>> getAllNearbyShopsWithinRadius({
    required double lat,
    required double lon,
    double radius = 5.0,
  }) async {
    const fetchSize = 100;
    final all = <Restaurant>[];
    var page = 1;

    while (true) {
      final response = await SearchRepository.instance.searchNearby(
        latitude: lat,
        longitude: lon,
        radiusKm: radius,
        page: page,
        size: fetchSize,
      );
      all.addAll(
        response.shops
            .map((dto) => _mapShopWithDistance(dto.shop, lat: lat, lon: lon))
            .toList(),
      );
      if (!response.hasMore) break;
      page++;
    }

    unawaited(_prefetchOrderStateForRestaurants(all));
    return all;
  }

  /// Popular shops from `GET /api/user/shop-profile/popular`.
  /// Falls back to nearby search when the user is not logged in.
  Future<List<Restaurant>> getPopularShops({
    required double lat,
    required double lon,
    int page = 1,
    int size = 10,
  }) async {
    final result = await getPopularShopsPage(
      lat: lat,
      lon: lon,
      page: page,
      size: size,
    );
    return result.restaurants;
  }

  Future<NearbyShopsPageResult> getPopularShopsPage({
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
      final restaurants = await _prefetchAndReturn(
        response.shops
            .map((dto) => _mapShopWithDistance(dto.shop, lat: lat, lon: lon))
            .toList(),
      );
      return NearbyShopsPageResult(
        restaurants: restaurants,
        page: response.currentPage,
        lastPage: response.lastPage,
        total: response.total,
        pageSize: size,
      );
    }

    return getNearbyShopsPage(
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
    final result = await getTrendingShopsPage(
      lat: lat,
      lon: lon,
      page: page,
      size: size,
      days: days,
    );
    return result.restaurants;
  }

  Future<NearbyShopsPageResult> getTrendingShopsPage({
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
      final restaurants = response.shops
          .map((dto) => _mapShopWithDistance(dto.shop, lat: lat, lon: lon))
          .toList();
      unawaited(_prefetchOrderStateForRestaurants(restaurants));
      return NearbyShopsPageResult(
        restaurants: restaurants,
        page: response.currentPage,
        lastPage: response.lastPage,
        total: response.total,
        pageSize: size,
      );
    }

    return getNearbyShopsPage(
      lat: lat,
      lon: lon,
      radius: 10.0,
      page: page - 1,
      size: size,
    );
  }

  /// Master menu categories for search filters
  /// (`GET /api/user/master-menu-categories/popular`).
  Future<List<MasterCategoryDto>> getMasterCategories() {
    return _remoteDataSource.getMasterCategories();
  }

  /// Popular master menu categories (`GET /api/user/master-menu-categories/popular`).
  Future<List<MasterCategoryDto>> getPopularMasterCategories({
    int limit = 10,
  }) {
    return _remoteDataSource.getPopularMasterCategories(limit: limit);
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
    final result = await getShopProfilesPage(
      search: search,
      categoryId: categoryId,
      page: page,
      size: size,
      originLat: originLat,
      originLon: originLon,
    );
    return result.restaurants;
  }

  Future<NearbyShopsPageResult> getShopProfilesPage({
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
    final restaurants = response.shops.map((dto) {
      final shop = dto.shop;
      if (originLat != null && originLon != null) {
        return _mapShopWithDistance(shop, lat: originLat, lon: originLon);
      }
      return _mapShopDtoToDomain(shop);
    }).toList();
    return NearbyShopsPageResult(
      restaurants: restaurants,
      page: response.currentPage,
      lastPage: response.lastPage,
      total: response.total,
      pageSize: size,
    );
  }

  Future<Restaurant> getShopById(int id, {double? lat, double? lon}) async {
    if (!AuthService().isLoggedIn) {
      throw Exception('Login required to view shop details');
    }

    final response = await _remoteDataSource.getShopById(
      id,
      lat: lat,
      lon: lon,
    );
    final detail = _mapShopDetailDtoToDomain(response.data);
    if (lat != null &&
        lon != null &&
        detail.latitude != null &&
        detail.longitude != null) {
      final dist = GeoDistance.estimatedRoutingKm(
          lat, lon, detail.latitude!, detail.longitude!);
      return detail.copyWith(
        distance: '${dist.toStringAsFixed(1)} km',
        deliveryTime: GeoDistance.deliveryEtaFromKm(dist),
      );
    }
    return detail;
  }

  /// Active payment methods for a shop, used by the checkout flow.
  /// Backend (auth): `GET /api/user/shops/:shopId/payment-methods`.
  Future<List<ShopPaymentTypeDto>> getShopPaymentMethods(int shopId) async {
    return _remoteDataSource.getShopPaymentMethods(shopId);
  }

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
    result = await SearchRepository.instance.searchTrendingNearby(
      latitude: lat,
      longitude: lon,
      radiusKm: radiusKm,
      page: page + 1,
      size: size,
    );

    if (page == 0) {
      _cachedTrending = result;
      _trendingLastFetch = now;
    }
    return result;
  }


  Restaurant _mapShopWithDistance(
    ShopListItemDto shop, {
    required double lat,
    required double lon,
  }) {
    final dist = GeoDistance.resolveDistanceKm(
      originLat: lat,
      originLon: lon,
      apiDistanceKm: shop.distance > 0 ? shop.distance : null,
      shopLat: shop.latitude,
      shopLon: shop.longitude,
    );
    return _mapShopDtoToDomain(shop, distanceKmOverride: dist);
  }

  String _deliveryTimeForShop({
    required ShopListItemDto dto,
    double? distanceKmOverride,
  }) {
    final resolvedKm = distanceKmOverride ??
        (dto.distance > 0 ? dto.distance : null);
    if (resolvedKm != null && resolvedKm > 0) {
      return GeoDistance.deliveryEtaFromKm(resolvedKm);
    }
    return dto.estimatedTime ?? GeoDistance.defaultDeliveryEta;
  }

  Restaurant _mapShopDtoToDomain(
    ShopListItemDto dto, {
    double? distanceKmOverride,
  }) {
    final imagePath = dto.bannerImageUrl ?? '';

    final restaurant = Restaurant(
      id: dto.id.toString(),
      name: dto.name,
      nameEn: dto.nameEn,
      nameMm: dto.nameMm,
      nameTh: dto.nameTh,
      descriptionEn: dto.descriptionEn,
      descriptionMm: dto.descriptionMm,
      descriptionTh: dto.descriptionTh,
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
      deliveryTime: _deliveryTimeForShop(
        dto: dto,
        distanceKmOverride: distanceKmOverride,
      ),
      deliveryFee: dto.displayDeliveryFee,
      originalDeliveryFee: dto.originalDeliveryFee,
      status: dto.isOpen ? 'Open' : 'Closed',
      operatingHours: dto.operatingHours,
      deliveryEnabled: dto.deliveryEnabled,
      isVerified: dto.isVerified,
      latitude: dto.latitude,
      longitude: dto.longitude,
      imageUrls: dto.imageUrls.map((url) => _getImageUrl(url)).toList(),
      isFavorite: dto.isFavorite,
      myDays: dto.myDays,
    );
    return _published(restaurant);
  }

  Restaurant _mapShopDetailDtoToDomain(
    ShopDetailDto dto, {
    double? distanceKmOverride,
  }) {
    final imagePath = dto.bannerImageUrl ?? '';

    final restaurant = Restaurant(
      id: dto.id.toString(),
      name: dto.name,
      nameEn: dto.nameEn,
      nameMm: dto.nameMm,
      nameTh: dto.nameTh,
      descriptionEn: dto.descriptionEn,
      descriptionMm: dto.descriptionMm,
      descriptionTh: dto.descriptionTh,
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
      deliveryTime: () {
        final resolvedKm = distanceKmOverride ??
            (dto.distance > 0 ? dto.distance : null);
        if (resolvedKm != null && resolvedKm > 0) {
          return GeoDistance.deliveryEtaFromKm(resolvedKm);
        }
        return dto.estimatedTime ?? GeoDistance.defaultDeliveryEta;
      }(),
      status: dto.isOpen ? 'Open' : 'Closed',
      deliveryEnabled: dto.deliveryEnabled,
      taxEnable: dto.taxEnable,
      isVerified: dto.isVerified,
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
      myDays: dto.myDays,
    );
    return _published(restaurant);
  }

  Restaurant _published(Restaurant restaurant) {
    ShopOrderStateCache.instance.ensureListening();
    ShopOrderStateCache.instance.remember(restaurant);
    return restaurant;
  }

  /// Loads operating hours / delivery state for list cards when the nearby
  /// search response omits them. Updates [ShopOrderStateCache] so home + food
  /// tab cards fade in sync without opening the detail page first.
  Future<void> _prefetchOrderStateForRestaurants(
    List<Restaurant> restaurants,
  ) async {
    ShopOrderStateCache.instance.ensureListening();
    final needsApi = <int>[];

    for (final restaurant in restaurants) {
      final shopId = int.tryParse(restaurant.id);
      if (shopId == null || shopId <= 0) continue;

      final hasCompleteSchedule =
          restaurant.operatingHours.length >= 7 ||
          ShopOrderStateCache.instance.hasCompleteOperatingHours(shopId);

      if (hasCompleteSchedule) {
        ShopOrderStateCache.instance.rememberParts(
          shopId,
          deliveryEnabled: restaurant.deliveryEnabled,
          operatingHours: restaurant.operatingHours,
          status: restaurant.status,
        );
        continue;
      }

      final stored = await ShopStorage.getShop(shopId);
      if (stored != null) {
        _applyShopProfileJsonToCache(shopId, stored);
        if (ShopOrderStateCache.instance.hasCompleteOperatingHours(shopId)) {
          continue;
        }
      }
      needsApi.add(shopId);
    }

    await Future.wait(
      needsApi.map((shopId) async {
        try {
          final dto = await SearchRepository.instance.getShopProfileById(shopId);
          if (dto == null) return;
          ShopOrderStateCache.instance.replaceParts(
            shopId,
            deliveryEnabled: dto.deliveryEnabled,
            operatingHours: dto.operatingHours,
            status: dto.isOpen ? 'Open' : 'Closed',
          );
        } catch (_) {}
      }),
    );
  }

  /// Polls `GET /api/user/shop-profile/:id` for live open/closed and delivery
  /// state when WebSocket updates are unavailable (e.g. guest / PWA).
  Future<void> refreshOrderStatesForShopIds(Iterable<int> shopIds) async {
    final ids = shopIds.where((id) => id > 0).toSet();
    if (ids.isEmpty) return;

    ShopOrderStateCache.instance.ensureListening();
    await Future.wait(
      ids.map((shopId) async {
        try {
          final dto = await SearchRepository.instance.getShopProfileById(shopId);
          if (dto == null) return;
          ShopOrderStateCache.instance.replaceParts(
            shopId,
            deliveryEnabled: dto.deliveryEnabled,
            operatingHours: dto.operatingHours,
            status: dto.isOpen ? 'Open' : 'Closed',
          );
          clearCache(shopId: shopId);
        } catch (_) {}
      }),
    );
  }

  Future<List<Restaurant>> _prefetchAndReturn(List<Restaurant> restaurants) {
    unawaited(_prefetchOrderStateForRestaurants(restaurants));
    return Future.value(restaurants);
  }

  void _applyShopProfileJsonToCache(int shopId, Map<String, dynamic> json) {
    final dto = ShopListItemDto.fromJson(json);
    ShopOrderStateCache.instance.rememberParts(
      shopId,
      deliveryEnabled: dto.deliveryEnabled,
      operatingHours: dto.operatingHours,
      status: dto.isOpen ? 'Open' : 'Closed',
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
    int? categoryId,
  }) async {
    final response = await _remoteDataSource.getShopMenu(
      shopId: shopId,
      page: page,
      size: size,
      categoryId: categoryId,
    );
    return response.data;
  }

  void _storeFeedCache(String key, ShopFeedSectionDto value) {
    while (_feedCache.length >= _maxFeedCacheEntries && _feedCache.isNotEmpty) {
      String? oldestKey;
      DateTime? oldestTime;
      for (final entry in _feedCacheTime.entries) {
        if (oldestTime == null || entry.value.isBefore(oldestTime)) {
          oldestTime = entry.value;
          oldestKey = entry.key;
        }
      }
      if (oldestKey == null) break;
      _feedCache.remove(oldestKey);
      _feedCacheTime.remove(oldestKey);
    }
    _feedCache[key] = value;
    _feedCacheTime[key] = DateTime.now();
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
    _storeFeedCache(key, result);
    return result;
  }

  /// Returns a cached food tab feed section or fetches from the API.
  /// Cache TTL: 5 minutes per feedType+page (LRU capped at [_maxFeedCacheEntries]).
  Future<ShopFeedSectionDto> getFoodTabFeed({
    required String feedType,
    required double lat,
    required double lon,
    double radiusKm = 10.0,
    int page = 0,
    int size = 20,
  }) async {
    final key =
        'food-tab-$feedType-${lat.toStringAsFixed(3)}-${lon.toStringAsFixed(3)}-$page-$size';
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
    _storeFeedCache(key, result);
    return result;
  }

  /// Admin-controlled home discount section config
  /// (`GET /api/user/home-discount-section`). The backend caches this in Redis
  /// (~60s TTL) and invalidates on admin edits; we mirror that with a short
  /// client cache and always refetch on home open / pull-to-refresh / resume
  /// via [forceRefresh] (or [clearCache]).
  Future<HomeDiscountSectionListDto> getHomeDiscountSectionConfig({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedDiscountConfig != null &&
        _discountConfigLastFetch != null &&
        now.difference(_discountConfigLastFetch!).inSeconds < 60) {
      return _cachedDiscountConfig!;
    }

    try {
      final result = await _remoteDataSource.getHomeDiscountSection();
      _cachedDiscountConfig = result;
      _discountConfigLastFetch = now;
      return result;
    } catch (e) {
      if (_cachedDiscountConfig != null) return _cachedDiscountConfig!;
      rethrow;
    }
  }

  /// Discounted menu items for the home discount carousel
  /// (`GET /api/user/menu-items/discount`). [percentage] and [sectionTitle]
  /// come from the active home discount section config — never hardcoded.
  /// Cached for 5 minutes keyed by the request inputs.
  Future<DiscountDealsDto> getDiscountDeals({
    required double lat,
    required double lon,
    int percentage = 50,
    double radiusKm = 30.0,
    int page = 1,
    int size = 10,
    String? sectionTitle,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cacheKey =
        '$percentage|${sectionTitle ?? ''}|$page|$size|${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}';
    if (!forceRefresh &&
        _cachedDiscountDeals != null &&
        _discountDealsCacheKey == cacheKey &&
        _discountDealsLastFetch != null &&
        now.difference(_discountDealsLastFetch!).inMinutes < 5) {
      return _cachedDiscountDeals!;
    }

    final result = await _remoteDataSource.getDiscountDeals(
      lat: lat,
      lon: lon,
      percentage: percentage,
      radiusKm: radiusKm,
      page: page,
      size: size,
      sectionTitle: sectionTitle,
    );
    _cachedDiscountDeals = result;
    _discountDealsCacheKey = cacheKey;
    _discountDealsLastFetch = now;
    return result;
  }

  Future<FoodDetailDto?> getFoodById(int id) async {
    return _remoteDataSource.getFoodById(id);
  }

  /// Auth-aware menu item fetch (includes favorite state). Requires login.
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

  /// Clears only caches tied to the user's delivery coordinates (nearby shops,
  /// geo food-tab feeds, discount deals). Does not touch banners, collections,
  /// shop profiles, or other non-location data.
  void clearNearbyCache() {
    _cachedNearbyShops = null;
    _cachedNearbyPageResult = null;
    _lastCacheKey = null;
    _lastFetchTime = null;
    _feedCache.removeWhere((key, _) => key.startsWith('food-tab-'));
    _feedCacheTime.removeWhere((key, _) => key.startsWith('food-tab-'));
    _cachedDiscountDeals = null;
    _discountDealsCacheKey = null;
    _discountDealsLastFetch = null;
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
      _discountDealsCacheKey = null;
      _discountDealsLastFetch = null;
      _cachedDiscountConfig = null;
      _discountConfigLastFetch = null;
    }
  }

  Future<Map<String, dynamic>?> getBackgroundTheme() async {
    final themeData = await _remoteDataSource.getBackgroundTheme();
    if (themeData != null && themeData['url'] != null) {
      themeData['url'] = _getImageUrl(themeData['url']);
      return themeData;
    }
    return null;
  }

  Future<List<ShopReviewDto>> getShopReviews(int shopId) {
    return _remoteDataSource.getShopReviews(shopId);
  }

  Future<ShopReviewSummaryDto> getShopReviewSummary(int shopId) {
    return _remoteDataSource.getShopReviewSummary(shopId);
  }
}
