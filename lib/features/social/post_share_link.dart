/// Pulls a post id out of a share link.
///
/// `https://api.mytogether.org/p/12` and `mytogether://p/12` both count.
int? postIdFromShareLink(Uri uri) {
  if (uri.scheme == 'mytogether') {
    if (uri.host == 'p') {
      return _id(uri.pathSegments.isEmpty ? '' : uri.pathSegments.first);
    }
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'p') {
      return _id(uri.pathSegments[1]);
    }
    return null;
  }

  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  final host = uri.host.toLowerCase();
  if (host != 'api.mytogether.org' && host != 'localhost') return null;
  if (uri.pathSegments.length < 2 || uri.pathSegments.first != 'p') return null;
  return _id(uri.pathSegments[1]);
}

int? _id(String value) {
  final id = int.tryParse(value);
  if (id == null || id <= 0) return null;
  return id;
}
