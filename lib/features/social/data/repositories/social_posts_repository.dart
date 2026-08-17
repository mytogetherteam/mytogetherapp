import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/post_dto.dart';

class SocialPostsFeedPage {
  final List<SocialPostDto> items;
  final int totalElements;
  final int totalPages;
  final int page;

  const SocialPostsFeedPage({
    required this.items,
    required this.totalElements,
    required this.totalPages,
    required this.page,
  });
}

class SocialPostsRepository {
  static final SocialPostsRepository instance = SocialPostsRepository._();
  SocialPostsRepository._();

  final Dio _dio = ApiClient().dio;

  Future<SocialPostsFeedPage> fetchFeed({int page = 1, int size = 10}) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/posts',
      queryParameters: {'page': page, 'size': size},
    );
    final body = response.data;
    return SocialPostsFeedPage(
      items: ApiResponseUtils.parseContentPage(body, SocialPostDto.fromJson),
      totalElements: ApiResponseUtils.parseTotalElements(body),
      totalPages: ApiResponseUtils.parseLastPage(body),
      page: page,
    );
  }

  Future<SocialPostDto?> fetchOne(int id) async {
    final response = await _dio.get('${ApiClient.apiPrefix}/user/posts/$id');
    return ApiResponseUtils.parseDataObject(
      response.data,
      SocialPostDto.fromJson,
    );
  }

  Future<({bool liked, int likeCount})> toggleLike(int id) async {
    final response =
        await _dio.post('${ApiClient.apiPrefix}/user/posts/$id/like');
    final data = ApiResponseUtils.unwrapData(response.data);
    if (data is Map) {
      return (
        liked: data['liked'] == true,
        likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      );
    }
    return (liked: false, likeCount: 0);
  }

  Future<List<SocialPostCommentDto>> fetchComments(
    int postId, {
    int page = 1,
    int size = 50,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/posts/$postId/comments',
      queryParameters: {'page': page, 'size': size},
    );
    return ApiResponseUtils.parseContentPage(
      response.data,
      SocialPostCommentDto.fromJson,
    );
  }

  Future<SocialPostCommentDto?> addComment(int postId, String content) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/user/posts/$postId/comments',
      data: {'content': content},
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      SocialPostCommentDto.fromJson,
    );
  }

  Future<SocialPostCommentDto?> updateComment(
    int postId,
    int commentId,
    String content,
  ) async {
    final response = await _dio.patch(
      '${ApiClient.apiPrefix}/user/posts/$postId/comments/$commentId',
      data: {'content': content},
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      SocialPostCommentDto.fromJson,
    );
  }

  Future<void> deleteComment(int postId, int commentId) async {
    await _dio.delete(
      '${ApiClient.apiPrefix}/user/posts/$postId/comments/$commentId',
    );
  }
}
