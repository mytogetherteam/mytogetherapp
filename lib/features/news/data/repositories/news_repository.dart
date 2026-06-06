import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/news_dto.dart';

class NewsFeedPage {
  final List<NewsArticleDto> items;
  final int totalElements;
  final int totalPages;
  final int page;

  const NewsFeedPage({
    required this.items,
    required this.totalElements,
    required this.totalPages,
    required this.page,
  });
}

class NewsRepository {
  static final NewsRepository instance = NewsRepository._();
  NewsRepository._();

  final Dio _dio = ApiClient().dio;

  Future<NewsFeedPage> fetchFeed({int page = 1, int size = 20}) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/news',
      queryParameters: {'page': page, 'size': size},
    );
    final body = response.data;
    return NewsFeedPage(
      items: ApiResponseUtils.parseContentPage(body, NewsArticleDto.fromJson),
      totalElements: ApiResponseUtils.parseTotalElements(body),
      totalPages: ApiResponseUtils.parseLastPage(body),
      page: page,
    );
  }

  Future<NewsArticleDto?> fetchOne(int id) async {
    final response = await _dio.get('${ApiClient.apiPrefix}/user/news/$id');
    return ApiResponseUtils.parseDataObject(
      response.data,
      NewsArticleDto.fromJson,
    );
  }

  Future<({bool liked, int likeCount})> toggleLike(int id) async {
    final response = await _dio.post('${ApiClient.apiPrefix}/user/news/$id/like');
    final data = ApiResponseUtils.unwrapData(response.data);
    if (data is Map) {
      return (
        liked: data['liked'] == true,
        likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      );
    }
    return (liked: false, likeCount: 0);
  }

  Future<List<NewsCommentDto>> fetchComments(
    int newsId, {
    int page = 1,
    int size = 50,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/news/$newsId/comments',
      queryParameters: {'page': page, 'size': size},
    );
    return ApiResponseUtils.parseContentPage(
      response.data,
      NewsCommentDto.fromJson,
    );
  }

  Future<NewsCommentDto?> addComment(int newsId, String content) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/user/news/$newsId/comments',
      data: {'content': content},
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      NewsCommentDto.fromJson,
    );
  }

  /// Edit own comment. Backend: PATCH /api/user/news/:id/comments/:commentId
  Future<NewsCommentDto?> updateComment(
    int newsId,
    int commentId,
    String content,
  ) async {
    final response = await _dio.patch(
      '${ApiClient.apiPrefix}/user/news/$newsId/comments/$commentId',
      data: {'content': content},
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      NewsCommentDto.fromJson,
    );
  }

  /// Delete own comment. Backend: DELETE /api/user/news/:id/comments/:commentId
  Future<void> deleteComment(int newsId, int commentId) async {
    await _dio.delete(
      '${ApiClient.apiPrefix}/user/news/$newsId/comments/$commentId',
    );
  }
}
