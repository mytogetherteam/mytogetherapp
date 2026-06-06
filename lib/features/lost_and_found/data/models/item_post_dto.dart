import '../../../../core/network/media_url.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../news/data/models/news_dto.dart';

class ItemPostPhotoDto {
  final int id;
  final String url;
  final int position;

  ItemPostPhotoDto({required this.id, required this.url, required this.position});

  factory ItemPostPhotoDto.fromJson(Map<String, dynamic> json) {
    return ItemPostPhotoDto(
      id: (json['id'] as num).toInt(),
      url: resolveMediaUrl(json['url']?.toString()),
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }
}

class ItemPostDto {
  final int id;
  final String type;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? phoneNumber;
  final String description;
  final DateTime createdAt;
  final List<ItemPostPhotoDto> photos;
  final NewsAuthorDto? user;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final double? distanceKm;

  ItemPostDto({
    required this.id,
    required this.type,
    this.latitude,
    this.longitude,
    this.locationName,
    this.phoneNumber,
    required this.description,
    required this.createdAt,
    required this.photos,
    this.user,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    this.distanceKm,
  });

  List<String> get imageUrls =>
      photos.map((p) => p.url).where((u) => u.isNotEmpty).toList();

  String get timeAgo => formatRelativeTime(createdAt);

  String? get locationLabel {
    if (locationName != null && locationName!.trim().isNotEmpty) {
      return locationName;
    }
    if (distanceKm != null) {
      return formatDistanceKm(distanceKm);
    }
    return null;
  }

  factory ItemPostDto.fromJson(Map<String, dynamic> json) {
    final photosRaw = json['photos'];
    return ItemPostDto(
      id: (json['id'] as num).toInt(),
      type: json['type']?.toString() ?? 'LOST',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationName: json['locationName']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      description: json['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      photos: photosRaw is List
          ? photosRaw
              .whereType<Map<String, dynamic>>()
              .map(ItemPostPhotoDto.fromJson)
              .toList()
          : const [],
      user: json['user'] is Map<String, dynamic>
          ? NewsAuthorDto.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] == true,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    );
  }
}

class ItemPostCommentDto {
  final int id;
  final String content;
  final DateTime createdAt;
  final NewsAuthorDto? user;

  ItemPostCommentDto({
    required this.id,
    required this.content,
    required this.createdAt,
    this.user,
  });

  String get authorName => user?.displayName ?? 'User';
  String get authorAvatar => user?.profileUrl ?? '';
  String get timeAgo => formatRelativeTime(createdAt);

  factory ItemPostCommentDto.fromJson(Map<String, dynamic> json) {
    return ItemPostCommentDto(
      id: (json['id'] as num).toInt(),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      user: json['user'] is Map<String, dynamic>
          ? NewsAuthorDto.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}
