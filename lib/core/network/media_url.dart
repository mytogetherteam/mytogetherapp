import 'api_client.dart';

String resolveMediaUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http') || path.startsWith('assets/')) return path;
  final normalized = path.startsWith('/') ? path.substring(1) : path;
  return '${ApiClient.baseUrl}/$normalized';
}

List<String> resolveMediaUrls(Iterable<String?> paths) {
  return paths
      .map((p) => resolveMediaUrl(p))
      .where((url) => url.isNotEmpty)
      .toList();
}
