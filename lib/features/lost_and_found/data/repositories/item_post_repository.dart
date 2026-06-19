import 'package:dio/dio.dart';
import 'package:mytogetherapp/core/media/picked_image.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/item_post_dto.dart';

class ItemPostFeedPage {
  final List<ItemPostDto> items;
  final int totalElements;
  final int totalPages;
  final int page;

  const ItemPostFeedPage({
    required this.items,
    required this.totalElements,
    required this.totalPages,
    required this.page,
  });
}

class ItemPostRepository {
  static final ItemPostRepository instance = ItemPostRepository._();
  ItemPostRepository._();

  final Dio _dio = ApiClient().dio;

  Future<ItemPostFeedPage> fetchFeed({
    int page = 1,
    int size = 20,
    String? type,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/item-posts',
      queryParameters: {
        'page': page,
        'size': size,
        'type': ?type,
      },
    );
    final body = response.data;
    return ItemPostFeedPage(
      items: ApiResponseUtils.parseContentPage(body, ItemPostDto.fromJson),
      totalElements: ApiResponseUtils.parseTotalElements(body),
      totalPages: ApiResponseUtils.parseLastPage(body),
      page: page,
    );
  }

  Future<ItemPostFeedPage> fetchNearby({
    required double latitude,
    required double longitude,
    int page = 1,
    int size = 20,
    double? radiusKm,
    String? type,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/item-posts/nearby',
      queryParameters: {
        'page': page,
        'size': size,
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': ?radiusKm,
        'type': ?type,
      },
    );
    final body = response.data;
    return ItemPostFeedPage(
      items: ApiResponseUtils.parseContentPage(body, ItemPostDto.fromJson),
      totalElements: ApiResponseUtils.parseTotalElements(body),
      totalPages: ApiResponseUtils.parseLastPage(body),
      page: page,
    );
  }

  Future<ItemPostDto?> fetchOne(int id) async {
    final response = await _dio.get('${ApiClient.apiPrefix}/user/item-posts/$id');
    return ApiResponseUtils.parseDataObject(
      response.data,
      ItemPostDto.fromJson,
    );
  }

  /// Current user's own posts. Backend: GET /api/user/item-posts/mine
  Future<ItemPostFeedPage> fetchMine({int page = 1, int size = 20}) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/item-posts/mine',
      queryParameters: {'page': page, 'size': size},
    );
    final body = response.data;
    return ItemPostFeedPage(
      items: ApiResponseUtils.parseContentPage(body, ItemPostDto.fromJson),
      totalElements: ApiResponseUtils.parseTotalElements(body),
      totalPages: ApiResponseUtils.parseLastPage(body),
      page: page,
    );
  }

  /// Update own post. Backend: PATCH /api/user/item-posts/:id (multipart).
  /// [removePhotoIds] deletes existing photos; [photos] adds new ones.
  Future<ItemPostDto?> update(
    int id, {
    String? description,
    String? type,
    double? latitude,
    double? longitude,
    String? locationName,
    String? phoneNumber,
    List<PickedImage> photos = const [],
    List<int> removePhotoIds = const [],
  }) async {
    final formData = FormData.fromMap({
      'description': ?description,
      'type': ?type,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'locationName': ?locationName,
      'phoneNumber': ?phoneNumber,
      if (removePhotoIds.isNotEmpty)
        'removePhotoIds': removePhotoIds.map((e) => e.toString()).toList(),
    });

    for (var i = 0; i < photos.length; i++) {
      formData.files.add(
        MapEntry(
          'photos',
          photos[i].toMultipartFile(
            filenameOverride: 'photo_$i.${photos[i].extension}',
          ),
        ),
      );
    }

    final response = await _dio.patch(
      '${ApiClient.apiPrefix}/user/item-posts/$id',
      data: formData,
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      ItemPostDto.fromJson,
    );
  }

  /// Delete own post. Backend: DELETE /api/user/item-posts/:id
  Future<void> delete(int id) async {
    await _dio.delete('${ApiClient.apiPrefix}/user/item-posts/$id');
  }

  Future<ItemPostDto?> create({
    required String description,
    String type = 'LOST',
    double? latitude,
    double? longitude,
    String? locationName,
    String? phoneNumber,
    List<PickedImage> photos = const [],
  }) async {
    final formData = FormData.fromMap({
      'description': description,
      'type': type,
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (locationName != null && locationName.isNotEmpty)
        'locationName': locationName,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phoneNumber': phoneNumber,
    });

    for (var i = 0; i < photos.length; i++) {
      formData.files.add(
        MapEntry(
          'photos',
          photos[i].toMultipartFile(
            filenameOverride: 'photo_$i.${photos[i].extension}',
          ),
        ),
      );
    }

    final response = await _dio.post(
      '${ApiClient.apiPrefix}/user/item-posts',
      data: formData,
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      ItemPostDto.fromJson,
    );
  }

  Future<({bool liked, int likeCount})> toggleLike(int id) async {
    final response =
        await _dio.post('${ApiClient.apiPrefix}/user/item-posts/$id/like');
    final data = ApiResponseUtils.unwrapData(response.data);
    if (data is Map) {
      return (
        liked: data['liked'] == true,
        likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      );
    }
    return (liked: false, likeCount: 0);
  }

  Future<List<ItemPostCommentDto>> fetchComments(
    int postId, {
    int page = 1,
    int size = 50,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/item-posts/$postId/comments',
      queryParameters: {'page': page, 'size': size},
    );
    return ApiResponseUtils.parseContentPage(
      response.data,
      ItemPostCommentDto.fromJson,
    );
  }

  Future<ItemPostCommentDto?> addComment(int postId, String content) async {
    final response = await _dio.post(
      '${ApiClient.apiPrefix}/user/item-posts/$postId/comments',
      data: {'content': content},
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      ItemPostCommentDto.fromJson,
    );
  }

  /// Edit own comment. Backend: PATCH /api/user/item-posts/:id/comments/:commentId
  Future<ItemPostCommentDto?> updateComment(
    int postId,
    int commentId,
    String content,
  ) async {
    final response = await _dio.patch(
      '${ApiClient.apiPrefix}/user/item-posts/$postId/comments/$commentId',
      data: {'content': content},
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      ItemPostCommentDto.fromJson,
    );
  }

  /// Delete own comment. Backend: DELETE /api/user/item-posts/:id/comments/:commentId
  Future<void> deleteComment(int postId, int commentId) async {
    await _dio.delete(
      '${ApiClient.apiPrefix}/user/item-posts/$postId/comments/$commentId',
    );
  }
}
