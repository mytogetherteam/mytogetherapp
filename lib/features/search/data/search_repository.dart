import 'package:dio/dio.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_client.dart';
import '../../home/data/models/shop_dto.dart';
import '../../home/data/models/trending_item_dto.dart';
import 'models/search_shop_dto.dart';
import 'models/search_filters.dart';
import 'models/location_ref_dto.dart';

/// Talks to the authenticated user search & shop-profile endpoints on the
/// NestJS backend (`dev` branch):
///   GET /api/user/search
///   GET /api/user/search/nearby
///   GET /api/user/menu-items/search
///   GET /api/user/shop-profile/popular
class SearchRepository {
  static final SearchRepository instance = SearchRepository._internal();
  SearchRepository._internal();

  final ApiClient _apiClient = ApiClient();

  bool get _isLoggedIn => AuthService().isLoggedIn;

  /// Full shop search with optional text query, preview menu items, and
  /// optional dietary / rating / category filters supported by
  /// `GET /api/user/search` on the backend.
  Future<SearchPageResult> searchShops({
    required double latitude,
    required double longitude,
    String? search,
    double? radiusKm,
    int page = 1,
    int size = 20,
    SearchFilters? filters,
  }) async {
    _requireAuth();
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/search',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': ?radiusKm,
        if (search != null && search.trim().isNotEmpty) ...{
          'search': search.trim(),
          'q': search.trim(),
          'keyword': search.trim(),
        },
        'page': page,
        'size': size,
        ...?filters?.toQueryParameters(),
      },
    );
    return SearchPageResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Trending shops ranked by completed (DELIVERED) order count in the last
  /// `days`. Backend: `GET /api/user/shop-profile/trending`.
  Future<SearchPageResult> getTrendingShops({
    int page = 1,
    int size = 10,
    int? days,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/shop-profile/trending',
      queryParameters: {
        'page': page,
        'size': size,
        'days': ?days,
      },
    );
    return SearchPageResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Trending menu items in nearby shops for the current meal type.
  /// Backend: `GET /api/user/search/trending-nearby`.
  /// `timeZone` maps to the `X-Timezone` header used to pick the meal type;
  /// falls back to Asia/Bangkok server-side when omitted.
  Future<TrendingSectionDto> searchTrendingNearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
    String? timeZone,
    int page = 1,
    int size = 10,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/search/trending-nearby',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': ?radiusKm,
        'page': page,
        'size': size,
      },
      options: timeZone != null
          ? Options(headers: {'X-Timezone': timeZone})
          : null,
    );
    return TrendingSectionDto.fromTrendingNearbyResponse(
      response.data as Map<String, dynamic>,
    );
  }

  /// Nearby shops sorted by rating (no text query).
  Future<SearchPageResult> searchNearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
    int page = 1,
    int size = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/search/nearby',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': ?radiusKm,
        'page': page,
        'size': size,
      },
    );
    return SearchPageResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Text search across published menu items.
  Future<List<MenuItemSearchResultDto>> searchMenuItems({
    required String query,
    int? shopId,
  }) async {
    _requireAuth();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/menu-items/search',
      queryParameters: {
        'q': trimmed,
        'shopId': ?shopId,
      },
    );

    final raw = response.data;
    final List<dynamic> data = raw is Map && raw['data'] is List
        ? raw['data'] as List
        : (raw is List ? raw : const []);

    return data
        .map((e) => MenuItemSearchResultDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Popular shops ranked by order demand + Bayesian rating.
  Future<SearchPageResult> getPopularShops({
    int page = 1,
    int size = 10,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/shop-profile/popular',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
    return SearchPageResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Paginated catalog of user-visible shops (active, verified, open).
  /// Backend: `GET /api/user/shop-profile` (UserShopProfileController.findAll).
  /// Supports server-side `search` and `categoryId` filtering.
  Future<SearchPageResult> listShopProfiles({
    String? search,
    int? categoryId,
    int page = 1,
    int size = 20,
  }) async {
    _requireAuth();
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/shop-profile',
      queryParameters: {
        'page': page,
        'size': size,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'categoryId': ?categoryId,
      },
    );
    return SearchPageResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// A single user-visible shop by id (enriched + isFavorite).
  /// Backend: `GET /api/user/shop-profile/:id` (UserShopProfileController.findOne).
  /// Returns null when the response body has no usable `data` object.
  Future<ShopListItemDto?> getShopProfileById(int id) async {
    final shop = await getShopProfileRawById(id);
    if (shop == null) return null;
    return ShopListItemDto.fromJson(shop);
  }

  /// Raw enriched shop profile payload from `GET /api/user/shop-profile/:id`.
  Future<Map<String, dynamic>?> getShopProfileRawById(int id) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/shop-profile/$id',
    );
    final body = response.data;
    final shop = body is Map ? body['data'] : null;
    if (shop is Map<String, dynamic>) {
      return shop;
    }
    return null;
  }

  /// Full shop detail for restaurant pages (`ShopDetailDto`).
  Future<ShopDetailDto?> getShopDetailById(
    int id, {
    double? distanceKm,
  }) async {
    final shop = await getShopProfileRawById(id);
    if (shop == null) return null;
    return ShopDetailDto.fromUserProfileJson(shop, distanceKm: distanceKm);
  }

  /// Active cuisine types for search filters.
  /// Backend: `GET /api/user/cuisine-types` (UserCuisineController).
  /// Paginated envelope: `{ data: { content: [...], totalElements, ... } }`.
  Future<List<CuisineTypeDto>> listCuisineTypes({
    int page = 1,
    int size = 200,
    String? search,
  }) async {
    _requireAuth();
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/cuisine-types',
      queryParameters: {
        'page': page,
        'size': size,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return _parseLocationContent(response.data)
        .map(CuisineTypeDto.fromJson)
        .toList();
  }

  /// Active cities for filters/forms.
  /// Backend: `GET /api/user/cities` (UserCitiesController).
  Future<List<CityDto>> listCities({
    int page = 1,
    int size = 200,
    String? search,
  }) async {
    _requireAuth();
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/cities',
      queryParameters: {
        'page': page,
        'size': size,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return _parseLocationContent(response.data).map(CityDto.fromJson).toList();
  }

  /// Active districts (optionally filtered by [cityId]).
  /// Backend: `GET /api/user/districts` (UserDistrictsController).
  Future<List<DistrictDto>> listDistricts({
    int? cityId,
    int page = 1,
    int size = 200,
    String? search,
  }) async {
    _requireAuth();
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/districts',
      queryParameters: {
        'page': page,
        'size': size,
        'cityId': ?cityId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return _parseLocationContent(response.data)
        .map(DistrictDto.fromJson)
        .toList();
  }

  /// Extracts the `data.content` list shared by the cities/districts/cuisine
  /// endpoints (also tolerates a flat `data` list or top-level `content`).
  List<Map<String, dynamic>> _parseLocationContent(dynamic raw) {
    dynamic list;
    if (raw is Map) {
      final data = raw['data'];
      if (data is Map && data['content'] is List) {
        list = data['content'];
      } else if (data is List) {
        list = data;
      } else if (raw['content'] is List) {
        list = raw['content'];
      }
    } else if (raw is List) {
      list = raw;
    }
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  void _requireAuth() {
    if (!_isLoggedIn) {
      throw DioException(
        requestOptions: RequestOptions(path: '${ApiClient.apiPrefix}/user/search'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 401,
          statusMessage: 'Login required for search',
        ),
      );
    }
  }
}
