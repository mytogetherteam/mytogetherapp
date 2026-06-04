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
    final body = response.data;
    final List<dynamic> list = body is Map
        ? (body['data'] as List<dynamic>? ?? const [])
        : (body is List ? body : const []);
    return list
        .map((e) => ShopReviewDto.fromJson(e as Map<String, dynamic>))
        .toList();
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
}
