import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/media/picked_image.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/post_dto.dart';
import '../models/social_reaction.dart';

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

class ReportOwnPostException implements Exception {}

class SocialFollowNotice {
  final SocialAuthorType type;
  final int id;
  final bool following;

  const SocialFollowNotice({
    required this.type,
    required this.id,
    required this.following,
  });
}

class SocialPostsRepository {
  static final SocialPostsRepository instance = SocialPostsRepository._();
  SocialPostsRepository._();

  /// Bumps when the signed-in user publishes or deletes a post.
  /// For You stays mounted under the other tabs, so it listens and reloads.
  static final feedRevision = ValueNotifier<int>(0);
  static final reactionsRevision = ValueNotifier<int>(0);
  /// The latest follow or unfollow, so a profile opened from Home
  /// updates the video feed that is still open underneath.
  static final followNotice = ValueNotifier<SocialFollowNotice?>(null);
  List<SocialReaction> reactions = List<SocialReaction>.of(fallbackSocialReactions);

  SocialReaction? reactionByKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final item in reactions) {
      if (item.key == key) return item;
    }
    for (final item in fallbackSocialReactions) {
      if (item.key == key) return item;
    }
    return null;
  }

  Future<List<SocialReaction>> loadReactions() async {
    try {
      reactions = await fetchReactions();
      reactionsRevision.value++;
    } catch (_) {}
    return reactions;
  }

  static void markFeedChanged() {
    feedRevision.value++;
  }

  final Dio _dio = ApiClient().dio;

  Future<SocialPostsFeedPage> fetchFeed({
    int page = 1,
    int size = 10,
    bool following = false,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/posts',
      queryParameters: {
        'page': page,
        'size': size,
        if (following) 'feed': 'following',
      },
    );
    final body = response.data;
    return SocialPostsFeedPage(
      items: ApiResponseUtils.parseContentPage(body, SocialPostDto.fromJson),
      totalElements: ApiResponseUtils.parseTotalElements(body),
      totalPages: ApiResponseUtils.parseLastPage(body),
      page: page,
    );
  }

  Future<SocialPostsFeedPage> fetchByShop(
    int shopId, {
    int page = 1,
    int size = 18,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/posts',
      queryParameters: {'page': page, 'size': size, 'shopId': shopId},
    );
    final body = response.data;
    return SocialPostsFeedPage(
      items: ApiResponseUtils.parseContentPage(body, SocialPostDto.fromJson),
      totalElements: ApiResponseUtils.parseTotalElements(body),
      totalPages: ApiResponseUtils.parseLastPage(body),
      page: page,
    );
  }

  Future<SocialPostsFeedPage> fetchByUser(
    int userId, {
    int page = 1,
    int size = 18,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/posts',
      queryParameters: {'page': page, 'size': size, 'userId': userId},
    );
    final body = response.data;
    return SocialPostsFeedPage(
      items: ApiResponseUtils.parseContentPage(body, SocialPostDto.fromJson),
      totalElements: ApiResponseUtils.parseTotalElements(body),
      totalPages: ApiResponseUtils.parseLastPage(body),
      page: page,
    );
  }

  Future<SocialPostsFeedPage> fetchByAuthor({
    required SocialAuthorType type,
    required int id,
    int page = 1,
    int size = 18,
  }) async {
    // Request up to 100 posts for creator profile so total likes and views are complete
    const querySize = 100;
    final Map<String, dynamic> query = {'page': page, 'size': querySize};
    switch (type) {
      case SocialAuthorType.user:
        query['userId'] = id;
        break;
      case SocialAuthorType.shop:
        query['shopId'] = id;
        break;
      case SocialAuthorType.admin:
        if (id > 0) query['adminId'] = id;
        break;
    }
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/posts',
      queryParameters: query,
    );
    final body = response.data;
    final rawItems =
        ApiResponseUtils.parseContentPage(body, SocialPostDto.fromJson);

    // Strictly match the author so mixed feed posts are never leaked
    final items = rawItems.where((p) {
      if (type == SocialAuthorType.admin) {
        return p.author.type == SocialAuthorType.admin &&
            (id <= 0 || p.author.id == id);
      } else if (type == SocialAuthorType.user) {
        return p.author.type == SocialAuthorType.user && p.author.id == id;
      } else if (type == SocialAuthorType.shop) {
        return p.author.type == SocialAuthorType.shop && p.author.id == id;
      }
      return true;
    }).toList();

    final backendTotal = ApiResponseUtils.parseTotalElements(body);
    final totalElements = (type == SocialAuthorType.admin)
        ? items.length
        : (backendTotal > 0 ? backendTotal : items.length);
    final totalPages = (type == SocialAuthorType.admin)
        ? 1
        : ApiResponseUtils.parseLastPage(body);

    return SocialPostsFeedPage(
      items: items,
      totalElements: totalElements,
      totalPages: totalPages,
      page: page,
    );
  }

  Future<SocialPostsFeedPage> fetchMine({int page = 1, int size = 18}) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/posts/mine',
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

  Future<SocialPostDto?> createPost({
    String? content,
    List<PickedImage> media = const [],
  }) async {
    final caption = content?.trim() ?? '';
    if (caption.isEmpty && media.isEmpty) {
      throw ArgumentError('A social post needs text or at least one photo or video.');
    }
    final form = FormData();
    if (caption.isNotEmpty) {
      form.fields.add(MapEntry('content', caption));
    }
    for (var i = 0; i < media.length; i++) {
      form.files.add(
        MapEntry(
          'media',
          media[i].toMultipartFile(
            filenameOverride: 'media_$i.${media[i].extension}',
          ),
        ),
      );
    }
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/user/posts',
      data: form,
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      SocialPostDto.fromJson,
    );
  }

  Future<SocialPostDto?> fetchOne(int id) async {
    final response = await _dio.get('${ApiClient.apiPrefix}/user/posts/$id');
    return ApiResponseUtils.parseDataObject(
      response.data,
      SocialPostDto.fromJson,
    );
  }

  Future<void> reportPost(int id) async {
    try {
      await _dio.post('${ApiClient.apiPrefix}/user/posts/$id/report');
    } on DioException catch (error) {
      if (error.response?.statusCode == 403) {
        throw ReportOwnPostException();
      }
      rethrow;
    }
  }

  Future<void> recordView(int id) async {
    try {
      await _dio.post('${ApiClient.apiPrefix}/user/posts/$id/view');
    } catch (_) {}
  }

  Future<({bool liked, int likeCount, String? reactionKey})> toggleLike(
    int id, {
    String? reactionKey,
  }) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/user/posts/$id/like',
      data: reactionKey == null ? null : {'reactionKey': reactionKey},
    );
    final data = ApiResponseUtils.unwrapData(response.data);
    if (data is Map) {
      final key = data['reactionKey']?.toString();
      return (
        liked: data['liked'] == true,
        likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
        reactionKey: key == null || key.isEmpty ? null : key,
      );
    }
    return (liked: false, likeCount: 0, reactionKey: null);
  }

  Future<List<SocialReaction>> fetchReactions() async {
    final response =
        await _dio.get('${ApiClient.apiPrefix}/user/social/reactions');
    final data = ApiResponseUtils.unwrapData(response.data);
    if (data is! List) return fallbackSocialReactions;
    final rows = data
        .whereType<Map>()
        .map((row) => SocialReaction.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    if (rows.isEmpty) return fallbackSocialReactions;
    rows.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return rows.take(7).toList();
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

  Future<SocialPostCommentDto?> addComment(
    int postId,
    String content, {
    int? parentId,
  }) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/user/posts/$postId/comments',
      data: {
        'content': content,
        if (parentId != null) 'parentId': parentId,
      },
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

  Future<void> deletePost(int id) async {
    await _dio.delete('${ApiClient.apiPrefix}/user/posts/$id');
  }

  Future<void> deleteComment(int postId, int commentId) async {
    await _dio.delete(
      '${ApiClient.apiPrefix}/user/posts/$postId/comments/$commentId',
    );
  }

  Future<({bool liked, int likeCount})> toggleCommentLike(
    int postId,
    int commentId,
  ) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/user/posts/$postId/comments/$commentId/like',
    );
    final data = ApiResponseUtils.unwrapData(response.data);
    if (data is Map) {
      return (
        liked: data['liked'] == true,
        likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      );
    }
    return (liked: false, likeCount: 0);
  }

  Future<({bool following, int followerCount})> followStatus({
    int? userId,
    int? shopId,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/social/follow',
      queryParameters: {
        if (userId != null) 'userId': userId,
        if (shopId != null) 'shopId': shopId,
      },
    );
    return _readFollow(response.data);
  }

  Future<({bool following, int followerCount})> toggleFollow({
    int? userId,
    int? shopId,
  }) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/user/social/follow',
      data: {
        if (userId != null) 'userId': userId,
        if (shopId != null) 'shopId': shopId,
      },
    );
    final result = _readFollow(response.data);
    if (userId != null) {
      followNotice.value = SocialFollowNotice(
        type: SocialAuthorType.user,
        id: userId,
        following: result.following,
      );
    } else if (shopId != null) {
      followNotice.value = SocialFollowNotice(
        type: SocialAuthorType.shop,
        id: shopId,
        following: result.following,
      );
    }
    return result;
  }

  ({bool following, int followerCount}) _readFollow(dynamic body) {
    final data = ApiResponseUtils.unwrapData(body);
    if (data is Map) {
      return (
        following: data['following'] == true,
        followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
      );
    }
    return (following: false, followerCount: 0);
  }
}
