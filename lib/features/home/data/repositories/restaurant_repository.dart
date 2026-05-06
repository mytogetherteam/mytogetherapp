import '../restaurant_data.dart';
import '../models/banner_image_dto.dart';
import '../models/trending_item_dto.dart';
import '../models/shop_feed_item_dto.dart';
import '../remote_restaurant_data_source.dart';
import '../models/shop_dto.dart';
import '../models/food_detail_dto.dart';

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
  Map<String, List<BannerImageDto>> _cachedBanners = {};
  DateTime? _bannersLastFetch;

  // Cache for shop feed sections: key = "shopId-feedType"
  final Map<String, ShopFeedSectionDto> _feedCache = {};
  final Map<String, DateTime> _feedCacheTime = {};

  RestaurantRepository(this._remoteDataSource);

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
  }) async {
    // Generate a unique key for this request
    final cacheKey = '$lat-$lon-$radius-$page-$size';
    final now = DateTime.now();

    // If we have cached data for the SAME request and it's less than 30 seconds old, return it
    if (_cachedNearbyShops != null && 
        _lastCacheKey == cacheKey && 
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inSeconds < 30) {
      return _cachedNearbyShops!;
    }

    try {
      final request = ShopRequestDto(
        lat: lat,
        lon: lon,
        radius: radius,
        page: page,
        size: size,
      );
      final response = await _remoteDataSource.getNearbyShops(request);
      final results = response.data.content.map((dto) => _mapShopDtoToDomain(dto)).toList();
      
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


  Future<Restaurant> getShopById(int id, {double? lat, double? lon}) async {
    final response = await _remoteDataSource.getShopById(id, lat: lat, lon: lon);
    return _mapShopDetailDtoToDomain(response.data);
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
    final result = await _remoteDataSource.getTrendingItems(
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
      page: page,
      size: size,
    );
    if (page == 0) {
      _cachedTrending = result;
      _trendingLastFetch = now;
    }
    return result;
  }

  Restaurant _mapShopDtoToDomain(ShopListItemDto dto) {
    String imagePath = '';
    
    // 1. Prioritize imageUrls list (as requested by user)
    if (dto.imageUrls.isNotEmpty) {
      imagePath = dto.imageUrls.first;
    } 
    // 2. Fallback to logoUrl if available and NOT a Pinterest link
    else if (dto.logoUrl != null && 
             dto.logoUrl!.isNotEmpty && 
             !dto.logoUrl!.contains('pinterest.com')) {
      imagePath = dto.logoUrl!;
    }
    // 3. Last fallback to primaryPhotoUrl
    else if (dto.primaryPhotoUrl != null && dto.primaryPhotoUrl!.isNotEmpty) {
      imagePath = dto.primaryPhotoUrl!;
    }
    
    // If still empty, use a curated food placeholder for premium feel
    if (imagePath.isEmpty) {
      imagePath = 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=800&auto=format&fit=crop';
    }

    return Restaurant(
      id: dto.id.toString(),
      name: dto.name,
      category: dto.category ?? 'Restaurant',
      rating: dto.rating,
      reviewCount: dto.reviewCount,
      distance: '${dto.distance.toStringAsFixed(1)} km',
      imagePath: imagePath,
      logoPath: (dto.logoUrl != null && !dto.logoUrl!.contains('pinterest.com')) 
          ? dto.logoUrl! 
          : '', 
      deliveryTime: dto.estimatedTime ?? '20-30 mins',
      deliveryFee: dto.displayDeliveryFee,
      originalDeliveryFee: dto.originalDeliveryFee,
      status: dto.isOpen ? 'Open' : 'Closed',
      latitude: dto.latitude,
      longitude: dto.longitude,
      imageUrls: dto.imageUrls,
      isFavorite: dto.isFavorite,
    );
  }

  Restaurant _mapShopDetailDtoToDomain(ShopDetailDto dto) {
    final imagePath = (dto.coverUrl != null && dto.coverUrl!.isNotEmpty)
        ? dto.coverUrl!
        : (dto.primaryPhotoUrl != null && dto.primaryPhotoUrl!.isNotEmpty)
            ? dto.primaryPhotoUrl!
            : (dto.photos.isNotEmpty ? dto.photos.first : '');

    return Restaurant(
      id: dto.id.toString(),
      name: dto.name,
      category: dto.category ?? 'Restaurant',
      rating: dto.rating,
      reviewCount: dto.reviewCount,
      distance: '${dto.distance.toStringAsFixed(1)} km',
      imagePath: imagePath,
      logoPath: (dto.logoUrl != null && !dto.logoUrl!.contains('pinterest.com')) 
          ? dto.logoUrl! 
          : '',
      deliveryTime: dto.estimatedTime ?? '20-30 mins',
      status: dto.isOpen ? 'Open' : 'Closed',
      latitude: dto.latitude,
      longitude: dto.longitude,
      imageUrls: dto.photos,
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
      isFavorite: dto.isFavorite,
      paymentTypes: dto.paymentTypes,
      paymentQrUrl: dto.paymentQrUrl,
    );
  }

  static const _feedTypes = [
    'right-now', 'for-you', 'hot-deals', 'trending', 'popular-dishes'
  ];

  /// Fires all 5 feed requests in parallel. Call this on page entry for
  /// best performance — results land in cache before the user scrolls down.
  void prefetchShopFeeds(int shopId) {
    for (final type in _feedTypes) {
      getShopFeed(shopId: shopId, feedType: type);
    }
  }

  /// Returns a cached feed section or fetches from the API.
  /// Cache TTL: 5 minutes per shopId+feedType combination.
  Future<ShopFeedSectionDto> getShopFeed({
    required int shopId,
    required String feedType,
  }) async {
    final key = '$shopId-$feedType';
    final now = DateTime.now();
    final cached = _feedCache[key];
    final cacheTime = _feedCacheTime[key];
    if (cached != null &&
        cacheTime != null &&
        now.difference(cacheTime).inMinutes < 5) {
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
  }) async {
    final key = 'food-tab-$feedType';
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
    );
    _feedCache[key] = result;
    _feedCacheTime[key] = now;
    return result;
  }

  Future<FoodDetailDto?> getFoodById(int id) async {
    return _remoteDataSource.getFoodById(id);
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
}
