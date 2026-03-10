class ImageUtils {
  static String? cleanImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    if (url.contains('placehold.co') && !url.endsWith('.png') && !url.endsWith('.jpg')) {
      return '$url.png';
    }
    return url;
  }
}
