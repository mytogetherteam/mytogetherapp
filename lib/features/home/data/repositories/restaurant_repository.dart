import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../fallback_data.dart';
import '../restaurant_data.dart';
import '../models/trending_item_dto.dart';
import '../models/shop_feed_item_dto.dart';
import '../remote_restaurant_data_source.dart';
import '../models/shop_dto.dart';
import '../models/food_detail_dto.dart';
import '../models/category_dto.dart';
import '../models/menu_item_dto.dart';

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

  // Cache for shop feed sections: key = "shopId-feedType"
  final Map<String, ShopFeedSectionDto> _feedCache = {};
  final Map<String, DateTime> _feedCacheTime = {};

  // High-quality Myanmar demo fallback data from local asset
  Map<String, dynamic>? _fallbackData;
  Map<String, dynamic>? _primaryFallbackData;
  final Set<String> _primaryShopIds = {};

  RestaurantRepository(this._remoteDataSource);

  Future<void> _ensureFallbackLoaded() async {
    // Only return early if both are actually loaded with data
    if (_fallbackData != null && _primaryFallbackData != null) return;
    
    debugPrint('[FALLBACK] Attempting to load assets from assets/data/ directory...');

    if (_fallbackData == null) {
      try {
        final jsonString = await rootBundle.loadString('assets/data/food_fallback.json');
        _fallbackData = jsonDecode(jsonString);
        debugPrint('[FALLBACK] Successfully loaded food_fallback.json (${(_fallbackData as Map).length} root keys)');
      } catch (e) {
        _fallbackData = {};
        debugPrint('[FALLBACK] FAILED to load food_fallback.json: $e');
        debugPrint('[FALLBACK] Check if assets/data/food_fallback.json exists and is in pubspec.yaml');
      }
    }

    if (_primaryFallbackData == null) {
      try {
        final primaryString = await rootBundle.loadString('assets/data/two_restaurants_with_reviews.json');
        _primaryFallbackData = jsonDecode(primaryString);
        debugPrint('[FALLBACK] Successfully loaded primary fallback: two_restaurants_with_reviews.json');
      } catch (e) {
        _primaryFallbackData = {};
        debugPrint('[FALLBACK] FAILED to load two_restaurants_with_reviews.json: $e');
        debugPrint('[FALLBACK] Check if assets/data/two_restaurants_with_reviews.json exists and is in pubspec.yaml');
      }
    }
  }

  Restaurant _mapPrimaryShopToDomain(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Restaurant',
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      distance: '${(json['distance'] ?? 0.0).toStringAsFixed(1)} km',
      imagePath: json['primaryPhotoUrl'] as String? ?? '',
      logoPath: json['logoUrl'] as String? ?? '',
      deliveryTime: json['estimatedTime'] as String? ?? '20-30 mins',
      status: (json['isOpen'] == true) ? 'Open' : 'Closed',
      imageUrls: [
        if (json['coverUrl'] != null) json['coverUrl'],
        if (json['primaryPhotoUrl'] != null) json['primaryPhotoUrl'],
      ],
    );
  }

  Future<List<Restaurant>> _getFallbackShops() async {
    await _ensureFallbackLoaded();
    final List<Restaurant> results = [];

    // 1. Primary Data
    if (_primaryFallbackData != null) {
      // New structure: shopList.data.content
      if (_primaryFallbackData!.containsKey('shopList')) {
        try {
          final shopListRaw = _primaryFallbackData!['shopList'];
          final response = ApiResponseSliceShopListDto.fromJson(shopListRaw);
          for (final shop in response.data.content) {
            results.add(_mapShopDtoToDomain(shop));
          }
        } catch (e) {
          debugPrint('[FALLBACK] Error parsing primary shopList: $e');
        }
      } 
      // Compatibility with old structure: shops
      else if (_primaryFallbackData!.containsKey('shops')) {
        final shopsRaw = _primaryFallbackData!['shops'] as List?;
        if (shopsRaw != null) {
          for (final shop in shopsRaw) {
            results.add(_mapPrimaryShopToDomain(shop as Map<String, dynamic>));
          }
        }
      }

      // Collect primary shop IDs for prioritization
      _primaryShopIds.clear();
      for (final shop in results) {
        _primaryShopIds.add(shop.id);
      }
    }

    // 2. Secondary Data
    // Always attempt to merge secondary fallback data for more variety

    if (_fallbackData == null || _fallbackData?.containsKey('shopList') == false) {
      return results;
    }

    final fallbackListRaw = _fallbackData!['shopList'];
    try {
      debugPrint('[FALLBACK] Parsing fallback shopList raw data...');
      final response = ApiResponseSliceShopListDto.fromJson(fallbackListRaw);
      final basicShops = response.data.content;
      debugPrint(
        '[FALLBACK] Parsed ${basicShops.length} basic shops from shopList',
      );

      // Enrichment: Attempt to find better data in shopDetails
      final detailsList = _fallbackData!['shopDetails'] as List?;
      debugPrint(
        '[FALLBACK] shopDetails list found: ${detailsList != null} (length: ${detailsList?.length})',
      );

      for (final dto in basicShops) {
        final detailMatch = detailsList?.firstWhere(
          (item) => item['data']?['id'] == dto.id,
          orElse: () => null,
        );

        final isDuplicate = results.any((r) => 
          r.id == dto.id.toString() || 
          r.name.toLowerCase().trim() == dto.name.toLowerCase().trim()
        );

        if (isDuplicate) continue;

        if (detailMatch != null) {
          try {
            final detailDto = ShopDetailDto.fromJson(detailMatch['data']);
            results.add(_mapShopDetailDtoToDomain(detailDto));
          } catch (e) {
            debugPrint(
              '[FALLBACK] Error parsing detail for shop ${dto.id}: $e',
            );
            results.add(_mapShopDtoToDomain(dto));
          }
        } else {
          results.add(_mapShopDtoToDomain(dto));
        }
      }

      if (results.isEmpty) {
        debugPrint(
          '[FALLBACK] No shops parsed from JSON, using hardcoded FallbackData.restaurants as last resort',
        );
        return FallbackData.restaurants;
      }


      debugPrint(
        '[FALLBACK] Successfully mapped ${results.length} restaurants (enriched)',
      );
      return results;
    } catch (e, stack) {
      debugPrint('[FALLBACK] Error parsing fallback shopList: $e');
      debugPrint(stack.toString());
      return [];
    }
  }

  Future<TrendingSectionDto> _getFallbackTrending() async {
    await _ensureFallbackLoaded();
    
    // 1. Try to use dedicated 'trending' key from primary fallback
    if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('trending')) {
      try {
        final trendingRaw = _primaryFallbackData!['trending'];
        final List<TrendingItemDto> items = [];
        final itemsRaw = trendingRaw['items'] as List?;
        
        if (itemsRaw != null) {
          debugPrint('[FALLBACK] Using primary trending items (${itemsRaw.length})');
          for (final item in itemsRaw) {
            if (item is! Map<String, dynamic>) continue;
            items.add(TrendingItemDto(
              id: int.tryParse(item['id']?.toString() ?? '') ?? 0,
              name: item['name'] as String? ?? item['title'] as String? ?? 'Item',
              imageUrl: item['imageUrl'] as String? ?? item['imagePath'] as String? ?? '',
              shopId: int.tryParse(item['shopId']?.toString() ?? '') ?? 0,
              shopName: item['shopName'] as String? ?? 'Restaurant',
              price: _parsePrice(item['price']),
              originalPrice: item['originalPrice'] != null ? _parsePrice(item['originalPrice']) : null,
              displayPrice: item['displayPrice'] as String?,
              currency: item['currency'] as String? ?? '฿',
              rating: (item['rating'] ?? 0.0).toDouble(),
              reviewCount: item['reviewCount'] ?? 0,
              distanceKm: (item['shopDistanceKm'] ?? item['distanceKm'] ?? 0.0).toDouble(),
              estimatedTime: item['shopEstimatedTime'] as String? ?? item['estimatedTime'] as String? ?? '',
              isFavorite: item['isFavorite'] == true,
            ));
          }
          if (items.isNotEmpty) {
            return TrendingSectionDto(
              title: trendingRaw['title'] as String? ?? 'Trending Near By',
              description: trendingRaw['description'] as String? ?? 'Popular picks near you',
              items: items,
              totalCount: items.length,
            );
          }
        }
      } catch (e) {
        debugPrint('[FALLBACK] Error parsing primary trending: $e');
      }
    }

    // 2. Fallback to existing shop-based logic
    debugPrint('[FALLBACK] Falling back to shop-based trending selection');
    final trendingShops = await getTrendingShops();
    final List<TrendingItemDto> items = [];

    for (final shop in trendingShops) {
      MenuItemDto? featuredDish;
      if (shop.hotDeals.isNotEmpty) {
        featuredDish = shop.hotDeals.first;
      } else if (shop.popularDishes.isNotEmpty) {
        featuredDish = shop.popularDishes.first;
      } else if (shop.recommendations.isNotEmpty) {
        featuredDish = shop.recommendations.first;
      }

      if (featuredDish != null) {
        items.add(TrendingItemDto(
          id: int.tryParse(featuredDish.id) ?? 0,
          name: featuredDish.title,
          imageUrl: featuredDish.imagePath,
          shopId: int.tryParse(shop.id) ?? 0,
          shopName: shop.name,
          price: featuredDish.price,
          rating: shop.rating,
          reviewCount: shop.reviewCount,
          isFavorite: false,
          currency: featuredDish.currency,
          distanceKm: _parseDistance(shop.distance) ?? 0,
          estimatedTime: shop.deliveryTime,
          originalPrice: featuredDish.originalPrice,
          displayPrice: featuredDish.displayPrice,
        ));
      } else {
        items.add(TrendingItemDto(
          id: int.tryParse(shop.id) ?? 0,
          name: shop.name,
          imageUrl: shop.imagePath,
          shopId: int.tryParse(shop.id) ?? 0,
          shopName: shop.name,
          price: 0,
          rating: shop.rating,
          reviewCount: shop.reviewCount,
          isFavorite: false,
          currency: '฿',
          distanceKm: _parseDistance(shop.distance) ?? 0,
          estimatedTime: shop.deliveryTime,
        ));
      }
    }

    return TrendingSectionDto(
      title: 'Trending Near By',
      description: 'Popular picks near you',
      items: items,
      totalCount: items.length,
    );
  }

  Future<ShopFeedSectionDto> _getFallbackFeed(
    String feedType, {
    int? shopId,
  }) async {
    await _ensureFallbackLoaded();
    
    // Check primary data first
    if (_primaryFallbackData != null) {
      // New structure: Get from shopDetails
      if (_primaryFallbackData!.containsKey('shopDetails')) {
        final detailsList = _primaryFallbackData!['shopDetails'] as List?;
        if (detailsList != null) {
          final List<ShopFeedItemDto> feedItems = [];
          
          for (final detail in detailsList) {
            final data = detail['data'] as Map<String, dynamic>?;
            if (data == null) continue;

            final currentShopId = data['id'];
            if (shopId != null && currentShopId.toString() != shopId.toString()) {
              continue;
            }

            // Collect all dishes
            for (final k in ['popularDishes', 'recommendations', 'hotDeals']) {
              final list = data[k] as List?;
              if (list != null) {
                for (final item in list) {
                  final dto = MenuItemDto.fromDishJson(item);
                  feedItems.add(
                    ShopFeedItemDto(
                      id: int.tryParse(dto.id) ?? 0,
                      name: dto.title,
                      imageUrl: dto.imagePath,
                      price: dto.price,
                      originalPrice: dto.originalPrice,
                      rating: dto.rating,
                      reviewCount: dto.reviewCount,
                      shopId: int.tryParse(dto.restaurantId) ?? 0,
                      shopName: dto.restaurantName,
                      isFavorite: dto.isFavorite,
                      currency: dto.currency,
                      displayPrice: dto.displayPrice,
                      distanceKm: dto.distanceKm ?? 0,
                      estimatedTime: dto.estimatedTime ?? '',
                      deliveryFee: dto.deliveryFee ?? '',
                    ),
                  );
                }
              }
            }
          }

          if (feedItems.isNotEmpty) {
            // Deduplicate
            final seenIds = <int>{};
            final uniqueItems = feedItems.where((item) => seenIds.add(item.id)).toList();
            
            // Randomize and filter based on feedType if needed
            // For now, simple variety logic
            uniqueItems.shuffle(Random(feedType.hashCode));
            
            final selectedItems = uniqueItems.take(8).toList();

            return ShopFeedSectionDto(
              title: _getTitleForFeedType(feedType),
              items: selectedItems,
            );
          }
        }
      }

      // Old compatibility structure
      if (_primaryFallbackData!.containsKey('menuItems')) {
        final menuItems = _primaryFallbackData!['menuItems'] as List?;
        if (menuItems != null) {
          final List<ShopFeedItemDto> feedItems = [];
          for (final item in menuItems) {
            if (item is Map<String, dynamic> && item['_comment'] == null) {
              if (shopId != null && item['shopId']?.toString() != shopId.toString()) {
                continue;
              }

              final itemId = int.tryParse(item['id']?.toString() ?? '') ?? 0;
              feedItems.add(
                ShopFeedItemDto(
                  id: itemId,
                  name: item['nameEn'] as String? ?? item['nameMm'] as String? ?? '',
                  imageUrl: item['imageUrl'] as String?,
                  price: _parsePrice(item['price']),
                  originalPrice: item['originalPrice'] != null ? _parsePrice(item['originalPrice']) : null,
                  rating: _parsePrice(item['rating'] ?? 0),
                  reviewCount: item['reviewCount'] ?? 0,
                  shopId: int.tryParse(item['shopId']?.toString() ?? '') ?? 0,
                  shopName: item['shopName'] as String? ?? '',
                  isFavorite: false,
                  currency: '฿',
                  displayPrice: item['displayPrice'] as String?,
                  distanceKm: 0,
                  estimatedTime: '',
                  deliveryFee: '',
                ),
              );
            }
          }
          if (feedItems.isNotEmpty) {
            feedItems.shuffle();
            final offset = _getOffsetForFeedType(feedType);
            final start = offset % feedItems.length;
            final selectedItems = [
              ...feedItems.skip(start),
              ...feedItems.take(start),
            ].take(8).toList();
            
            return ShopFeedSectionDto(
              title: _getTitleForFeedType(feedType),
              items: selectedItems,
            );
          }
        }
      }
    }

    final List<ShopFeedItemDto> feedItems = [];

    try {
      if (_fallbackData != null &&
          _fallbackData!.isNotEmpty &&
          _fallbackData!.containsKey('shopDetails')) {
        final detailsList = _fallbackData!['shopDetails'] as List?;

        if (detailsList != null && detailsList.isNotEmpty) {
          final keys = _getKeysForFeedType(feedType);
          List shuffledDetails;

          if (shopId != null) {
            debugPrint('[FALLBACK] Searching for shopId: $shopId');
            final specificShop = detailsList.firstWhere(
              (item) =>
                  item is Map<String, dynamic> &&
                  item['data']?['id']?.toString() == shopId.toString(),
              orElse: () => null,
            );
            if (specificShop == null) {
              debugPrint('[FALLBACK] Shop with ID $shopId NOT found in fallback JSON');
            } else {
              debugPrint('[FALLBACK] Found shop in fallback JSON: ${specificShop['data']?['name']}');
            }
            shuffledDetails = specificShop != null ? [specificShop] : [];
          } else {
            shuffledDetails = List.from(detailsList)..shuffle();
          }

          for (final detail in shuffledDetails) {
            if (detail is! Map<String, dynamic>) continue;
            final data = detail['data'] as Map<String, dynamic>?;
            if (data == null) continue;

            final currentShopId = data['id'] ?? 0;
            final shopName =
                data['nameEn'] as String? ??
                data['name'] as String? ??
                data['nameMm'] as String? ??
                '';
            final shopDistance = data['distance']?.toString();
            final shopEstimatedTime = data['estimatedTime']?.toString();
            final shopDeliveryFee =
                data['displayBaseDeliveryFee']?.toString() ??
                data['displayDeliveryFee']?.toString();

            // Unified item pool for the shop to ensure variety across sections
            final List<dynamic> rawAllItems = [];
            if (shopId != null) {
              // Aggregate all available items for THIS shop to partition them
              for (final k in ['popularDishes', 'recommendations', 'hotDeals']) {
                final list = data[k] as List?;
                if (list != null) rawAllItems.addAll(list);
              }
            } else {
              // Original logic for Food Tab (mix styles): use feedType keys
              for (final key in keys) {
                final list = data[key] as List?;
                if (list != null) rawAllItems.addAll(list);
              }
            }

            if (rawAllItems.isEmpty) continue;

            // Deduplicate items by ID
            final Map<String, dynamic> uniqueItemsMap = {};
            for (final item in rawAllItems) {
              if (item is Map<String, dynamic>) {
                final id = item['id']?.toString() ?? '';
                if (id.isNotEmpty) uniqueItemsMap[id] = item;
              }
            }

            final List<dynamic> uniqueRawItems = uniqueItemsMap.values.toList();
            
            // Randomize selection
            // Use currentShopId as seed to keep it stable but unique to the shop
            final seed = currentShopId is int ? currentShopId : (int.tryParse(currentShopId.toString()) ?? 0);
            uniqueRawItems.shuffle(Random(seed));

            // Partition logic when shopId is provided to avoid section duplicates
            List<dynamic> selectedItems;
            if (shopId != null && uniqueRawItems.length > 3) {
              final offset = _getOffsetForFeedType(feedType);
              final start = offset % uniqueRawItems.length;
              debugPrint('[FALLBACK] Section $feedType using offset $offset/${uniqueRawItems.length} items');
              // Create a rotated/slotted view — enough items to fill the grid
              selectedItems = [
                ...uniqueRawItems.skip(start),
                ...uniqueRawItems.take(start),
              ].take(8).toList();
            } else if (shopId == null) {
              // Food Tab: take 4 items per shop so each section can show a 2×2 grid
              selectedItems = uniqueRawItems.take(4).toList();
            } else {
              selectedItems = uniqueRawItems;
            }

            debugPrint('[FALLBACK] $feedType → ${selectedItems.length} items selected');

            for (final item in selectedItems) {
              if (item is! Map<String, dynamic>) continue;
              try {
                final itemId =
                    int.tryParse(item['id']?.toString() ?? '') ?? 0;

                feedItems.add(
                  ShopFeedItemDto(
                    id: itemId,
                    name:
                        item['title'] as String? ??
                        item['nameEn'] as String? ??
                        item['name'] as String? ??
                        '',
                    imageUrl:
                        item['imagePath'] as String? ??
                        item['imageUrl'] as String?,
                    price: _parsePrice(item['price']),
                    originalPrice: item['originalPrice'] != null
                        ? _parsePrice(item['originalPrice'])
                        : null,
                    rating: _parsePrice(item['rating'] ?? 0),
                    reviewCount: item['reviewCount'] ?? 0,
                    shopId: currentShopId is int
                        ? currentShopId
                        : (int.tryParse(currentShopId.toString()) ?? 0),
                    shopName: shopName,
                    isFavorite: item['isFavorite'] ?? false,
                    currency: item['currency'] as String? ?? '฿',
                    displayPrice: item['displayPrice'] as String?,
                    distanceKm: _parseDistance(
                      item['distanceKm'] ??
                          item['shopDistanceKm'] ??
                          shopDistance,
                    ),
                    estimatedTime:
                        item['estimatedTime']?.toString() ??
                        item['shopEstimatedTime']?.toString() ??
                        shopEstimatedTime,
                    deliveryFee: _parseDeliveryFee(item) ?? shopDeliveryFee,
                  ),
                );
              } catch (e) {
                // Skip invalid items
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[FALLBACK] Error in _getFallbackFeed: $e');
    }

    if (feedItems.isNotEmpty) {
      return ShopFeedSectionDto(
        title: _getTitleForFeedType(feedType),
        items: feedItems,
      );
    }

    // Always return hardcoded fallback to ensure we have data
    return _getHardcodedFallbackFeed(feedType);
  }

  int _getOffsetForFeedType(String feedType) {
    switch (feedType) {
      case 'right-now': return 0;
      case 'for-you': return 2;
      case 'hot-deals': return 4;
      case 'trending': return 6;
      case 'popular-dishes': return 8;
      default: return 0;
    }
  }

  String _getTitleForFeedType(String feedType) {
    switch (feedType) {
      case 'trending':
        return 'Trending Now';
      case 'right-now':
        return 'Order Right Now';
      case 'popular-dishes':
        return 'Popular Dishes';
      case 'hot-deals':
        return 'Hot Deals';
      case 'for-you':
        return 'For You';
      case 'recommendations':
        return 'Recommendations';
      default:
        return 'Delicious Food';
    }
  }

  List<String> _getKeysForFeedType(String feedType) {
    switch (feedType) {
      case 'popular-dishes':
        return ['popularDishes'];
      case 'hot-deals':
        return ['hotDeals'];
      case 'recommendations':
      case 'for-you':
        return ['recommendations'];
      case 'right-now':
        return ['popularDishes', 'recommendations'];
      case 'trending':
        return ['popularDishes', 'recommendations', 'hotDeals'];
      default:
        return ['popularDishes', 'recommendations', 'hotDeals'];
    }
  }

  double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double? _parseDistance(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
    }
    return null;
  }

  String? _parseDeliveryFee(Map<String, dynamic> json) {
    if (json['displayBaseDeliveryFee'] != null) {
      return json['displayBaseDeliveryFee'] as String;
    }
    if (json['displayDeliveryFee'] != null) {
      return json['displayDeliveryFee'] as String;
    }
    return null;
  }

  Future<List<Restaurant>> getPopularShops() async {
    final shops = await _getFallbackShops();
    // Return shops with rating >= 4.4 or just a sorted list
    final popular = shops.where((s) => s.rating >= 4.4).toList();
    
    popular.sort((a, b) {
      final aIsPrimary = _primaryShopIds.contains(a.id);
      final bIsPrimary = _primaryShopIds.contains(b.id);
      
      if (aIsPrimary && !bIsPrimary) return -1;
      if (!aIsPrimary && bIsPrimary) return 1;
      
      // Secondary sort: Rating
      return b.rating.compareTo(a.rating);
    });
    
    return popular.take(10).toList();
  }

  Future<List<MenuItemDto>> getTogetherDeals() async {
    await _ensureFallbackLoaded();
    final List<MenuItemDto> deals = [];
    
    // Check both JSONs for items with originalPrice > price
    final List<Map<String, dynamic>> sources = [];
    if (_primaryFallbackData != null) sources.add(_primaryFallbackData!);
    if (_fallbackData != null) sources.add(_fallbackData!);

    final Set<String> seenIds = {};

    // Helper to process a list of items and add deals
    void processItemList(List? items, String shopId, String shopName) {
      if (items == null) return;
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        
        final price = _parsePrice(item['price']);
        final originalPriceRaw = item['originalPrice'] ?? item['displayOriginalPrice'];
        final originalPrice = originalPriceRaw != null ? _parsePrice(originalPriceRaw) : null;
        
        if (originalPrice != null && originalPrice > price) {
          final id = item['id']?.toString() ?? '';
          if (seenIds.add(id)) {
            final dto = MenuItemDto.fromDishJson(item);
            deals.add(dto.copyWith(
              restaurantId: shopId.isEmpty ? (item['shopId']?.toString() ?? '0') : shopId,
              restaurantName: shopName.isEmpty ? (item['shopName'] as String? ?? 'Restaurant') : shopName,
              estimatedTime: _formatEstimatedTime(item['estimatedTime'] as String? ?? item['shopEstimatedTime'] as String? ?? ''),
            ));
          }
        }
      }
    }

    // 0. Priority: Check dedicated 'togetherDeals' at root of primary JSON
    if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('togetherDeals')) {
      try {
        final dealsData = _primaryFallbackData!['togetherDeals'];
        final itemsRaw = dealsData['items'] as List?;
        if (itemsRaw != null) {
          debugPrint('[FALLBACK] Using primary togetherDeals items (${itemsRaw.length})');
          for (final item in itemsRaw) {
            if (item is! Map<String, dynamic>) continue;
            final id = item['id']?.toString() ?? '';
            if (seenIds.add(id)) {
               final dto = MenuItemDto.fromDishJson(item);
               deals.add(dto.copyWith(
                 restaurantId: item['restaurantId']?.toString() ?? item['shopId']?.toString() ?? '0',
                 restaurantName: item['restaurantName'] as String? ?? item['shopName'] as String? ?? 'Restaurant',
                 estimatedTime: _formatEstimatedTime(item['estimatedTime'] as String? ?? item['shopEstimatedTime'] as String? ?? ''),
               ));
            }
          }
          if (deals.isNotEmpty) return deals;
        }
      } catch (e) {
        debugPrint('[FALLBACK] Error parsing togetherDeals: $e');
      }
    }

    // 1. Check trending items for deals
    if (_primaryFallbackData != null && _primaryFallbackData?.containsKey('trending') == true) {
      final trendingItems = _primaryFallbackData?['trending']?['items'] as List?;
      processItemList(trendingItems, '', '');
    }

    // 4. Return results if found in primary sources
    if (deals.isNotEmpty) {
      debugPrint('[FALLBACK] Using ${deals.length} deals from primary sources');
      deals.shuffle();
      return deals.take(10).toList();
    }

    // 5. Use hardcoded fallback as last resort if everything else failed
    debugPrint('[FALLBACK] No deals found in JSON primary fallback, using hardcoded TogetherDeals');
    return FallbackData.togetherDeals.map((data) => MenuItemDto(
      id: 'fallback-${data['name']}',
      restaurantId: '0',
      restaurantName: 'Restaurant',
      title: data['name']?.toString() ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (data['originalPrice'] as num?)?.toDouble() ?? 0.0,
      currency: '฿',
      imagePath: data['imagePath']?.toString() ?? '',
      category: '',
    )).toList();
  }

  Future<List<Restaurant>> getTrendingShops() async {
    final shops = await _getFallbackShops();
    // Return a variety of shops, maybe some specific ones or just high rated
    final trending = shops.where((s) => s.rating >= 4.0).toList();
    trending.shuffle(Random(42)); // Seeded for consistency in session
    return trending.take(8).toList();
  }

  ShopFeedSectionDto _getHardcodedFallbackFeed(String feedType) {
    final trendingItems = [
      ShopFeedItemDto(
        id: 101,
        name: 'Crispy Tofu Salad',
        imageUrl:
            'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&h=300&fit=crop',
        price: 130.0,
        rating: 4.6,
        reviewCount: 142,
        shopId: 1,
        shopName: 'Rangoon Tea House',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿130',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 102,
        name: 'Lahpet Thoke (Tea Leaf Salad)',
        imageUrl:
            'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&h=300&fit=crop',
        price: 150.0,
        rating: 4.7,
        reviewCount: 185,
        shopId: 1,
        shopName: 'Rangoon Tea House',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿150',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 103,
        name: 'Shan Noodles (Dry)',
        imageUrl:
            'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&h=300&fit=crop',
        price: 100.0,
        rating: 4.5,
        reviewCount: 88,
        shopId: 2,
        shopName: 'ThaNaKa Myanmar',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿100',
        distanceKm: 1.8,
        estimatedTime: '20-30 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 104,
        name: 'Nan Gyi Thoke',
        imageUrl:
            'https://images.unsplash.com/photo-1511690656952-34342bfca0de?w=400&h=300&fit=crop',
        price: 120.0,
        rating: 4.8,
        reviewCount: 167,
        shopId: 3,
        shopName: 'The Burma Food House',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿120',
        distanceKm: 3.1,
        estimatedTime: '30-40 min',
        deliveryFee: '฿30',
      ),
    ];

    final forYouItems = [
      ShopFeedItemDto(
        id: 201,
        name: 'Masala Myanmar Tea',
        imageUrl:
            'https://images.unsplash.com/photo-1556742502-ec7c0e9f34b6?w=400&h=300&fit=crop',
        price: 50.0,
        rating: 4.2,
        reviewCount: 44,
        shopId: 4,
        shopName: 'Laxmi Myanmar Food',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿50',
        distanceKm: 3.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 202,
        name: 'Bagan Papaya Salad',
        imageUrl:
            'https://images.unsplash.com/photo-1559847844-5315695dadae?w=400&h=300&fit=crop',
        price: 120.0,
        rating: 4.4,
        reviewCount: 78,
        shopId: 5,
        shopName: 'Bagan Myay',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿120',
        distanceKm: 4.5,
        estimatedTime: '35-45 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 203,
        name: 'Mont Di (Fish Gravy Noodle)',
        imageUrl:
            'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400&h=300&fit=crop',
        price: 120.0,
        rating: 4.5,
        reviewCount: 71,
        shopId: 5,
        shopName: 'Bagan Myay',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿120',
        distanceKm: 4.5,
        estimatedTime: '35-45 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 204,
        name: 'Mote Hin Gar (Classic Mohinga)',
        imageUrl:
            'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400&h=300&fit=crop',
        price: 110.0,
        rating: 4.7,
        reviewCount: 203,
        shopId: 6,
        shopName: 'Feel Restaurant',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿110',
        distanceKm: 5.2,
        estimatedTime: '30-45 min',
        deliveryFee: '฿30',
      ),
    ];

    final hotDealsItems = [
      ShopFeedItemDto(
        id: 301,
        name: 'Rangoon Signature Milk Tea',
        imageUrl:
            'https://images.unsplash.com/photo-1556742502-ec7c0e9f34b6?w=400&h=300&fit=crop',
        price: 80.0,
        originalPrice: 100.0,
        rating: 4.6,
        reviewCount: 205,
        shopId: 1,
        shopName: 'Rangoon Tea House',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿80',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 302,
        name: 'Slow-Braised Pork Belly Curry',
        imageUrl:
            'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=400&h=300&fit=crop',
        price: 220.0,
        originalPrice: 260.0,
        rating: 4.5,
        reviewCount: 134,
        shopId: 1,
        shopName: 'Rangoon Tea House',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿220',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 303,
        name: 'Steamed Seabass Kachin Style',
        imageUrl:
            'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&h=300&fit=crop',
        price: 350.0,
        originalPrice: 400.0,
        rating: 4.9,
        reviewCount: 76,
        shopId: 1,
        shopName: 'Rangoon Tea House',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿350',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 304,
        name: 'Tandoori Chicken Half',
        imageUrl:
            'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=400&h=300&fit=crop',
        price: 180.0,
        originalPrice: 220.0,
        rating: 4.5,
        reviewCount: 64,
        shopId: 4,
        shopName: 'Laxmi Myanmar Food',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿180',
        distanceKm: 3.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
    ];

    final rightNowItems = [
      ShopFeedItemDto(
        id: 401,
        name: 'Chicken Potato Curry',
        imageUrl:
            'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=400&h=300&fit=crop',
        price: 130.0,
        rating: 4.3,
        reviewCount: 66,
        shopId: 2,
        shopName: 'ThaNaKa Myanmar',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿130',
        distanceKm: 1.8,
        estimatedTime: '20-30 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 402,
        name: 'Wet Thar Hin (Pork Curry)',
        imageUrl:
            'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a?w=400&h=300&fit=crop',
        price: 160.0,
        rating: 4.5,
        reviewCount: 92,
        shopId: 5,
        shopName: 'Bagan Myay',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿160',
        distanceKm: 4.5,
        estimatedTime: '35-45 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 403,
        name: 'Za Lone Rice Salad',
        imageUrl:
            'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&h=300&fit=crop',
        price: 100.0,
        rating: 4.5,
        reviewCount: 87,
        shopId: 6,
        shopName: 'Feel Restaurant',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿100',
        distanceKm: 5.2,
        estimatedTime: '30-45 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 404,
        name: 'Nga Phal Curry (Fish Paste Curry)',
        imageUrl:
            'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=400&h=300&fit=crop',
        price: 130.0,
        rating: 4.3,
        reviewCount: 66,
        shopId: 6,
        shopName: 'Feel Restaurant',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿130',
        distanceKm: 5.2,
        estimatedTime: '30-45 min',
        deliveryFee: '฿30',
      ),
    ];

    final popularDishesItems = [
      ShopFeedItemDto(
        id: 501,
        name: 'Rangoon Signature Mohinga',
        imageUrl:
            'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400&h=300&fit=crop',
        price: 180.0,
        rating: 4.8,
        reviewCount: 210,
        shopId: 1,
        shopName: 'Rangoon Tea House',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿180',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 502,
        name: 'Traditional Tea Leaf Salad',
        imageUrl:
            'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&h=300&fit=crop',
        price: 150.0,
        rating: 4.7,
        reviewCount: 185,
        shopId: 1,
        shopName: 'Rangoon Tea House',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿150',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 503,
        name: 'Shan Style Dry Noodles',
        imageUrl:
            'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&h=300&fit=crop',
        price: 100.0,
        rating: 4.5,
        reviewCount: 88,
        shopId: 2,
        shopName: 'ThaNaKa Myanmar',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿100',
        distanceKm: 1.8,
        estimatedTime: '20-30 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 504,
        name: 'Authentic Nan Gyi Thoke',
        imageUrl:
            'https://images.unsplash.com/photo-1511690656952-34342bfca0de?w=400&h=300&fit=crop',
        price: 120.0,
        rating: 4.8,
        reviewCount: 167,
        shopId: 3,
        shopName: 'The Burma Food House',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿120',
        distanceKm: 3.1,
        estimatedTime: '30-40 min',
        deliveryFee: '฿30',
      ),
    ];

    List<ShopFeedItemDto> items;
    switch (feedType) {
      case 'trending':
        items = trendingItems;
        break;
      case 'for-you':
      case 'recommendations':
        items = forYouItems;
        break;
      case 'hot-deals':
        items = hotDealsItems;
        break;
      case 'right-now':
        items = rightNowItems;
        break;
      case 'popular-dishes':
        items = popularDishesItems;
        break;
      default:
        items = trendingItems;
    }

    items.shuffle();
    return ShopFeedSectionDto(
      items: items.take(4).toList(),
      title: _getTitleForFeedType(feedType),
    );
  }

  Future<List<String>> getRecentDemoSearches() async {
    await _ensureFallbackLoaded();
    // Return a mix of trending names from the fallback data
    final shops = await _getFallbackShops();
    if (shops.isNotEmpty) {
      return shops.take(5).map((s) => s.name).toList();
    }
    return ['KFC', 'Lotteria', 'Tea Shop', 'Shan Noodle', 'Myanmar Cuisine'];
  }

  Future<List<Map<String, String>>> getFallbackCategories() async {
    await _ensureFallbackLoaded();

    // 0. Primary: use the dedicated `categories` array from primary fallback
    if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('categories')) {
      final cats = _primaryFallbackData!['categories'] as List? ?? [];
      if (cats.isNotEmpty) {
        return cats.map((c) {
          final name = c['name']?.toString() ?? '';
          final icon = c['icon']?.toString() ?? _getEmojiForCategory(name.toLowerCase());
          return {'name': name, 'emoji': icon};
        }).where((m) => (m['name'] as String).isNotEmpty).toList();
      }
    }

    // 1. Secondary: use the dedicated `categories` array from secondary fallback
    if (_fallbackData != null && _fallbackData!.containsKey('categories')) {
      final cats = _fallbackData!['categories'] as List? ?? [];
      if (cats.isNotEmpty) {
        return cats.map((c) {
          final name = c['name']?.toString() ?? '';
          final icon = c['icon']?.toString() ?? _getEmojiForCategory(name.toLowerCase());
          return {'name': name, 'emoji': icon};
        }).where((m) => (m['name'] as String).isNotEmpty).toList();
      }
    }

    // Secondary fallback: cuisine types
    if (_fallbackData != null && _fallbackData!.containsKey('cuisineTypes')) {
      final types = _fallbackData!['cuisineTypes'] as List? ?? [];
      return types
          .map(
            (t) => {
              'name': t['nameEn']?.toString() ?? t['nameMm']?.toString() ?? '',
              'emoji': _getEmojiForCategory(t['slug']?.toString() ?? ''),
            },
          )
          .where((m) => (m['name'] as String).isNotEmpty)
          .toList();
    }

    // Final hardcoded fallback
    return [
      {'name': 'Noodles', 'emoji': '🍜'},
      {'name': 'Rice', 'emoji': '🍚'},
      {'name': 'Curries', 'emoji': '🍛'},
      {'name': 'Salads', 'emoji': '🥗'},
      {'name': 'Soups', 'emoji': '🍲'},
      {'name': 'Snacks', 'emoji': '🥟'},
      {'name': 'Beverages', 'emoji': '🧋'},
      {'name': 'Desserts', 'emoji': '🍮'},
      {'name': 'Seafood', 'emoji': '🐟'},
      {'name': 'Sets', 'emoji': '🍱'},
    ];
  }

  String _getEmojiForCategory(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('myanmar')) return '🍛';
    if (lower.contains('shan')) return '🍜';
    if (lower.contains('rakhine')) return '🌶️';
    if (lower.contains('dessert') || lower.contains('sweets')) return '🍰';
    if (lower.contains('cafe') || lower.contains('coffee')) return '☕';
    if (lower.contains('fine dining')) return '🍽️';
    if (lower.contains('home cooking')) return '🏠';
    if (lower.contains('street food')) return '🍢';
    if (lower.contains('noodle')) return '🍜';
    if (lower.contains('salad')) return '🥗';
    if (lower.contains('tea')) return '🍵';
    return '🍴';
  }

  Future<List<Restaurant>> searchFoodOrShop(String query) async {
    debugPrint('[SEARCH] Query: "$query"');
    final allShops = await _getFallbackShops();
    if (query.isEmpty) return allShops;

    final lowercaseQuery = query.toLowerCase().trim();
    final results = allShops.where((shop) {
      final matchesName = shop.name.toLowerCase().contains(lowercaseQuery);
      final matchesCategory = shop.category.toLowerCase().contains(
        lowercaseQuery,
      );
      final matchesDishes = shop.popularDishes.any(
        (dish) =>
            dish.title.toLowerCase().contains(lowercaseQuery) ||
            dish.category.toLowerCase().contains(lowercaseQuery),
      );
      return matchesName || matchesCategory || matchesDishes;
    }).toList();

    debugPrint(
      '[SEARCH] Found ${results.length} matches for "$query" out of ${allShops.length} total shops',
    );
    return results;
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
      final response = await _remoteDataSource
          .getNearbyShops(request)
          .timeout(const Duration(seconds: 4));
      final results = response.data.content
          .map((dto) => _mapShopDtoToDomain(dto))
          .toList();

      // If the API returns success but an empty list, use fallback for better UX
      if (results.isEmpty) {
        return await _getFallbackShops();
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

      // --- FALLBACK TO LOCAL ASSET ON FAILURE ---
      final fallbackResults = await _getFallbackShops();
      if (fallbackResults.isNotEmpty) {
        return fallbackResults;
      }

      // No cache or fallback — let the error propagate
      rethrow;
    }
  }

  Future<Restaurant> getShopById(int id, {double? lat, double? lon}) async {
    try {
      final response = await _remoteDataSource
          .getShopById(id, lat: lat, lon: lon)
          .timeout(const Duration(seconds: 2));
      return _mapShopDetailDtoToDomain(response.data);
    } catch (e) {
      // --- NEW: FALLBACK TO LOCAL ASSET ---
      await _ensureFallbackLoaded();
      
      // 1. Check shopDetails in primary fallback
      if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('shopDetails')) {
        final detailsList = _primaryFallbackData!['shopDetails'] as List?;
        final shopJson = detailsList?.firstWhere(
          (item) => item['data']?['id']?.toString() == id.toString(),
          orElse: () => null,
        );
        if (shopJson != null) {
          try {
            final detailDto = ShopDetailDto.fromJson(shopJson['data']);
            return _mapShopDetailDtoToDomain(detailDto);
          } catch (err) {
            debugPrint('[FALLBACK] Error mapping ShopDetailDto from primary: $err');
          }
        }
      }

      // 2. Check shopList in primary fallback
      if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('shopList')) {
        final content = _primaryFallbackData!['shopList']?['data']?['content'] as List?;
        final shopJson = content?.firstWhere(
          (item) => item['id']?.toString() == id.toString(),
          orElse: () => null,
        );
        if (shopJson != null) {
          return _mapShopDtoToDomain(ShopListItemDto.fromJson(shopJson));
        }
      }
      
      // 3. Compatibility with old structure: shops
      if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('shops')) {
        final shops = _primaryFallbackData!['shops'] as List?;
        if (shops != null) {
          final shopJson = shops.firstWhere(
            (item) => item['id']?.toString() == id.toString(),
            orElse: () => null,
          );
          if (shopJson != null) {
            return _mapPrimaryShopToDomain(shopJson as Map<String, dynamic>);
          }
        }
      }
      
      // 4. Secondary fallback: food_fallback.json
      if (_fallbackData != null && _fallbackData!.containsKey('shopDetails')) {
        final detailsList = _fallbackData!['shopDetails'] as List?;
        if (detailsList != null) {
          final shopJson = detailsList.firstWhere(
            (item) => item['data']?['id']?.toString() == id.toString(),
            orElse: () => null,
          );
          if (shopJson != null) {
            try {
              final detailDto = ShopDetailDto.fromJson(shopJson['data']);
              return _mapShopDetailDtoToDomain(detailDto);
            } catch (err) {
              debugPrint('[FALLBACK] Error mapping ShopDetailDto: $err');
            }
          }
        }
      }

      // 5. Try to construct from shopList if we have it but no detail
      final allShops = await _getFallbackShops();
      try {
        final shop = allShops.firstWhere(
          (r) => r.id == id.toString(),
        );
        
        // If the shop has no dishes, try to find some for it in the JSONs
        if (shop.popularDishes.isEmpty && shop.recommendations.isEmpty) {
           debugPrint('[FALLBACK] Shop ${shop.name} has no dishes, searching for replacements...');
           // This is where we could do extra searching, but for now the hardcoded 
           // enrichment in getFallbackShops (via _mapShopDetailDtoToDomain) should handle it
        }
        return shop;
      } catch (_) {}

      // 6. Last resort: use hardcoded list from FallbackData
      try {
        final hardcoded = FallbackData.restaurants.firstWhere(
          (r) => r.id == id.toString(),
        );
        debugPrint('[FALLBACK] Using hardcoded restaurant data for ID $id');
        return hardcoded;
      } catch (_) {}

      // If we really can't find it, return a generic one to avoid crash
      debugPrint('[FALLBACK] CRITICAL: Restaurant $id not found anywhere. Returning generic.');
      return Restaurant(
        id: id.toString(), 
        name: 'Restaurant', 
        category: 'Food', 
        rating: 4.0, 
        distance: '0 km', 
        imagePath: '', 
        logoPath: '', 
        deliveryTime: '20 min', 
        status: 'Open'
      );
    }
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
    try {
      final result = await _remoteDataSource.getTrendingItems(
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
        page: page,
        size: size,
      );

      if (page == 0) {
        // If API returns empty, use fallback
        if (result.items.isEmpty) {
          final fallbackResult = await _getFallbackTrending();
          _cachedTrending = fallbackResult;
          _trendingLastFetch = now;
          return fallbackResult;
        }

        _cachedTrending = result;
        _trendingLastFetch = now;
      }
      return result;
    } catch (e) {
      if (page == 0) {
        final fallbackResult = await _getFallbackTrending();
        return fallbackResult;
      }
      rethrow;
    }
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
      imagePath =
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=800&auto=format&fit=crop';
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
    'right-now',
    'for-you',
    'hot-deals',
    'trending',
    'popular-dishes',
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
    final key = 'shop-$shopId-$feedType';

    if (_feedCache.containsKey(key)) return _feedCache[key]!;

    try {
      final result = await _remoteDataSource
          .getShopFeed(shopId: shopId, feedType: feedType)
          .timeout(const Duration(milliseconds: 1500));
      if (result.items.isNotEmpty) {
        _feedCache[key] = result;
        return result;
      }
    } catch (e) {
      debugPrint('[FEED] Failed to get shop feed: $e, using fallback');
    }

    final fallback = await _getFallbackFeed(feedType, shopId: shopId);
    _feedCache[key] = fallback;
    return fallback;
  }

  Future<ShopFeedSectionDto> getFoodTabFeed({
    required String feedType,
    required double lat,
    required double lon,
    double radiusKm = 10.0,
  }) async {
    try {
      final key = 'food-tab-$feedType';
      final now = DateTime.now();
      final cached = _feedCache[key];
      final cacheTime = _feedCacheTime[key];
      if (cached != null &&
          cacheTime != null &&
          now.difference(cacheTime).inMinutes < 5) {
        return cached;
      }
      final result = await _remoteDataSource
          .getFoodTabFeed(feedType: feedType, lat: lat, lon: lon, radiusKm: radiusKm)
          .timeout(const Duration(milliseconds: 1500));

      if (result.items.isEmpty) {
        final fallback = await _getFallbackFeed(feedType);
        _feedCache[key] = fallback;
        _feedCacheTime[key] = now;
        return fallback;
      }

      _feedCache[key] = result;
      _feedCacheTime[key] = now;
      return result;
    } catch (e) {
      debugPrint('[FEED] Failed to get food tab feed: $e, using fallback');
      return await _getFallbackFeed(feedType);
    }
  }

  Future<FoodDetailDto?> getFoodById(int id) async {
    try {
      return await _remoteDataSource
          .getFoodById(id)
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      // --- NEW: FALLBACK TO LOCAL ASSET ---
      await _ensureFallbackLoaded();

      // 1. Check shopDetails in primary fallback
      if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('shopDetails')) {
        final detailsList = _primaryFallbackData!['shopDetails'] as List?;
        if (detailsList != null) {
          for (final detail in detailsList) {
            final data = detail['data'] as Map<String, dynamic>?;
            if (data == null) continue;

            final shopName = data['nameEn'] ?? data['name'] ?? '';
            final cuisineTypeJson = data['cuisineType'];

            for (final k in ['popularDishes', 'recommendations', 'hotDeals']) {
              final list = data[k] as List?;
              if (list != null) {
                final itemJson = list.firstWhere(
                  (item) => item['id']?.toString() == id.toString(),
                  orElse: () => null,
                );
                if (itemJson != null) {
                  final itemData = Map<String, dynamic>.from(itemJson as Map);
                  itemData['shopName'] = shopName;
                  itemData['cuisineType'] = cuisineTypeJson;
                  return FoodDetailDto.fromJson(itemData);
                }
              }
            }
          }
        }
      }

      // 2. Check old structure: menuItems
      if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('menuItems')) {
        final items = _primaryFallbackData!['menuItems'] as List?;
        final itemJson = items?.firstWhere(
          (item) => item is Map<String, dynamic> && item['id']?.toString() == id.toString(),
          orElse: () => null,
        );

        if (itemJson != null) {
          // Enrich with shop info from the same file
          final shopId = int.tryParse(itemJson['shopId']?.toString() ?? '');
          String? shopName;
          Map<String, dynamic>? cuisineTypeJson;

          if (shopId != null && _primaryFallbackData!.containsKey('shops')) {
            final shops = _primaryFallbackData!['shops'] as List?;
            final shop = shops?.firstWhere(
              (s) => s['id']?.toString() == shopId.toString(),
              orElse: () => null,
            );
            if (shop != null) {
              shopName = shop['name'];
              cuisineTypeJson = {
                'id': 1,
                'nameEn': shop['cuisineType'] ?? 'Myanmar',
              };
            }
          }

          final data = Map<String, dynamic>.from(itemJson as Map);
          data['shopName'] = shopName;
          data['cuisineType'] = cuisineTypeJson;
          return FoodDetailDto.fromJson(data);
        }
      }

      // 3. Check Secondary Fallback (food_fallback.json)
      if (_fallbackData != null && _fallbackData!.containsKey('foodDetails')) {
        final foodList = _fallbackData!['foodDetails'] as List?;
        final foodJson = foodList?.firstWhere(
          (item) => item['data']?['id']?.toString() == id.toString(),
          orElse: () => null,
        );
        if (foodJson != null) {
          return FoodDetailDto.fromJson(foodJson['data']);
        }
      }
      return null;
    }
  }

  // ── Reviews ─────────────────────────────────────────────────────────────
  
  Future<Map<String, dynamic>?> getShopReviews(int shopId) async {
    await _ensureFallbackLoaded();
    
    // 1. Check shopDetails in primary fallback
    if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('shopDetails')) {
      final detailsList = _primaryFallbackData!['shopDetails'] as List?;
      if (detailsList != null) {
        final shopJson = detailsList.firstWhere(
          (item) => item['data']?['id']?.toString() == shopId.toString(),
          orElse: () => null,
        );
        if (shopJson != null && shopJson['data']?['reviews'] != null) {
          return shopJson['data']['reviews'] as Map<String, dynamic>;
        }
      }
    }

    // 2. Check shopDetails in secondary fallback
    if (_fallbackData != null && _fallbackData!.containsKey('shopDetails')) {
      final detailsList = _fallbackData!['shopDetails'] as List?;
      if (detailsList != null) {
        final shopJson = detailsList.firstWhere(
          (item) => item['data']?['id']?.toString() == shopId.toString(),
          orElse: () => null,
        );
        if (shopJson != null && shopJson['data']?['reviews'] != null) {
          return shopJson['data']['reviews'] as Map<String, dynamic>;
        }
      }
    }

    // 3. Compatibility with old structure: shops
    if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('shops')) {
      final shops = _primaryFallbackData!['shops'] as List?;
      if (shops != null) {
        final shopJson = shops.firstWhere(
          (item) => item['id']?.toString() == shopId.toString(),
          orElse: () => null,
        );
        if (shopJson != null && shopJson['reviews'] != null) {
          return shopJson['reviews'] as Map<String, dynamic>;
        }
      }
    }

    // Default to empty structure to prevent crashes with ! operator in UI
    return {
      'totalReviews': 0,
       'averageRating': 0.0,
       'items': [],
       'content': [],
    };
  }

  Future<List<CategoryDto>> getCategories() async {
    await _ensureFallbackLoaded();
    if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('categories')) {
      final list = _primaryFallbackData!['categories'] as List?;
      if (list != null) {
        return list.map((e) => CategoryDto.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    
    // Fallback categories if JSON doesn't have them
    return [
      CategoryDto(id: 1, name: 'Noodles', icon: '🍜', slug: 'noodles'),
      CategoryDto(id: 2, name: 'Rice', icon: '🍚', slug: 'rice'),
      CategoryDto(id: 3, name: 'Curries', icon: '🍛', slug: 'curries'),
    ];
  }

  Future<List<CuisineTypeDto>> getCuisineTypes() async {
    await _ensureFallbackLoaded();
    if (_primaryFallbackData != null && _primaryFallbackData!.containsKey('cuisineTypes')) {
      final list = _primaryFallbackData!['cuisineTypes'] as List?;
      if (list != null) {
        return list.map((e) => CuisineTypeDto.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    return [];
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

  String _formatEstimatedTime(String time) {
    if (time.isEmpty) return '20';
    // Remove 'min' or 'mins' if present to avoid 'minmin' in UI
    return time.replaceAll(RegExp(r'\s*mins?'), '').trim();
  }
}
