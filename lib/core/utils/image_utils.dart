import '../network/api_client.dart';

class ImageUtils {
  static String? cleanImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    
    String cleanUrl = url;
    if (url.contains('placehold.co') && !url.endsWith('.png') && !url.endsWith('.jpg')) {
      cleanUrl = '$url.png';
    }
    
    return ensureFullUrl(cleanUrl);
  }

  static String? ensureFullUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    
    // Prepend base URL
    const baseUrl = ApiClient.baseUrl;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$cleanPath';
  }
}

