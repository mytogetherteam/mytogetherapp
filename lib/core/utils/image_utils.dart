class ImageUtils {
  static String? cleanImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    if (url.contains('placehold.co') && !url.endsWith('.png') && !url.endsWith('.jpg')) {
      return '$url.png';
    }
    return url;
  }
}

/// Resolves a shop/restaurant banner from the various image shapes the API
/// returns (`coverUrl`, `galleries`, `imageUrls`, `photos`, etc.).
class ShopImageResolver {
  ShopImageResolver._();

  /// Collects gallery URLs from every known backend field name.
  static List<String> parseImageUrls(Map<String, dynamic> json) {
    var imageUrls = (json['imageUrls'] as List? ?? [])
        .map((e) => ImageUtils.cleanImageUrl(e.toString()))
        .whereType<String>()
        .toList();
    if (imageUrls.isEmpty && json['galleries'] is List) {
      imageUrls = (json['galleries'] as List)
          .map((e) => e is Map ? ImageUtils.cleanImageUrl(e['imageUrl']) : null)
          .whereType<String>()
          .toList();
    }
    if (imageUrls.isEmpty && json['photos'] is List) {
      imageUrls = (json['photos'] as List)
          .map((e) {
            if (e is Map) {
              return ImageUtils.cleanImageUrl(e['url']?.toString()) ??
                  ImageUtils.cleanImageUrl(e['imageUrl']?.toString());
            }
            return ImageUtils.cleanImageUrl(e.toString());
          })
          .whereType<String>()
          .toList();
    }
    return imageUrls;
  }

  /// Banner priority: cover → gallery → logo → primary photo.
  static String? resolveBannerUrl({
    String? coverUrl,
    List<String> imageUrls = const [],
    String? logoUrl,
    String? primaryPhotoUrl,
  }) {
    final cover = ImageUtils.cleanImageUrl(coverUrl);
    if (cover != null && cover.isNotEmpty) return cover;
    if (imageUrls.isNotEmpty) return imageUrls.first;
    final logo = ImageUtils.cleanImageUrl(logoUrl);
    if (logo != null &&
        logo.isNotEmpty &&
        !logo.contains('pinterest.com')) {
      return logo;
    }
    final primary = ImageUtils.cleanImageUrl(primaryPhotoUrl);
    if (primary != null && primary.isNotEmpty) return primary;
    return null;
  }

  /// Parses a raw shop JSON object and returns the best banner URL.
  static String? resolveBannerFromJson(Map<String, dynamic> json) {
    final imageUrls = parseImageUrls(json);
    final primaryPhotoUrl = ImageUtils.cleanImageUrl(json['primaryPhotoUrl']) ??
        (imageUrls.isNotEmpty ? imageUrls.first : null);
    return resolveBannerUrl(
      coverUrl: json['coverUrl']?.toString(),
      imageUrls: imageUrls,
      logoUrl: json['logoUrl']?.toString(),
      primaryPhotoUrl: primaryPhotoUrl,
    );
  }
}
