import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_client.dart';
import '../../home/data/models/shop_dto.dart';
import '../../home/data/models/trending_item_dto.dart';
import 'models/search_shop_dto.dart';
import 'models/search_filters.dart';
import 'models/location_ref_dto.dart';
import 'models/ai_search_parsed_result.dart';

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

  /// Shop delivery/open state must not sit in the 7-day response cache.
  Options get _freshShopOptions => Options(
        extra: {
          '@dio_cache_interceptor@': CacheOptions(
            store: MemCacheStore(),
            policy: CachePolicy.refresh,
          ),
        },
      );

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
      options: _freshShopOptions,
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
      options: _freshShopOptions,
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
      originLat: latitude,
      originLon: longitude,
      pageSize: size,
    );
  }

  /// Nearby shops. Open shops come first, then the nearer shop.
  /// [deliveryEnabled] asks the server for delivery (`true`) or Go & Eat
  /// (`false`) before the page is cut. Null leaves both kinds in the page.
  Future<SearchPageResult> searchNearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
    int page = 1,
    int size = 20,
    bool? deliveryEnabled,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/search/nearby',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': ?radiusKm,
        'page': page,
        'size': size,
        'deliveryEnabled': ?deliveryEnabled,
      },
      options: _freshShopOptions,
    );
    return SearchPageResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Shops with active MyDays globally/randomly.
  Future<SearchPageResult> searchNearbyActiveMyDays({
    int page = 1,
    int size = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/search/mydays',
      queryParameters: {
        'page': page,
        'size': size,
        '_cb': DateTime.now().millisecondsSinceEpoch, // bypass DioCacheInterceptor
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
      options: _freshShopOptions,
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
      options: _freshShopOptions,
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
      options: _freshShopOptions,
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

  /// Fast on-device client heuristics for instant 0ms, zero-cost intent parsing.
  static AiSearchParsedResult extractClientHeuristics(String rawQuery) {
    var search = rawQuery.trim();
    bool? isSpicy;
    bool? isVegetarian;
    bool? isHalal;
    String? mealType;
    bool? topRated;
    final labels = <String>[];

    // Dinner / Night food
    if (RegExp(r'(ညစာ|ညဉ့်နက်|ညပိုင်း|dinner|night\s*food|late\s*night|night\s*time|\bnight\b|\bည\b)', caseSensitive: false).hasMatch(search)) {
      mealType = 'dinner';
      labels.add('ညစာ (Dinner)');
      search = search.replaceAll(RegExp(r'(ညစာ|ညဉ့်နက်|ညပိုင်း|dinner|night\s*food|late\s*night|night\s*time|\bnight\b|\bည\b)', caseSensitive: false), '');
    } else if (RegExp(r'(မနက်စာ|မနက်ပိုင်း|breakfast|morning\s*food|\bmorning\b|\bမနက်\b)', caseSensitive: false).hasMatch(search)) {
      mealType = 'breakfast';
      labels.add('မနက်စာ (Breakfast)');
      search = search.replaceAll(RegExp(r'(မနက်စာ|မနက်ပိုင်း|breakfast|morning\s*food|\bmorning\b|\bမနက်\b)', caseSensitive: false), '');
    } else if (RegExp(r'(နေ့လယ်စာ|နေ့လည်စာ|lunch|afternoon\s*food|lunch\s*food|\bနေ့လယ်\b)', caseSensitive: false).hasMatch(search)) {
      mealType = 'lunch';
      labels.add('နေ့လယ်စာ (Lunch)');
      search = search.replaceAll(RegExp(r'(နေ့လယ်စာ|နေ့လည်စာ|lunch\s*food|\blunch\b|\bနေ့လယ်\b)', caseSensitive: false), '');
    } else if (RegExp(r'(အဆာပြေ|လက်ဖက်ရည်|snack|tea\s*time|snack\s*food|dessert)', caseSensitive: false).hasMatch(search)) {
      mealType = 'snack';
      labels.add('အဆာပြေ (Snack)');
      search = search.replaceAll(RegExp(r'(အဆာပြေ|လက်ဖက်ရည်|snack\s*food|\bsnack\b|dessert)', caseSensitive: false), '');
    }

    // Spicy / Mild
    if (RegExp(r'(အစပ်မပါ|မစပ်တာ|မစပ်ဘဲ|မစပ်တဲ့|အစပ်မကြိုက်|not\s*spicy|non\s*spicy|mild|no\s*chili|no\s*spice)', caseSensitive: false).hasMatch(search)) {
      isSpicy = false;
      labels.add('အစပ်မပါ (Mild)');
      search = search.replaceAll(RegExp(r'(အစပ်မပါ(သော|တဲ့)?|မစပ်တာ|မစပ်ဘဲ|မစပ်တဲ့|အစပ်မကြိုက်|not\s*spicy|non\s*spicy|mild|no\s*chili|no\s*spice)', caseSensitive: false), '');
    } else if (RegExp(r'(အစပ်|စပ်စပ်|စပ်တာ|spicy|hot)', caseSensitive: false).hasMatch(search)) {
      isSpicy = true;
      labels.add('အစပ် (Spicy)');
      search = search.replaceAll(RegExp(r'(အစပ်|စပ်စပ်|စပ်တာ|\bspicy\b|\bhot\b)', caseSensitive: false), '');
    }

    // Vegetarian
    if (RegExp(r'(သက်သတ်လွတ်|vegetarian|veggie|vegan)', caseSensitive: false).hasMatch(search)) {
      isVegetarian = true;
      labels.add('သက်သတ်လွတ်');
      search = search.replaceAll(RegExp(r'(သက်သတ်လွတ်|vegetarian|veggie|vegan)', caseSensitive: false), '');
    }

    // Halal
    if (RegExp(r'(ဟာလာလ်|ဟာလာ|halal)', caseSensitive: false).hasMatch(search)) {
      isHalal = true;
      labels.add('ဟာလာလ် (Halal)');
      search = search.replaceAll(RegExp(r'(ဟာလာလ်|ဟာလာ|halal)', caseSensitive: false), '');
    }

    // Top rated / Famous
    if (RegExp(r'(အကောင်းဆုံး|နာမည်ကြီး|လူကြိုက်အများဆုံး|top\s*rated|best|popular|famous)', caseSensitive: false).hasMatch(search)) {
      topRated = true;
      labels.add('နာမည်ကြီး (Popular)');
      search = search.replaceAll(RegExp(r'(အကောင်းဆုံး|နာမည်ကြီး|လူကြိုက်အများဆုံး|top\s*rated|best|popular|famous)', caseSensitive: false), '');
    }

    // Clean up generic filler words in both Myanmar and English
    search = search
        .replaceAll(RegExp(r'(\bfood\b|\bdishes\b|\bdish\b|\bmeals\b|\bmeal\b|\brestaurant\b|\brestaurants\b|စားချင်တယ်|လိုချင်တယ်|ရနိုင်မယ့်|အတွက်|ကလေးတွေ|ကလေး|ဆိုင်|ရှာပေးပါ|အစားအသောက်|ဟင်း|စားစရာ)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return AiSearchParsedResult(
      search: search.isNotEmpty ? search : (labels.isNotEmpty ? '' : rawQuery.trim()),
      isSpicy: isSpicy,
      isVegetarian: isVegetarian,
      isHalal: isHalal,
      mealType: mealType,
      topRated: topRated,
      intentLabel: labels.isNotEmpty ? labels.join(' · ') : null,
    );
  }

  /// Parses natural language query into intent and filters using backend AI service.
  /// Free tier + in-memory cached. Fallback to direct Gemini and basic query.
  Future<AiSearchParsedResult> parseNaturalLanguageQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return AiSearchParsedResult.fallback('');
    }

    // 1. Instant local client heuristic (0ms, 0 cost, works offline / before deploy)
    final localResult = extractClientHeuristics(trimmed);
    if (localResult.hasAnyFilter) {
      return localResult;
    }

    // Single-word check: avoid network call if query is a simple word without conversational context
    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final hasConversationalWords = RegExp(
      r'(မပါ|မကြိုက်|ကြိုက်|စားချင်|လိုချင်|ရနိုင်|အကောင်းဆုံး|အတွက်|နဲ့|food|near|best|spicy)',
      caseSensitive: false,
    ).hasMatch(trimmed);

    if (words.length <= 1 && !hasConversationalWords) {
      return AiSearchParsedResult.fallback(trimmed);
    }

    // 2. Try backend AI service
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/search/ai-parse',
        queryParameters: {'q': trimmed},
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
        final parsed = AiSearchParsedResult.fromJson(data['data'] as Map<String, dynamic>);
        if (parsed.hasAnyFilter || parsed.search.isNotEmpty) {
          return parsed;
        }
      }
    } catch (_) {
      // Backend not yet reachable or not yet deployed to cloud
    }

    // 3. Direct Gemini 1.5 Flash client fallback (guarantees AI search works anywhere right now)
    try {
      const geminiKey = 'AIzaSyBwCrKBa7V-QXJCiTN12urmEiKZSqSf7tA';
      final dio = Dio();
      final prompt = 'Parse food query: "$trimmed" into JSON: {"search": string, "isSpicy": boolean|null, "isVegetarian": boolean|null, "isHalal": boolean|null, "mealType": "breakfast"|"lunch"|"dinner"|"snack"|null, "topRated": boolean|null, "intentLabel": string}';
      final geminiResp = await dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiKey',
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 150,
            'responseMimeType': 'application/json',
          },
        },
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final rawText = geminiResp.data?['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (rawText != null) {
        final Map<String, dynamic> parsedJson = jsonDecode(rawText as String);
        return AiSearchParsedResult.fromJson(parsedJson);
      }
    } catch (_) {
      // Fallback
    }

    return localResult;
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
