import 'package:dio/dio.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import '../../../../core/auth/auth_service.dart';
import 'models/banner_image_dto.dart';
import 'models/shop_dto.dart';
import 'models/trending_item_dto.dart';
import 'models/shop_feed_item_dto.dart';
import 'models/food_detail_dto.dart';
import 'models/shop_review_dto.dart';

import 'shop_storage.dart';

class RemoteRestaurantDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<List<BannerImageDto>> getBanners({String? position}) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.baseUrl}${ApiClient.apiPrefix}/banners',
        queryParameters: position != null ? {'position': position} : null,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => BannerImageDto.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load banners: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<ApiResponseSliceShopListDto> getNearbyShops(ShopRequestDto request) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.baseUrl}${ApiClient.apiPrefix}/shops/nearby',
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
      final response = await _apiClient.dio.get(
        '${ApiClient.baseUrl}${ApiClient.apiPrefix}/shops/$id',
        queryParameters: {
          'lat': lat,
          'lon': lon,
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

  Future<TrendingSectionDto> getTrendingItems({
    required double lat,
    required double lon,
    double radiusKm = 10.0,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.baseUrl}${ApiClient.apiPrefix}/feed/trending-items',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'radiusKm': radiusKm,
        'page': page,
        'size': size,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return TrendingSectionDto.fromJson(data);
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
      final response = await _apiClient.dio.get(
        '${ApiClient.baseUrl}${ApiClient.apiPrefix}/shops/$shopId/feed/$feedType',
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
  }) async {
    if (!AuthService().isLoggedIn) {
      return ShopFeedSectionDto(items: []);
    }

    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.baseUrl}${ApiClient.apiPrefix}/menu/feed/$feedType',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'radiusKm': radiusKm,
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

  Future<FoodDetailDto?> getFoodById(int id) async {
    try {
      final response = await _apiClient.dio.get('${ApiClient.baseUrl}${ApiClient.apiPrefix}/foods/$id');
      if (response.statusCode == 200) {
        final apiResponse = ApiResponseFoodDetailDto.fromJson(response.data);
        return apiResponse.data;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  Future<void> addShopFavorite(int shopId) async {
    await _apiClient.dio.post('${ApiClient.baseUrl}${ApiClient.apiPrefix}/user/favorites/shop/$shopId');
  }

  Future<void> removeShopFavorite(int shopId) async {
    await _apiClient.dio.delete('${ApiClient.baseUrl}${ApiClient.apiPrefix}/user/favorites/shop/$shopId');
  }

  Future<void> addMenuFavorite(int menuItemId) async {
    await _apiClient.dio.post('${ApiClient.baseUrl}${ApiClient.apiPrefix}/user/favorites/menu-item/$menuItemId');
  }

  Future<void> removeMenuFavorite(int menuItemId) async {
    await _apiClient.dio.delete('${ApiClient.baseUrl}${ApiClient.apiPrefix}/user/favorites/menu-item/$menuItemId');
  }

  Future<void> trackConversion(int shopId, String action) async {
    try {
      await _apiClient.dio.post(
        '${ApiClient.apiPrefix}/shops/$shopId/track',
        data: {'action': action},
      );
    } catch (e) {
      // Ignore non-critical tracking errors
    }
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Future<List<ShopReviewDto>> getShopReviews(int shopId) async {
    try {
      final response = await _apiClient.dio.get('${ApiClient.apiPrefix}/shops/$shopId/reviews');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => ShopReviewDto.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<ShopReviewSummaryDto> getShopReviewSummary(int shopId) async {
    try {
      final response = await _apiClient.dio.get('${ApiClient.apiPrefix}/shops/$shopId/reviews/summary');
      if (response.statusCode == 200) {
        return ShopReviewSummaryDto.fromJson(response.data);
      }
      throw Exception('Failed to load review summary');
    } catch (e) {
      rethrow;
    }
  }
}
