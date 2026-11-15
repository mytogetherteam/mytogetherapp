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
      key: json['key']?.toString() ?? 'love',
      emoji: json['emoji']?.toString() ?? '❤️',
      labelEn: json['labelEn']?.toString() ?? 'Love',
      labelMm: json['labelMm']?.toString(),
      labelTh: json['labelTh']?.toString(),
      imageUrl: image.isEmpty ? null : image,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Used when the catalog has not loaded yet, so the row still has seven faces.
const fallbackSocialReactions = <SocialReaction>[
  SocialReaction(id: 1, key: 'love', emoji: '❤️', labelEn: 'Love', labelMm: 'ချစ်', sortOrder: 1),
  SocialReaction(id: 2, key: 'care', emoji: '🥰', labelEn: 'Care', labelMm: 'ဂရုစိုက်', sortOrder: 2),
  SocialReaction(id: 3, key: 'haha', emoji: '😆', labelEn: 'Haha', labelMm: 'ရယ်', sortOrder: 3),
  SocialReaction(id: 4, key: 'wow', emoji: '😮', labelEn: 'Wow', labelMm: 'အံ့', sortOrder: 4),
  SocialReaction(id: 5, key: 'sad', emoji: '😢', labelEn: 'Sad', labelMm: 'ဝမ်းနည်း', sortOrder: 5),
  SocialReaction(id: 6, key: 'angry', emoji: '😡', labelEn: 'Angry', labelMm: 'စိတ်ဆိုး', sortOrder: 6),
  SocialReaction(id: 7, key: 'like', emoji: '👍', labelEn: 'Like', labelMm: 'ကြိုက်', sortOrder: 7),
];
