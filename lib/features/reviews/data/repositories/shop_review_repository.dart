import 'package:dio/dio.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import '../../../home/data/models/shop_review_dto.dart';

/// Shop-level reviews written by the current user (distinct from order
/// reviews). Backend (`dev`):
///   POST   /api/user/reviews                 body: {shopId, rating, comment?}
///   GET    /api/user/reviews                 list mine (paginated)
///   GET    /api/user/reviews/:id             one of mine
///   PATCH  /api/user/reviews/:id             update {rating?, comment?}
///   DELETE /api/user/reviews/:id             delete mine
class ShopReviewRepository {
  static final ShopReviewRepository instance = ShopReviewRepository._();
  ShopReviewRepository._();

  final ApiClient _apiClient = ApiClient();

  Future<ShopReviewDto> create({
    required int shopId,
    required double rating,
    String? comment,
  }) async {
    final response = await _apiClient.dio.post(
      '${ApiClient.apiPrefix}/user/reviews',
      data: {
        'shopId': shopId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
    return ShopReviewDto.fromJson(_unwrap(response.data));
  }

  /// Creates a shop review, or updates the existing one if the user already
  /// reviewed this restaurant (409). Used when mirroring order-history reviews
  /// to the shop review feed that MyShop reads.
  Future<void> createOrUpdate({
    required int shopId,
    required double rating,
    String? comment,
  }) async {
    try {
      await create(shopId: shopId, rating: rating, comment: comment);
    } on DioException catch (e) {
      if (e.response?.statusCode != 409) rethrow;
      final existing = await getMyReviews(shopId: shopId, page: 1, size: 1);
      if (existing.isEmpty) rethrow;
      await update(
        reviewId: existing.first.id,
        rating: rating,
        comment: comment,
      );
    }
  }

  Future<List<ShopReviewDto>> getMyReviews({
    int? shopId,
    int page = 1,
    int size = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiClient.apiPrefix}/user/reviews',
      queryParameters: {
        'page': page,
        'size': size,
        'shopId': ?shopId,
      },
    );
    return _parseReviewList(response.data);
  }

  /// Fetches a single review owned by the current user.
  /// Backend: GET /api/user/reviews/:id. Returns null on 404.
  Future<ShopReviewDto?> getById(int reviewId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/reviews/$reviewId',
      );
      return ShopReviewDto.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ShopReviewDto> update({
    required int reviewId,
    double? rating,
    String? comment,
  }) async {
    final response = await _apiClient.dio.patch(
      '${ApiClient.apiPrefix}/user/reviews/$reviewId',
      data: {
        'rating': ?rating,
        'comment': ?comment?.trim(),
      },
    );
    return ShopReviewDto.fromJson(_unwrap(response.data));
  }

  Future<bool> delete(int reviewId) async {
    try {
      final response = await _apiClient.dio.delete(
        '${ApiClient.apiPrefix}/user/reviews/$reviewId',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException {
      return false;
    }
  }

  Map<String, dynamic> _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    return <String, dynamic>{};
  }

  List<ShopReviewDto> _parseReviewList(dynamic body) {
    if (body is! Map) return [];
    final data = body['data'];
    final List<dynamic> list;
    if (data is Map && data['content'] is List) {
      list = data['content'] as List;
    } else if (data is List) {
      list = data;
    } else {
      list = const [];
    }
    return list
        .map((e) => ShopReviewDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
