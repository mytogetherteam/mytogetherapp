import '../../../../core/network/media_url.dart';
import '../../../../core/utils/relative_time.dart';

class NewsAuthorDto {
  final int id;
  final String? name;
  final String? username;
  final String? profileUrl;

  NewsAuthorDto({
    required this.id,
    this.name,
    this.username,
    this.profileUrl,
  });

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (username != null && username!.trim().isNotEmpty) {
      return username!.trim();
    }
    return 'Together';
  }

  factory NewsAuthorDto.fromJson(Map<String, dynamic> json) {
    return NewsAuthorDto(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString(),
      username: json['username']?.toString(),
      profileUrl: resolveMediaUrl(json['profileUrl']?.toString()),
    );
  }
}

class NewsPhotoDto {
  final int id;
  final String url;
  final int position;

  NewsPhotoDto({required this.id, required this.url, required this.position});

  factory NewsPhotoDto.fromJson(Map<String, dynamic> json) {
    return NewsPhotoDto(
      id: (json['id'] as num).toInt(),
      url: resolveMediaUrl(json['url']?.toString()),
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }
}

class NewsArticleDto {
  final int id;
  final String title;
  final String description;
  final DateTime createdAt;
  final List<NewsPhotoDto> photos;
  final NewsAuthorDto? createdByAdmin;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  NewsArticleDto({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.photos,
    this.createdByAdmin,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  List<String> get imageUrls =>
      photos.map((p) => p.url).where((u) => u.isNotEmpty).toList();

  String get timeAgo => formatRelativeTime(createdAt);

  String get feedContent {
    final body = description.trim();
    if (body.isEmpty) return title;
    if (title.trim().isEmpty) return body;
    return '$title\n\n$body';
  }

  factory NewsArticleDto.fromJson(Map<String, dynamic> json) {
    final photosRaw = json['photos'];
    return NewsArticleDto(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      photos: photosRaw is List
          ? photosRaw
              .whereType<Map<String, dynamic>>()
              .map(NewsPhotoDto.fromJson)
              .toList()
          : const [],
      createdByAdmin: json['createdByAdmin'] is Map<String, dynamic>
          ? NewsAuthorDto.fromJson(
              json['createdByAdmin'] as Map<String, dynamic>,
            )
          : null,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] == true,
    );
  }
}

class NewsCommentDto {
  final int id;
  final int userId;
  final String content;
  final DateTime createdAt;
  final NewsAuthorDto? user;

  NewsCommentDto({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.user,
  });

  String get authorName => user?.displayName ?? 'User';
  String get authorAvatar => user?.profileUrl ?? '';
  String get timeAgo => formatRelativeTime(createdAt);

  factory NewsCommentDto.fromJson(Map<String, dynamic> json) {
    return NewsCommentDto(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      user: json['user'] is Map<String, dynamic>
          ? NewsAuthorDto.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}
