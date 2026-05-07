import 'package:flutter/foundation.dart';
import '../network/api_client.dart';

class ImageUtils {
  static String? cleanImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    
    String cleanUrl = url;
    if (url.contains('placehold.co') && !url.endsWith('.png') && !url.endsWith('.jpg')) {
      cleanUrl = '$url.png';
    }
    
    final fullUrl = ensureFullUrl(cleanUrl);
    if (kDebugMode) {
      debugPrint('[ImageUtils] Original: $url -> Final: $fullUrl');
    }
    return fullUrl;
  }

  static String? ensureFullUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    
    // If it's already a full URL, just return it
    if (path.startsWith('http')) return path;
    
    // If it's an asset path, return as is
    if (path.startsWith('assets/')) return path;
    
    // Ensure base URL doesn't have trailing slash and path doesn't have leading slash
    String baseUrl = ApiClient.baseUrl;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    
    String cleanPath = path.trim();
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    
    return '$baseUrl/$cleanPath';
  }
}


