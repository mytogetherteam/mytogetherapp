import '../../../../core/network/media_url.dart';

class SocialReaction {
  final int id;
  final String key;
  final String emoji;
  final String labelEn;
  final String? labelMm;
  final String? labelTh;
  final String? imageUrl;
  final int sortOrder;

  const SocialReaction({
    required this.id,
    required this.key,
    required this.emoji,
    required this.labelEn,
    this.labelMm,
    this.labelTh,
    this.imageUrl,
    required this.sortOrder,
  });

  factory SocialReaction.fromJson(Map<String, dynamic> json) {
    final image = resolveMediaUrl(json['imageUrl']?.toString());
    return SocialReaction(
      id: (json['id'] as num?)?.toInt() ?? 0,
      key: json['key']?.toString() ?? 'like',
      emoji: json['emoji']?.toString() ?? '👍',
      labelEn: json['labelEn']?.toString() ?? 'Like',
      labelMm: json['labelMm']?.toString(),
      labelTh: json['labelTh']?.toString(),
      imageUrl: image.isEmpty ? null : image,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Used when the catalog has not loaded yet, so the row still has seven faces.
const fallbackSocialReactions = <SocialReaction>[
  SocialReaction(id: 1, key: 'like', emoji: '👍', labelEn: 'Like', sortOrder: 1),
  SocialReaction(id: 2, key: 'love', emoji: '❤️', labelEn: 'Love', sortOrder: 2),
  SocialReaction(id: 3, key: 'care', emoji: '🥰', labelEn: 'Care', sortOrder: 3),
  SocialReaction(id: 4, key: 'haha', emoji: '😆', labelEn: 'Haha', sortOrder: 4),
  SocialReaction(id: 5, key: 'wow', emoji: '😮', labelEn: 'Wow', sortOrder: 5),
  SocialReaction(id: 6, key: 'sad', emoji: '😢', labelEn: 'Sad', sortOrder: 6),
  SocialReaction(id: 7, key: 'angry', emoji: '😡', labelEn: 'Angry', sortOrder: 7),
];
