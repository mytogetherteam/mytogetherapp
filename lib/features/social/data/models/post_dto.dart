import '../../../../core/network/media_url.dart';
import '../../../../core/utils/relative_time.dart';

enum SocialMediaType { image, video }

enum SocialAuthorType { user, shop, admin }

class SocialPostAuthorDto {
  final SocialAuthorType type;
  final int id;
  final String displayName;
  final String? avatarUrl;

  const SocialPostAuthorDto({
    required this.type,
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  factory SocialPostAuthorDto.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SocialPostAuthorDto(
        type: SocialAuthorType.admin,
        id: 0,
        displayName: 'MyTogether',
      );
    }

    final typeRaw = (json['type']?.toString() ?? 'ADMIN').toUpperCase();
    final type = switch (typeRaw) {
      'USER' => SocialAuthorType.user,
      'SHOP' => SocialAuthorType.shop,
      _ => SocialAuthorType.admin,
    };

    String name;
    String? avatar;
    switch (type) {
      case SocialAuthorType.shop:
        name = (json['nameEn']?.toString().trim().isNotEmpty == true)
            ? json['nameEn'].toString().trim()
            : (json['nameMm']?.toString().trim().isNotEmpty == true)
                ? json['nameMm'].toString().trim()
                : 'Shop #${json['id']}';
        avatar = _nullableMedia(json['logoUrl']?.toString());
        break;
      case SocialAuthorType.user:
        name = (json['name']?.toString().trim().isNotEmpty == true)
            ? json['name'].toString().trim()
            : (json['username']?.toString().trim().isNotEmpty == true)
                ? json['username'].toString().trim()
                : 'User #${json['id']}';
        avatar = _nullableMedia(json['profileUrl']?.toString());
        break;
      case SocialAuthorType.admin:
        name = (json['name']?.toString().trim().isNotEmpty == true)
            ? json['name'].toString().trim()
            : (json['username']?.toString().trim().isNotEmpty == true)
                ? json['username'].toString().trim()
                : (json['email']?.toString().trim().isNotEmpty == true)
                    ? json['email'].toString().trim()
                    : 'MyTogether';
        avatar = _nullableMedia(json['profileUrl']?.toString());
        break;
    }

    return SocialPostAuthorDto(
      type: type,
      id: (json['id'] as num?)?.toInt() ?? 0,
      displayName: name,
      avatarUrl: avatar,
    );
  }

  String get handle {
    final cleaned = displayName.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return '@mytogether';
    return cleaned.startsWith('@') ? cleaned : '@$cleaned';
  }
}

class SocialPostMediaDto {
  final int id;
  final SocialMediaType type;
  final String url;
  final String? thumbnailUrl;
  final int? duration;
  final int position;

  const SocialPostMediaDto({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    this.duration,
    required this.position,
  });

  bool get isVideo => type == SocialMediaType.video;

  /// Prefer poster for teasers / offline; fall back to media url for images.
  String get previewUrl {
    if (isVideo) {
      final thumb = thumbnailUrl?.trim() ?? '';
      if (thumb.isNotEmpty) return thumb;
    }
    return url;
  }

  factory SocialPostMediaDto.fromJson(Map<String, dynamic> json) {
    final typeRaw = (json['type']?.toString() ?? 'IMAGE').toUpperCase();
    return SocialPostMediaDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: typeRaw == 'VIDEO' ? SocialMediaType.video : SocialMediaType.image,
      url: resolveMediaUrl(json['url']?.toString()),
      thumbnailUrl: _nullableMedia(json['thumbnailUrl']?.toString()),
      duration: (json['duration'] as num?)?.toInt(),
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }
}

String? _nullableMedia(String? path) {
  final url = resolveMediaUrl(path);
  return url.isEmpty ? null : url;
}

class SocialPostDto {
  final int id;
  final String? content;
  final bool isActive;
  final DateTime createdAt;
  final List<SocialPostMediaDto> media;
  final SocialPostAuthorDto author;
  int likeCount;
  int commentCount;
  bool likedByMe;

  SocialPostDto({
    required this.id,
    required this.content,
    required this.isActive,
    required this.createdAt,
    required this.media,
    required this.author,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  SocialPostMediaDto? get primaryMedia =>
      media.isEmpty ? null : media.first;

  String get caption => content?.trim() ?? '';

  factory SocialPostDto.fromJson(Map<String, dynamic> json) {
    final mediaRaw = json['media'];
    final media = mediaRaw is List
        ? mediaRaw
            .whereType<Map>()
            .map((e) => SocialPostMediaDto.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SocialPostMediaDto>[];
    media.sort((a, b) => a.position.compareTo(b.position));

    return SocialPostDto(
      id: (json['id'] as num).toInt(),
      content: json['content']?.toString(),
      isActive: json['isActive'] != false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      media: media,
      author: SocialPostAuthorDto.fromJson(
        json['author'] is Map
            ? Map<String, dynamic>.from(json['author'] as Map)
            : null,
      ),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] == true,
    );
  }
}

class SocialPostCommentDto {
  final int id;
  final int? userId;
  final int? shopId;
  final String content;
  final DateTime createdAt;
  final SocialPostAuthorDto author;

  SocialPostCommentDto({
    required this.id,
    required this.userId,
    required this.shopId,
    required this.content,
    required this.createdAt,
    required this.author,
  });

  String get timeAgo => formatRelativeTime(createdAt);

  bool isMine(int? currentUserId) =>
      currentUserId != null && userId != null && userId == currentUserId;

  factory SocialPostCommentDto.fromJson(Map<String, dynamic> json) {
    // Nest shapeComment exposes `author`; older payloads may still nest `user`.
    Map<String, dynamic>? authorJson;
    if (json['author'] is Map) {
      authorJson = Map<String, dynamic>.from(json['author'] as Map);
    } else if (json['user'] is Map) {
      authorJson = {
        ...Map<String, dynamic>.from(json['user'] as Map),
        'type': 'USER',
      };
    } else if (json['shop'] is Map) {
      authorJson = {
        ...Map<String, dynamic>.from(json['shop'] as Map),
        'type': 'SHOP',
      };
    }

    return SocialPostCommentDto(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      shopId: (json['shopId'] as num?)?.toInt(),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      author: SocialPostAuthorDto.fromJson(authorJson),
    );
  }
}
